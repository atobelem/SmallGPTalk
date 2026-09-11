"Store one OpenAI credential record in the macOS login Keychain."
Class {
	#name : 'SmallGPTalkKeychainStore',
	#superclass : 'Object',
	#instVars : [ 'service', 'account' ],
	#category : 'SmallGPTalk-OpenAI',
	#package : 'SmallGPTalk-OpenAI'
}

{ #category : 'initialization' }
SmallGPTalkKeychainStore >> initialize [
	super initialize.
	service := 'SmallGPTalk.OpenAI'.
	account := 'default'
]

{ #category : 'accessing' }
SmallGPTalkKeychainStore >> service [
	^ service
]

{ #category : 'accessing' }
SmallGPTalkKeychainStore >> service: aString [
	self validateName: aString.
	service := aString copy
]

{ #category : 'accessing' }
SmallGPTalkKeychainStore >> account [
	^ account
]

{ #category : 'accessing' }
SmallGPTalkKeychainStore >> account: aString [
	self validateName: aString.
	account := aString copy
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> security [
	^ SmallGPTalkSecurityLibrary uniqueInstance
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> coreFoundation [
	^ SmallGPTalkCoreFoundationLibrary uniqueInstance
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> validateName: aString [
	(aString isString and: [ aString isNotEmpty and: [ (aString includes: Character null) not ] ]) ifFalse: [
		self error: 'The Keychain name must be a non-empty string.' ]
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> checkStatus: status [
	| description |
	status = 0 ifTrue: [ ^ self ].
	description := 'The Keychain operation failed.'.
	status = -128 ifTrue: [ description := 'The user cancelled Keychain access.' ].
	status = -25293 ifTrue: [ description := 'The Keychain denied access.' ].
	status = -25308 ifTrue: [ description := 'The Keychain requires user interaction.' ].
	status = -25291 ifTrue: [ description := 'The Keychain is not available.' ].
	self error: description, ' Status: ', status asString, '.'
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> encodeRecord: aDictionary [
	(aDictionary isKindOf: Dictionary) ifFalse: [
		self error: 'The credential record must be a dictionary.' ].
	^ [ (STONJSON toString: aDictionary) utf8Encoded ]
		on: Error
		do: [ :error | self error: 'The credential record cannot be encoded.' ]
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> decodeRecord: bytes [
	| record |
	record := [ STONJSON fromString: bytes utf8Decoded ]
		on: Error
		do: [ :error | self error: 'The Keychain record is not valid JSON.' ].
	(record isKindOf: Dictionary) ifFalse: [
		self error: 'The Keychain record must be a dictionary.' ].
	^ record
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> withLoginKeychainDo: aBlock [
	^ ExternalAddress allocate: ExternalAddress wordSize bytesDuring: [ :buffer |
		| status reference path |
		buffer pointerAt: 1 put: ExternalAddress null.
		path := (FileLocator home / 'Library' / 'Keychains' / 'login.keychain-db') fullName.
		status := self security openKeychain: path into: buffer.
		self checkStatus: status.
		reference := buffer pointerAt: 1.
		[ aBlock value: reference ] ensure: [ self coreFoundation release: reference ] ]
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> withDictionaryDo: aBlock [
	| dictionary |
	dictionary := self coreFoundation newDictionary.
	^ [ aBlock value: dictionary ] ensure: [ self coreFoundation release: dictionary ]
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> dictionary: dictionary at: keyName putString: aString [
	| value |
	value := self coreFoundation newString: aString.
	[ self coreFoundation dictionary: dictionary at: (self security constant: keyName) put: value ]
		ensure: [ self coreFoundation release: value ]
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> fillIdentity: dictionary [
	self coreFoundation dictionary: dictionary
		at: (self security constant: 'kSecClass')
		put: (self security constant: 'kSecClassGenericPassword').
	self dictionary: dictionary at: 'kSecAttrService' putString: service.
	self dictionary: dictionary at: 'kSecAttrAccount' putString: account
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> restrict: query to: keychain [
	| array |
	array := self coreFoundation newArrayWith: keychain.
	[ self coreFoundation dictionary: query
		at: (self security constant: 'kSecMatchSearchList') put: array ]
		ensure: [ self coreFoundation release: array ]
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> withQueryDo: aBlock [
	^ self withLoginKeychainDo: [ :keychain |
		self withDictionaryDo: [ :query |
			self fillIdentity: query.
			self restrict: query to: keychain.
			aBlock value: query value: keychain ] ]
]

{ #category : 'accessing' }
SmallGPTalkKeychainStore >> read [
	^ self withQueryDo: [ :query :keychain |
		self coreFoundation dictionary: query
			at: (self security constant: 'kSecReturnData')
			put: (self coreFoundation constant: 'kCFBooleanTrue').
		self coreFoundation dictionary: query
			at: (self security constant: 'kSecMatchLimit')
			put: (self security constant: 'kSecMatchLimitOne').
		self readQuery: query ]
]

{ #category : 'private' }
SmallGPTalkKeychainStore >> readQuery: query [
	^ ExternalAddress allocate: ExternalAddress wordSize bytesDuring: [ :buffer |
		| status reference bytes |
		buffer pointerAt: 1 put: ExternalAddress null.
		status := self security copyMatching: query into: buffer.
		status = -25300 ifTrue: [ nil ] ifFalse: [
			self checkStatus: status.
			reference := buffer pointerAt: 1.
			[ bytes := self coreFoundation bytesFromData: reference.
			[ self decodeRecord: bytes ] ensure: [ bytes atAllPut: 0 ] ]
				ensure: [ self coreFoundation release: reference ] ] ]
]

{ #category : 'accessing' }
SmallGPTalkKeychainStore >> write: aDictionary [
	| bytes data |
	bytes := self encodeRecord: aDictionary.
	[ data := self coreFoundation newData: bytes.
	[ self withQueryDo: [ :query :keychain |
		self withDictionaryDo: [ :attributes |
			| status |
			self coreFoundation dictionary: attributes
				at: (self security constant: 'kSecValueData') put: data.
			status := self security update: query attributes: attributes.
			status = -25300 ifTrue: [
				self fillIdentity: attributes.
				self coreFoundation dictionary: attributes
					at: (self security constant: 'kSecUseKeychain') put: keychain.
				status := self security add: attributes ].
			self checkStatus: status ] ] ]
		ensure: [ self coreFoundation release: data ] ]
		ensure: [ bytes atAllPut: 0 ]
]

{ #category : 'credentials' }
SmallGPTalkKeychainStore >> delete [
	self withQueryDo: [ :query :keychain |
		| status |
		status := self security delete: query.
		status = -25300 ifFalse: [ self checkStatus: status ] ]
]
