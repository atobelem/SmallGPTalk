Class {
	#name : 'SmallGPTalkKeychainStoreTest',
	#superclass : 'TestCase',
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkKeychainStoreTest >> testDefaultIdentity [
	| store |
	store := SmallGPTalkKeychainStore new.
	self assert: store service equals: 'SmallGPTalk.OpenAI'.
	self assert: store account equals: 'default'
]

{ #category : 'tests' }
SmallGPTalkKeychainStoreTest >> testSeparateIdentity [
	| store |
	store := SmallGPTalkKeychainStore new service: 'SmallGPTalk.Tests'; account: 'test'; yourself.
	self assert: store service equals: 'SmallGPTalk.Tests'.
	self assert: store account equals: 'test'
]

{ #category : 'tests' }
SmallGPTalkKeychainStoreTest >> testRejectsEmptyIdentity [
	self should: [ SmallGPTalkKeychainStore new service: '' ] raise: Error.
	self should: [ SmallGPTalkKeychainStore new account: '' ] raise: Error.
	self should: [ SmallGPTalkKeychainStore new service: nil ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkKeychainStoreTest >> testRecordEncoding [
	| store record |
	store := SmallGPTalkKeychainStore new.
	record := Dictionary new at: 'expiresAt' put: 42; at: 'label' put: 'Synthetic record'; yourself.
	self assert: (store decodeRecord: (store encodeRecord: record)) equals: record
]

{ #category : 'tests' }
SmallGPTalkKeychainStoreTest >> testRejectsInvalidRecords [
	| store |
	store := SmallGPTalkKeychainStore new.
	self should: [ store encodeRecord: #() ] raise: Error.
	self should: [ store decodeRecord: '[' utf8Encoded ] raise: Error.
	self should: [ store decodeRecord: '[]' utf8Encoded ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkKeychainStoreTest >> testStatusErrorDoesNotIncludeRecord [
	| store |
	store := SmallGPTalkKeychainStore new.
	[ store checkStatus: -25293. self fail ] on: Error do: [ :error |
		self assert: error messageText equals: 'The Keychain denied access. Status: -25293.' ]
]

{ #category : 'tests' }
SmallGPTalkKeychainStoreTest >> testSecureRandomRejectsInvalidSize [
	self should: [ SmallGPTalkSecureRandom bytes: -1 ] raise: Error.
	self should: [ SmallGPTalkSecureRandom bytes: 1.5 ] raise: Error.
	self assert: (SmallGPTalkSecureRandom bytes: 0) equals: ByteArray new
]
