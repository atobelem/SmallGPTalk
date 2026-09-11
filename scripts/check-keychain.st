[
 | service phase store record |
 service := OSPlatform current environment at: 'SMALLGPTALK_KEYCHAIN_TEST_SERVICE'.
 (service beginsWith: 'SmallGPTalk.Test.') ifFalse: [ Error signal: 'Use a separate test Keychain service.' ].
 phase := OSPlatform current environment at: 'SMALLGPTALK_KEYCHAIN_PHASE'.
 store := SmallGPTalkCredentialStore backend: (SmallGPTalkKeychain service: service account: 'test').
 record := Dictionary new at: 'test-marker' put: 'second'; yourself.
 phase = 'write' ifTrue: [
  store read ifNotNil: [ Error signal: 'The test record already exists.' ].
  store write: (Dictionary new at: 'test-marker' put: 'first'; yourself).
  store write: record.
  store read = record ifFalse: [ Error signal: 'Keychain update failed.' ]
 ] ifFalse: [
  phase = 'read' ifFalse: [ Error signal: 'Choose write or read.' ].
  [ store read = record ifFalse: [ Error signal: 'Keychain restart read failed.' ] ]
   ensure: [ store delete ].
  store read ifNotNil: [ Error signal: 'Keychain deletion failed.' ] ].
 Stdio stdout nextPutAll: 'PASS: Keychain '; nextPutAll: phase; lf.
 Smalltalk exit: 0
] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
