| model account provider session run |
model := Smalltalk os environment at: 'SMALLGPTALK_MODEL' ifAbsent: [
	Error signal: 'Set SMALLGPTALK_MODEL to an account model identifier.' ].
account := SmallGPTalkOpenAIAccount new.
provider := SmallGPTalkOpenAIProvider account: account.
session := SmallGPTalkSession new
	provider: provider;
	model: model;
	yourself.
run := session send: 'Reply with exactly SMALLGPTALK_OK.' onEvent: [ :event |
	(event at: #type) = #text ifTrue: [
		Stdio stdout nextPutAll: (event at: #text); flush ] ].
run wait.
Stdio stdout lf; nextPutAll: 'Run state: '; nextPutAll: run state asString; lf; flush.
run state = #completed ifFalse: [
	Stdio stderr nextPutAll: run error messageText; lf; flush.
	Smalltalk exit: 1 ].
(run result text includesSubstring: 'SMALLGPTALK_OK') ifFalse: [
	Error signal: 'The model did not return the expected reply.' ].
Smalltalk exit: 0.
