| service action store record updated |
service := Smalltalk os environment at: 'SMALLGPTALK_KEYCHAIN_TEST_SERVICE'.
action := Smalltalk os environment at: 'SMALLGPTALK_KEYCHAIN_TEST_ACTION'.
(service beginsWith: 'SmallGPTalk.Tests.') ifFalse: [
	Error signal: 'Use a separate Keychain test service.' ].
store := SmallGPTalkKeychainStore new service: service; account: 'synthetic'; yourself.
record := Dictionary new at: 'label' put: 'Synthetic record'; at: 'value' put: 42; yourself.
action = 'write' ifTrue: [
	store read ifNotNil: [ Error signal: 'The test record already exists.' ].
	[ store write: record.
	(store read = record) ifFalse: [ Error signal: 'The Keychain write check failed.' ].
	(SmallGPTalkSecureRandom bytes: 32) size = 32 ifFalse: [
		Error signal: 'The secure random check failed.' ] ]
		on: Error do: [ :error | store delete. error pass ] ].
action = 'verify' ifTrue: [
	[ (store read = record) ifFalse: [ Error signal: 'The Keychain restart check failed.' ].
	updated := record copy at: 'value' put: 43; yourself.
	store write: updated.
	(store read = updated) ifFalse: [ Error signal: 'The Keychain update check failed.' ] ]
		ensure: [ store delete ].
	store read ifNotNil: [ Error signal: 'The Keychain delete check failed.' ] ].
action = 'delete' ifTrue: [ store delete ].
(#('write' 'verify' 'delete') includes: action) ifFalse: [
	Error signal: 'Select a valid Keychain test action.' ].
Stdio stdout nextPutAll: 'Keychain test passed: '; nextPutAll: action; lf.
Smalltalk exit: 0.
