"Check context commands and evaluation inspection with an offline provider."
| chat provider session run evaluation historyCount summaries window outputPath |
chat := SmallGPTalkChat new.
summaries := 0.
provider := SmallGPTalkCoreTestProvider new responseBlock: [ :request :text :activeRun |
	request instructions = SmallGPTalkContext summaryInstructions
		ifTrue: [ summaries := summaries + 1. SmallGPTalkMessage assistant: 'The collection contains 42. The evaluation completed. Continue from this result.' ]
		ifFalse: [ provider requestCount = 1
			ifTrue: [ (SmallGPTalkMessage assistant: 'I will create a collection.') toolCalls: {
				SmallGPTalkToolCall id: 'collection-42' name: 'evaluate'
					arguments: (Dictionary new at: 'source' put: 'OrderedCollection with: 42'; yourself) }; yourself ]
			ifFalse: [ SmallGPTalkMessage assistant: 'The collection contains `42`.' ] ] ]; yourself.
chat instVarNamed: 'provider' put: provider.
[
	chat open.
	(chat instVarNamed: 'models') items: #('fixture-model'); selectFirst.
	(chat instVarNamed: 'effort') items: #('medium'); selectFirst.
	(chat instVarNamed: 'input') text: 'Create a collection with 42.'.
	chat send.
	run := chat instVarNamed: 'run'.
	run wait.
	3 timesRepeat: [ World doOneCycle ].
	run state = #completed ifFalse: [ Error signal: 'The evaluation run failed.' ].
	session := chat instVarNamed: 'session'.
	evaluation := (chat instVarNamed: 'evaluations') selectedItem.
	(evaluation context at: #toolCall) id = 'collection-42' ifFalse: [ Error signal: 'The evaluation lost its call.' ].
	evaluation value first = 42 ifFalse: [ Error signal: 'The local value is wrong.' ].
	(chat instVarNamed: 'inspectButton') label = 'Inspect evaluation' ifFalse: [ Error signal: 'The evaluation action is missing.' ].
	(chat instVarNamed: 'inspectButton') click.
	historyCount := session messages size.
	(chat instVarNamed: 'input') text: '/compact'.
	chat send.
	(chat instVarNamed: 'run') wait.
	3 timesRepeat: [ World doOneCycle ].
	session messages size = historyCount ifFalse: [ Error signal: 'Compaction changed history.' ].
	session context messages size = 1 ifFalse: [ Error signal: 'Compaction did not produce summary context.' ].
	(chat instVarNamed: 'input') text: 'Continue.'.
	chat send.
	(chat instVarNamed: 'run') wait.
	3 timesRepeat: [ World doOneCycle ].
	session context autoCompactLimit: 1.
	(chat instVarNamed: 'input') text: 'Continue again.'.
	chat send.
	(chat instVarNamed: 'run') wait.
	3 timesRepeat: [ World doOneCycle ].
	summaries = 2 ifFalse: [ Error signal: 'Manual and automatic compaction did not both run.' ].
	session context autoCompactLimit: session context characterCount * 2.
	chat updateContextUsage.
	((chat instVarNamed: 'contextUsage') label includesSubstring: '50%') ifFalse: [ Error signal: 'The usage percentage is wrong.' ].
	(chat instVarNamed: 'contextButton') click.
	window := chat window window.
	window activate; extent: 1100 @ 800.
	window fullBounds.
	3 timesRepeat: [ World doOneCycle ].
	outputPath := Smalltalk os environment at: 'SMALLGPTALK_UI_CAPTURE' ifAbsent: [ nil ].
	outputPath ifNotNil: [ PNGReadWriter putForm: window imageForm onFileNamed: outputPath ].
	Stdio stdout nextPutAll: 'Context command, automatic compaction, history, usage, and evaluation inspector checks passed.'; lf; flush
] ensure: [ chat window ifNotNil: [ chat window close ] ].
Smalltalk exit: 0.
