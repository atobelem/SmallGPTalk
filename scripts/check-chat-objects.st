| chat provider session view result menu items window start |
chat := SmallGPTalkChat new.
provider := SmallGPTalkCoreTestProvider new.
provider responseBlock: [ :activeSession :onText :activeRun |
	provider requestCount = 1
		ifTrue: [
			onText value: 'I will evaluate `OrderedCollection with: 42`.'.
			(SmallGPTalkMessage assistant: 'I will evaluate `OrderedCollection with: 42`.')
				toolCalls: { SmallGPTalkToolCall id: 'inspect-42' name: 'evaluate'
					arguments: (Dictionary new at: 'source' put: 'OrderedCollection with: 42'; yourself) }; yourself ]
		ifFalse: [
			onText value: 'The result is an `OrderedCollection`. Select the evaluation and open its context menu.'.
			SmallGPTalkMessage assistant: 'The result is an `OrderedCollection`. Select the evaluation and open its context menu.' ] ].
chat instVarNamed: 'provider' put: provider.
chat open.
(chat instVarNamed: 'models') items: #('test-model'); selectFirst.
(chat instVarNamed: 'effort') items: #('medium'); selectFirst.
(chat instVarNamed: 'input') text: 'Create a collection with 42.'.
chat send.
(chat instVarNamed: 'run') ifNil: [ self error: (chat instVarNamed: 'status') label ].
(chat instVarNamed: 'run') wait.
3 timesRepeat: [ World doOneCycle ].
session := chat instVarNamed: 'session'.
view := chat instVarNamed: 'history'.
view entries first object == session messages first ifFalse: [ self error: 'The user message is a copy.' ].
view entries last object == session messages last ifFalse: [ self error: 'The assistant message is a copy.' ].
result := (view entries detect: [ :entry | entry object isKindOf: SmallGPTalkEvaluationResult ]) object.
result value first = 42 ifFalse: [ self error: 'The result is not the evaluated object.' ].
start := view text asString findString: 'Evaluation complete'.
view selectionInterval: (start to: start + 9).
menu := view objectMenu.
items := menu menuGroups flatCollect: #menuItems.
#('Inspect object' 'Inspect value' 'Browse result' 'Open expression in Playground' 'Inspect conversation' 'Inspect agent' 'Inspect run') do: [ :name |
	(items anySatisfy: [ :item | item name = name ]) ifFalse: [ self error: 'Missing action: ', name ] ].
(items detect: [ :item | item name = 'Inspect value' ]) action value.
(items detect: [ :item | item name = 'Browse result' ]) action value.
(items detect: [ :item | item name = 'Open expression in Playground' ]) action value.
window := SystemWindow allSubInstances detect: [ :each | each label = 'SmallGPTalk Chat' ].
window activate.
window extent: 1000 @ 720.
window fullBounds.
3 timesRepeat: [ World doOneCycle ].
World doOneCycle.
Stdio stdout nextPutAll: 'Live object identity, context menu, inspector, browser, and Playground checks passed.'; lf.
chat closeChat.
Smalltalk exit: 0.
