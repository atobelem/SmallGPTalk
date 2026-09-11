"A chat window for the SmallGPTalk API. Network work runs outside the UI process."
Class {
	#name : 'SmallGPTalkChat',
	#superclass : 'SpPresenter',
	#instVars : [ 'agent', 'connection', 'provider', 'session', 'run', 'busy', 'closed', 'history', 'input', 'models', 'effort', 'modelOptions', 'status', 'connectButton', 'logoutButton', 'sendButton', 'stopButton', 'newButton', 'evaluations', 'inspectButton', 'browseButton', 'copyButton', 'resultPreview', 'userEntry', 'improveButton', 'improvement', 'contextUsage', 'contextButton' ],
	#category : 'SmallGPTalk-Chat',
	#package : 'SmallGPTalk-Chat'
}

{ #category : 'initialization' }
SmallGPTalkChat >> initializePresenters [
	busy := false.
	closed := false.
	agent := SmallGPTalkAgent new tools: SmallGPTalkImageTools all; yourself.
	connection := SmallGPTalkChatConnection new.
	provider := connection provider.
	history := self instantiate: SmallGPTalkConversationPresenter.
	history contextObjects: [ {
		'agent' -> agent.
		'session' -> session.
		'conversation' -> (session ifNotNil: [ session conversation ]).
		'run' -> run. 'improvement' -> improvement.
		'context' -> (session ifNotNil: [ session context ]) } ].
	input := self newText placeholder: 'Write a message or paste Smalltalk code.'; yourself.
	models := self newDropList startWithoutSelection; yourself.
	modelOptions := #().
	effort := self newDropList startWithoutSelection; items: #('medium'); selectFirst; yourself.
	status := self newLabel label: 'Connect to load your models.'; yourself.
	contextUsage := self newLabel label: 'Context: no conversation'; yourself.
	contextButton := self newButton label: 'Inspect context'; action: [ self inspectContext ]; yourself.
	connectButton := self newButton label: 'Connect'; action: [ self connect ]; yourself.
	logoutButton := self newButton label: 'Sign out'; action: [ self logout ]; yourself.
	sendButton := self newButton label: 'Send'; action: [ self send ]; yourself.
	stopButton := self newButton label: 'Stop'; action: [ self stop ]; yourself.
	improveButton := self newButton label: 'Improve SmallGPTalk'; action: [ self improveContinuously ]; yourself.
	newButton := self newButton label: 'New chat'; action: [ self newChat ]; yourself.
	evaluations := self newList display: [ :result | result expression readStream nextLine ifNil: [ '' ] ifNotNil: [ :line | line truncateTo: 65 ] ]; yourself.
	resultPreview := self newText beNotEditable; placeholder: 'Select an evaluation to see its expression and result.'; yourself.
	inspectButton := self newButton label: 'Inspect evaluation'; action: [ self inspectResult ]; yourself.
	browseButton := self newButton label: 'Browse result'; action: [ self browseResult ]; yourself.
	copyButton := self newButton label: 'Copy expression'; action: [ self copyExpression ]; yourself.
	self updateControls
]

{ #category : 'layout' }
SmallGPTalkChat >> defaultLayout [
	^ SpBoxLayout newTopToBottom
		borderWidth: 12;
		spacing: 10;
		add: self headerLayout height: 34;
		add: self settingsLayout height: 54;
		add: (SpBoxLayout newLeftToRight spacing: 14;
			add: self conversationLayout;
			add: self resultsLayout width: 270;
			yourself);
		add: (SpBoxLayout newLeftToRight spacing: 8;
			add: contextUsage; add: contextButton width: 140; yourself) height: 30;
		add: status height: 24;
		yourself
]

{ #category : 'layout' }
SmallGPTalkChat >> headerLayout [
	^ SpBoxLayout newLeftToRight spacing: 8;
		add: (self newLabel label: agent name);
		add: improveButton width: 170;
		add: newButton width: 110;
		add: connectButton width: 100;
		add: logoutButton width: 90;
		yourself
]

{ #category : 'layout' }
SmallGPTalkChat >> settingsLayout [
	^ SpBoxLayout newLeftToRight spacing: 12;
		add: (SpBoxLayout newTopToBottom spacing: 4;
			add: (self newLabel label: 'Model') height: 18;
			add: models; yourself);
		add: (SpBoxLayout newTopToBottom spacing: 4;
			add: (self newLabel label: 'Reasoning effort') height: 18;
			add: effort; yourself) width: 180;
		yourself
]

{ #category : 'layout' }
SmallGPTalkChat >> conversationLayout [
	^ SpBoxLayout newTopToBottom spacing: 8;
		add: (self newLabel label: 'Conversation / Select text and right-click') height: 22;
		add: history;
		add: (self newLabel label: 'Your message') height: 22;
		add: input height: 110;
		add: (SpBoxLayout newLeftToRight spacing: 8;
			add: (self newLabel label: 'New chat keeps this conversation.');
			add: stopButton width: 80;
			add: sendButton width: 100; yourself) height: 34;
		yourself
]

{ #category : 'layout' }
SmallGPTalkChat >> resultsLayout [
	^ SpBoxLayout newTopToBottom spacing: 8;
		add: (self newLabel label: 'Evaluations') height: 22;
		add: evaluations;
		add: (self newLabel label: 'Expression and result') height: 22;
		add: resultPreview;
		add: (SpBoxLayout newLeftToRight spacing: 6;
			add: inspectButton; add: browseButton; yourself) height: 32;
		add: copyButton height: 32;
		add: (self newLabel label: 'Evaluate has full image access.') height: 18;
		add: (self newLabel label: 'Changes remain after Stop.') height: 18;
		yourself
]

{ #category : 'initialization' }
SmallGPTalkChat >> initializeWindow: aWindow [
	super initializeWindow: aWindow.
	aWindow title: agent name, ' Chat'; initialExtent: 1000 @ 720.
	aWindow whenClosedDo: [ self closeChat ]
]

{ #category : 'private' }
SmallGPTalkChat >> onUI: aBlock [
	UIManager default defer: [ closed ifFalse: [ aBlock value ] ]
]

{ #category : 'private' }
SmallGPTalkChat >> updateControls [
	connectButton enabled: (busy not and: [ session isNil ]).
	logoutButton enabled: busy not.
	newButton enabled: true.
	improveButton enabled: (busy not and: [ models selectedItem isNotNil and: [ effort selectedItem isNotNil ] ]).
	models enabled: (busy not and: [ session isNil ]).
	effort enabled: (busy not and: [ session isNil ]).
	sendButton enabled: (busy not and: [ models selectedItem isNotNil and: [ effort selectedItem isNotNil ] ]).
	inspectButton enabled: evaluations selectedItem isNotNil.
	browseButton enabled: evaluations selectedItem isNotNil.
	copyButton enabled: evaluations selectedItem isNotNil.
	contextButton enabled: session isNotNil.
	self updateContextUsage.
	stopButton enabled: busy
]

{ #category : 'private' }
SmallGPTalkChat >> setBusy: aBoolean status: aString [
	busy := aBoolean.
	status label: aString.
	self updateControls
]

{ #category : 'initialization' }
SmallGPTalkChat >> connectPresenters [
	models whenSelectedItemChangedDo: [ self selectModel ].
	effort whenSelectedItemChangedDo: [ self updateControls ].
	evaluations whenSelectedItemChangedDo: [ self updateResultPreview. self updateControls ]
]

{ #category : 'actions' }
SmallGPTalkChat >> connect [
	busy ifTrue: [ ^ self ].
	self setBusy: true status: 'Connecting...'.
	connection connectOnEvent: [ :event | self onUI: [ self receiveConnectionEvent: event ] ]
]

{ #category : 'actions' }
SmallGPTalkChat >> logout [
	busy ifTrue: [ ^ self ].
	self setBusy: true status: 'Signing out...'.
	connection logoutOnEvent: [ :event | self onUI: [ self receiveConnectionEvent: event ] ]
]

{ #category : 'events' }
SmallGPTalkChat >> receiveConnectionEvent: event [
	| type |
	type := event at: #type.
	type = #authorization ifTrue: [
		status label: 'Complete login in your browser.'.
		WebBrowser openOn: (event at: #url) ].
	type = #loadingModels ifTrue: [ status label: 'Loading models...' ].
	type = #connected ifTrue: [ self installModelOptions: (event at: #models) ].
	type = #signedOut ifTrue: [
		self clearConversation.
		models items: #().
		self setBusy: false status: 'Signed out.' ].
	type = #failed ifTrue: [ self setBusy: false status: (event at: #error) messageText ]
]

{ #category : 'actions' }
SmallGPTalkChat >> newChat [
	^ self openChatWithAgent: agent
]

{ #category : 'private' }
SmallGPTalkChat >> clearConversation [
	session := nil.
	run := nil.
	history clear.
	userEntry := nil.
	input text: ''.
	evaluations items: #()
]

{ #category : 'actions' }
SmallGPTalkChat >> send [
	| text |
	busy ifTrue: [ ^ self ].
	text := input text asString trimBoth.
	text isEmpty ifTrue: [ ^ self ].
	text = '/compact' ifTrue: [ ^ self compact ].
	models selectedItem ifNil: [ status label: 'Select a model.' . ^ self ].
	effort selectedItem ifNil: [ status label: 'Select a reasoning effort.'. ^ self ].
	session ifNil: [
		session := agent newSession
			provider: provider;
			model: models selectedItem;
			reasoningEffort: effort selectedItem;
			yourself ].
	userEntry := history addObject: (SmallGPTalkMessage user: text)
		title: 'You' source: text markdown: false.
	self appendHeading: agent name.
	input text: ''.
	self setBusy: true status: 'Running...'.
	[ run := session send: text onEvent: [ :event | self onUI: [ self receiveEvent: event ] ] ]
		on: Error do: [ :error |
			input text: text.
			self appendNotice: 'Request did not start. ', error messageText.
			self setBusy: false status: error messageText ]
]

{ #category : 'events' }
SmallGPTalkChat >> receiveEvent: event [
	| type |
	type := event at: #type.
	type = #text ifFalse: [ self updateContextUsage ].
	type = #compactionStarted ifTrue: [ ^ status label: 'Compacting model context...' ].
	type = #compacted ifTrue: [ ^ status label: 'Model context compacted.' ].
	self bindUserMessage.
	type = #text ifTrue: [ ^ self appendAssistant: (event at: #text) ].
	type = #toolStarted ifTrue: [ ^ self receiveToolStarted: event ].
	type = #toolResult ifTrue: [ ^ self receiveToolResult: event ].
	type = #finished ifTrue: [ self receiveFinished: event ]
]

{ #category : 'events' }
SmallGPTalkChat >> receiveToolStarted: event [
	self bindAssistantForCall: (event at: #call).
	history addObject: (event at: #call) title: 'Tool call'
		source: 'Running ', (event at: #call) name, '...' markdown: false.
	status label: 'Evaluating Smalltalk...'
]

{ #category : 'events' }
SmallGPTalkChat >> receiveToolResult: event [
	| result |
	(event at: #call ifAbsent: [ nil ]) ifNotNil: [ :call | self bindAssistantForCall: call ].
	result := event at: #result.
	self retainEvaluation: result.
	history addObject: result title: 'Evaluation' source: (result isError
		ifTrue: [ 'Evaluation failed: ', (result text truncateTo: 500) ]
		ifFalse: [ 'Evaluation complete. See Evaluations for the result.' ]) markdown: false
]

{ #category : 'events' }
SmallGPTalkChat >> receiveFinished: event [
	| failure |
	failure := event at: #error.
	(event at: #result ifAbsent: [ nil ]) ifNotNil: [ :message | history bindCurrentMessage: message ].
	(event at: #state) = #completed ifFalse: [
		history addObject: failure title: 'Run ', (event at: #state) asString
			source: '[', (event at: #state) asString, ']',
			(failure ifNil: [ '' ] ifNotNil: [ ' ', failure messageText ]) markdown: false ].
	self setBusy: (improvement isNotNil and: [ improvement isActive ]) status: (failure
		ifNil: [ (event at: #state) = #completed
			ifTrue: [ 'Ready.' ] ifFalse: [ 'Stopped.' ] ]
		ifNotNil: [ failure messageText ])
]

{ #category : 'private' }
SmallGPTalkChat >> appendHeading: aString [
	history addObject: (SmallGPTalkMessage assistant: '') title: aString source: '' markdown: true
]

{ #category : 'private' }
SmallGPTalkChat >> appendNotice: aString [
	history addObject: nil title: '' source: aString markdown: false
]

{ #category : 'actions' }
SmallGPTalkChat >> stop [
	connection cancel.
	improvement ifNotNil: [ improvement cancel ].
	run ifNotNil: [ run cancel ].
	busy ifTrue: [ status label: 'Stopping. Wait for the operation to stop.' ]
]

{ #category : 'actions' }
SmallGPTalkChat >> closeChat [
	closed := true.
	self stop.
	history close.
	userEntry := nil.
	evaluations items: #()
]

{ #category : 'private' }
SmallGPTalkChat >> installModelOptions: catalog [
	modelOptions := catalog.
	models items: (catalog collect: [ :item | item at: 'slug' ]).
	(models items includes: 'gpt-5.6-luna') ifTrue: [ models selectItem: 'gpt-5.6-luna' ].
	self setBusy: false status: (models selectedItem
		ifNil: [ 'The default model is not available. Select a model.' ]
		ifNotNil: [ 'Ready. Enter a message.' ])
]

{ #category : 'private' }
SmallGPTalkChat >> selectModel [
	| option levels |
	option := modelOptions detect: [ :item | (item at: 'slug') = models selectedItem ] ifNone: [ nil ].
	option ifNotNil: [
		levels := (option at: 'supported_reasoning_levels' ifAbsent: [ #() ]) collect: [ :item | item at: 'effort' ].
		effort items: levels.
		(levels includes: 'medium') ifTrue: [ effort selectItem: 'medium' ] ].
	self updateControls
]

{ #category : 'private' }
SmallGPTalkChat >> createChat [
	| chat |
	chat := self class new agent: agent; yourself.
	modelOptions ifNotEmpty: [
		chat installModelOptions: modelOptions deepCopy.
		chat selectModel: models selectedItem effort: effort selectedItem ].
	^ chat
]

{ #category : 'private' }
SmallGPTalkChat >> selectModel: modelName effort: effortName [
	modelName ifNil: [ ^ self ].
	models selectItem: modelName.
	(effort items includes: effortName) ifTrue: [ effort selectItem: effortName ]
]

{ #category : 'private' }
SmallGPTalkChat >> retainEvaluation: result [
	| items |
	(result isKindOf: SmallGPTalkEvaluationResult) ifFalse: [ ^ self ].
	items := evaluations items copyWith: result.
	items size > 100 ifTrue: [ items := items last: 100 ].
	evaluations items: items; selectItem: result
]

{ #category : 'actions' }
SmallGPTalkChat >> inspectResult [
	evaluations selectedItem ifNotNil: [ :result | result inspect ]
]

{ #category : 'actions' }
SmallGPTalkChat >> browseResult [
	evaluations selectedItem ifNotNil: [ :result | history browse: result value ]
]

{ #category : 'actions' }
SmallGPTalkChat >> copyExpression [
	evaluations selectedItem ifNotNil: [ :result | Clipboard clipboardText: result expression ]
]

{ #category : 'context' }
SmallGPTalkChat >> prepareQuestionAbout: codeObject [
	input text: (SmallGPTalkCodeContext textFor: codeObject).
	status label: 'Add your question. Connect before sending.'
]

{ #category : 'instance creation' }
SmallGPTalkChat class >> askAbout: codeObject [
	| chat |
	chat := self new.
	chat prepareQuestionAbout: codeObject.
	chat open.
	^ chat
]

{ #category : 'private' }
SmallGPTalkChat >> updateResultPreview [
	resultPreview text: (evaluations selectedItem
		ifNil: [ '' ]
		ifNotNil: [ :result | self previewFor: result ])
]

{ #category : 'private' }
SmallGPTalkChat >> previewFor: result [
	| summary |
	summary := [
		| data |
		data := STONJSON fromString: result text.
		'Class: ', (data at: 'class'), String cr, String cr,
		'Value:', String cr, (data at: 'value')
	] on: Error do: [ :error | result text ].
	^ 'Expression:', String cr, result expression, String cr, String cr, summary,
		String cr, String cr, (self evaluationContextTextFor: result)
]

{ #category : 'accessing' }
SmallGPTalkChat >> agent [
	^ agent
]

{ #category : 'accessing' }
SmallGPTalkChat >> agent: anAgent [
	session ifNotNil: [ self error: 'Set the agent before the conversation starts.' ].
	agent := anAgent
]

{ #category : 'private' }
SmallGPTalkChat >> appendAssistant: fragment [
	history assistantName: agent name.
	history appendAssistant: fragment
]

{ #category : 'private' }
SmallGPTalkChat >> bindUserMessage [
	| message |
	(session isNil or: [ userEntry isNil ]) ifTrue: [ ^ self ].
	message := session messages reversed detect: [ :each | each role = #user ] ifNone: [ nil ].
	message ifNotNil: [ userEntry object: message ]
]

{ #category : 'private' }
SmallGPTalkChat >> bindAssistantForCall: call [
	session ifNotNil: [
		history assistantName: agent name.
		history bindCurrentMessage: (session conversation messageWithCallId: call id) ]
]

{ #category : 'actions' }
SmallGPTalkChat >> improveContinuously [
	| chat |
	(busy or: [ models selectedItem isNil or: [ effort selectedItem isNil ] ]) ifTrue: [ ^ self ].
	chat := self openChatWithAgent: agent forSelfImprovement.
	chat startImprovement.
	^ chat
]

{ #category : 'actions' }
SmallGPTalkChat >> startImprovement [
	| modelName effortName |
	busy ifTrue: [ ^ self ].
	modelName := models selectedItem.
	effortName := effort selectedItem.
	(modelName isNil or: [ effortName isNil ]) ifTrue: [ self error: 'Select a model and reasoning effort.' ].
	improvement := SmallGPTalkSelfImprovement new sessionFactory: [
		agent newSession provider: provider; model: modelName;
			reasoningEffort: effortName; yourself ]; yourself.
	self setBusy: true status: 'Continuous improvement is active. Use Stop to end it.'.
	improvement startOnEvent: [ :event | self onUI: [ self receiveImprovementEvent: event ] ]
]

{ #category : 'events' }
SmallGPTalkChat >> receiveImprovementEvent: event [
	| type |
	type := event at: #type.
	type = #cycleStarted ifTrue: [
		session := event at: #session.
		run := nil.
		userEntry := history addObject: (SmallGPTalkMessage user: (event at: #input))
			title: 'Improvement cycle ', (event at: #cycle) asString
			source: (event at: #input) markdown: false.
		self appendHeading: agent name.
		^ self setBusy: true status: 'Continuous improvement is running.' ].
	type = #cycleFailed ifTrue: [
		history addObject: (event at: #error) title: 'Cycle failed'
			source: (event at: #error) messageText markdown: false.
		^ status label: 'Cycle failed. Waiting before the next cycle.' ].
	type = #improvementStopped ifTrue: [ ^ self setBusy: false status: 'Continuous improvement stopped.' ].
	run := improvement activeRun.
	self receiveEvent: event.
	type = #finished ifTrue: [
		status label: 'Cycle finished. Continuous improvement remains active.' ]
]

{ #category : 'private' }
SmallGPTalkChat >> openChatWithAgent: anAgent [
	| chat modelName effortName |
	modelName := models selectedItem.
	effortName := effort selectedItem.
	chat := self createChat.
	chat agent: anAgent.
	chat open.
	chat selectModel: modelName effort: effortName.
	^ chat
]

{ #category : 'actions' }
SmallGPTalkChat >> compact [
	busy ifTrue: [ ^ self ].
	session ifNil: [ ^ status label: 'Start a conversation before using /compact.' ].
	userEntry := nil.
	history addObject: nil title: 'Command' source: '/compact' markdown: false.
	self appendHeading: 'Context summary'.
	input text: ''.
	self setBusy: true status: 'Compacting model context...'.
	[ run := session compactOnEvent: [ :event | self onUI: [ self receiveEvent: event ] ] ]
		on: Error do: [ :error |
			input text: '/compact'.
			self appendNotice: error messageText.
			self setBusy: false status: error messageText ]
]

{ #category : 'private' }
SmallGPTalkChat >> updateContextUsage [
	session ifNil: [ ^ contextUsage label: 'Context: no conversation' ].
	contextUsage label: (session context usagePercent
		ifNil: [ 'Context: ', session context characterCount asString, ' chars / auto compact off' ]
		ifNotNil: [ :percent | 'Context: ', percent asString, '% / ',
			session context autoCompactLimit asString, ' char auto-compact limit' ])
]

{ #category : 'accessing' }
SmallGPTalkChat >> contextSnapshot [
	| snapshot |
	session ifNil: [ ^ Dictionary new ].
	snapshot := session context snapshot.
	(session provider respondsTo: #requestBodyFor:) ifTrue: [
		snapshot at: #request put: (session provider requestBodyFor: session) ].
	^ snapshot
]

{ #category : 'actions' }
SmallGPTalkChat >> inspectContext [
	session ifNotNil: [ self contextSnapshot inspect ]
]

{ #category : 'private' }
SmallGPTalkChat >> evaluationContextTextFor: result [
	| context modelName effortName call |
	context := result context.
	modelName := (context at: #model ifAbsent: [ nil ]) ifNil: [ 'Not set' ].
	effortName := (context at: #reasoningEffort ifAbsent: [ nil ]) ifNil: [ 'Not set' ].
	call := context at: #toolCall ifAbsent: [ nil ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Model: '; nextPutAll: modelName; cr;
			nextPutAll: 'Effort: '; nextPutAll: effortName.
		call ifNotNil: [ stream cr; nextPutAll: 'Tool call: '; nextPutAll: call id ] ]
]
