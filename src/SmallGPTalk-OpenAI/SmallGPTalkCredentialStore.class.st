"Encode credential records independently of the native storage backend."
Class {
 #name : 'SmallGPTalkCredentialStore',
 #superclass : 'Object',
 #instVars : [ 'backend' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'instance creation' }
SmallGPTalkCredentialStore class >> backend: storage [ ^ self new backend: storage; yourself ]

{ #category : 'initialization' }
SmallGPTalkCredentialStore >> backend: storage [ backend := storage ]

{ #category : 'storage' }
SmallGPTalkCredentialStore >> read [
 | bytes record |
 bytes := backend readBytes.
 bytes ifNil: [ ^ nil ].
 [
  record := [ STONJSON fromString: bytes utf8Decoded ] on: Error do: [ :error |
   self error: 'The stored credential record is not valid JSON.' ].
  record isDictionary ifFalse: [ self error: 'The stored credential record must be an object.' ].
  ^ record
 ] ensure: [ bytes atAllPut: 0 ]
]

{ #category : 'storage' }
SmallGPTalkCredentialStore >> write: record [
 | bytes |
 record isDictionary ifFalse: [ self error: 'The credential record must be an object.' ].
 bytes := [ (STONJSON toString: record) utf8Encoded ] on: Error do: [ :error |
  self error: 'The credential record cannot be encoded.' ].
 [ backend writeBytes: bytes ] ensure: [ bytes atAllPut: 0 ]
]

{ #category : 'storage' }
SmallGPTalkCredentialStore >> delete [ backend delete ]

{ #category : 'instance creation' }
SmallGPTalkCredentialStore class >> loginKeychain [
 ^ self backend: SmallGPTalkKeychain new
]

{ #category : 'coordination' }
SmallGPTalkCredentialStore >> coordinationKey [
 ^ (backend respondsTo: #coordinationKey)
  ifTrue: [ backend coordinationKey ] ifFalse: [ backend ]
]
