"Store bytes under one service and account in the user's login Keychain."
Class {
 #name : 'SmallGPTalkKeychain',
 #superclass : 'Object',
 #instVars : [ 'service', 'account', 'security', 'cf' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'instance creation' }
SmallGPTalkKeychain class >> service: name account: user [ ^ self new service: name account: user; yourself ]

{ #category : 'initialization' }
SmallGPTalkKeychain >> initialize [
 super initialize.
 service := 'SmallGPTalk.OpenAI'.
 account := 'default'.
 security := SmallGPTalkSecurity uniqueInstance.
 cf := SmallGPTalkCoreFoundation uniqueInstance
]

{ #category : 'initialization' }
SmallGPTalkKeychain >> service: name account: user [
 { name. user } do: [ :value |
  (value isString and: [ value notEmpty and: [ (value includes: Character null) not ] ])
   ifFalse: [ self error: 'The Keychain identity must contain text.' ] ].
 service := name copy.
 account := user copy
]

{ #category : 'errors' }
SmallGPTalkKeychain >> checkStatus: code [
 | message |
 code = 0 ifTrue: [ ^ self ].
 message := (#(-128 -25293 -25308) includes: code)
  ifTrue: [ 'Keychain access was denied or requires user interaction.' ]
  ifFalse: [ 'The Keychain operation failed.' ].
 self error: message, ' Status: ', code asString, '.'
]

{ #category : 'private' }
SmallGPTalkKeychain >> identityIn: dictionary [
 cf dictionary: dictionary at: (security constant: 'kSecClass') put: (security constant: 'kSecClassGenericPassword').
 cf string: service during: [ :value | cf dictionary: dictionary at: (security constant: 'kSecAttrService') put: value ].
 cf string: account during: [ :value | cf dictionary: dictionary at: (security constant: 'kSecAttrAccount') put: value ]
]

{ #category : 'private' }
SmallGPTalkKeychain >> withQuery: aBlock [
 ^ ExternalAddress allocate: ExternalAddress wordSize bytesDuring: [ :buffer |
  | keychain path |
  buffer pointerAt: 1 put: ExternalAddress null.
  path := (FileLocator home / 'Library' / 'Keychains' / 'login.keychain-db') fullName.
  self checkStatus: (security open: path into: buffer).
  keychain := buffer pointerAt: 1.
  [ cf dictionaryDuring: [ :query |
   self identityIn: query.
   cf arrayWith: keychain during: [ :array |
    cf dictionary: query at: (security constant: 'kSecMatchSearchList') put: array ].
   aBlock value: query value: keychain ] ] ensure: [ cf release: keychain ] ]
]

{ #category : 'storage' }
SmallGPTalkKeychain >> readBytes [
 ^ self withQuery: [ :query :keychain |
  cf dictionary: query at: (security constant: 'kSecReturnData') put: (cf constant: 'kCFBooleanTrue').
  cf dictionary: query at: (security constant: 'kSecMatchLimit') put: (security constant: 'kSecMatchLimitOne').
  ExternalAddress allocate: ExternalAddress wordSize bytesDuring: [ :buffer |
   | code data |
   buffer pointerAt: 1 put: ExternalAddress null.
   code := security read: query into: buffer.
   code = -25300 ifTrue: [ nil ] ifFalse: [
    self checkStatus: code.
    data := buffer pointerAt: 1.
    [ cf bytesFrom: data ] ensure: [ cf release: data ] ] ] ]
]

{ #category : 'storage' }
SmallGPTalkKeychain >> writeBytes: bytes [
 cf data: bytes during: [ :data |
  self withQuery: [ :query :keychain |
   cf dictionaryDuring: [ :values |
    | code |
    cf dictionary: values at: (security constant: 'kSecValueData') put: data.
    code := security update: query values: values.
    code = -25300 ifTrue: [
     self identityIn: values.
     cf dictionary: values at: (security constant: 'kSecUseKeychain') put: keychain.
     code := security add: values ].
    self checkStatus: code ] ] ]
]

{ #category : 'storage' }
SmallGPTalkKeychain >> delete [
 self withQuery: [ :query :keychain |
  | code |
  code := security delete: query.
  code = -25300 ifFalse: [ self checkStatus: code ] ]
]

{ #category : 'coordination' }
SmallGPTalkKeychain >> coordinationKey [
 ^ { self class. service copy. account copy }
]
