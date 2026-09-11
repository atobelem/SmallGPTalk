Class {
 #name : 'SmallGPTalkCredentialStoreTest',
 #superclass : 'TestCase',
 #instVars : [ 'bytes', 'temporary', 'denied' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'backend protocol' }
SmallGPTalkCredentialStoreTest >> readBytes [
 denied ifNotNil: [ self error: denied ].
 ^ bytes copy
]

{ #category : 'backend protocol' }
SmallGPTalkCredentialStoreTest >> writeBytes: data [
 temporary := data.
 bytes := data copy
]

{ #category : 'backend protocol' }
SmallGPTalkCredentialStoreTest >> delete [ bytes := nil ]

{ #category : 'tests' }
SmallGPTalkCredentialStoreTest >> testStoreRoundTripClearsItsTemporaryBytes [
 | store record |
 store := SmallGPTalkCredentialStore backend: self.
 record := Dictionary new at: 'test' put: 'invented credential'; yourself.
 self assert: store read isNil.
 store write: record.
 self assert: (temporary allSatisfy: [ :byte | byte = 0 ]).
 self assert: store read equals: record.
 store delete.
 self assert: store read isNil
]

{ #category : 'tests' }
SmallGPTalkCredentialStoreTest >> testCorruptRecordHasNoSecretInItsError [
 | store |
 bytes := 'invalid-test-secret' utf8Encoded.
 store := SmallGPTalkCredentialStore backend: self.
 self should: [ store read ] raise: Error withExceptionDo: [ :error |
  self deny: (error messageText includesSubstring: 'invalid-test-secret') ]
]

{ #category : 'tests' }
SmallGPTalkCredentialStoreTest >> testAccessDenialIsReported [
 | store |
 denied := 'Keychain access denied.'.
 store := SmallGPTalkCredentialStore backend: self.
 self should: [ store read ] raise: Error withExceptionDo: [ :error |
  self assert: error messageText equals: denied ]
]

{ #category : 'tests - native contract' }
SmallGPTalkCredentialStoreTest >> testKeychainStatusExplainsDeniedAccess [
 self should: [ SmallGPTalkKeychain new checkStatus: -25293 ] raise: Error
  withExceptionDo: [ :error | self assert: (error messageText includesSubstring: 'denied') ]
]

{ #category : 'tests - native contract' }
SmallGPTalkCredentialStoreTest >> testKeychainIdentityCannotBeEmpty [
 self should: [ SmallGPTalkKeychain service: '' account: 'default' ] raise: Error
  withExceptionDo: [ :error | self assert: error messageText equals: 'The Keychain identity must contain text.' ]
]

{ #category : 'tests - coordination' }
SmallGPTalkCredentialStoreTest >> testSeparateAdaptersForOneRecordShareAccountAccess [
 | first second other access |
 first := SmallGPTalkCredentialStore backend:
  (SmallGPTalkKeychain service: 'SmallGPTalk.Test.coordination' account: 'one').
 second := SmallGPTalkCredentialStore backend:
  (SmallGPTalkKeychain service: 'SmallGPTalk.Test.coordination' account: 'one').
 other := SmallGPTalkCredentialStore backend:
  (SmallGPTalkKeychain service: 'SmallGPTalk.Test.coordination' account: 'two').
 access := SmallGPTalkAccountAccess for: first.
 self assert: (SmallGPTalkAccountAccess for: second) identicalTo: access.
 self deny: (SmallGPTalkAccountAccess for: other) identicalTo: access
]
