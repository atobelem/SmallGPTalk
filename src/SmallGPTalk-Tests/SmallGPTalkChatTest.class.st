Class {
	#name : 'SmallGPTalkChatTest',
	#superclass : 'TestCase',
	#instVars : [ 'chats' ],
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkChatTest >> testRequiresExplicitModel [
	| chat |
	chat := self newChat.
	self assert: (chat instVarNamed: 'models') selectedItem isNil.
	self deny: (chat instVarNamed: 'sendButton') isEnabled
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testSendAndContinueConversation [
	| chat provider pending firstRun |
	chat := self newChat.
	pending := Semaphore new.
	provider := SmallGPTalkCoreTestProvider new responseBlock: [ :session :text :run |
		pending wait.
		text value: 'Hello.'.
		SmallGPTalkMessage assistant: 'Hello.' ].
	chat instVarNamed: 'provider' put: provider.
	(chat instVarNamed: 'models') items: #('test-model'); selectFirst.
	(chat instVarNamed: 'input') text: 'First'.
	chat send.
	firstRun := chat instVarNamed: 'run'.
	self assert: ((chat instVarNamed: 'session') tools collect: #name) equals: #('evaluate').
	self assert: (chat instVarNamed: 'busy').
	chat send.
	self assert: (chat instVarNamed: 'run') identicalTo: firstRun.
	pending signal.
	firstRun wait.
	chat receiveEvent: (Dictionary new at: #type put: #finished; at: #error put: nil; at: #state put: #completed; yourself).
	(chat instVarNamed: 'input') text: 'Second'.
	chat send.
	pending signal.
	(chat instVarNamed: 'run') wait.
	self assert: (chat instVarNamed: 'session') messages size equals: 4.
	self assert: provider requestCount equals: 2
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testCloseCancelsActiveRun [
	| chat provider started |
	chat := self newChat.
	started := Semaphore new.
	provider := SmallGPTalkCoreTestProvider new responseBlock: [ :session :text :run |
		started signal.
		Semaphore new wait ].
	chat instVarNamed: 'provider' put: provider.
	(chat instVarNamed: 'models') items: #('test-model'); selectFirst.
	(chat instVarNamed: 'input') text: 'Wait'.
	chat send.
	self deny: (started waitTimeoutMilliseconds: 2000).
	chat closeChat.
	(chat instVarNamed: 'run') wait.
	self assert: (chat instVarNamed: 'run') state equals: #cancelled
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testFailureKeepsPartialTextAndShowsState [
	| chat |
	chat := self newChat.
	chat receiveEvent: (Dictionary new at: #type put: #text; at: #text put: 'Partial'; yourself).
	chat receiveEvent: (Dictionary new at: #type put: #finished;
		at: #state put: #failed;
		at: #error put: (SmallGPTalkFailure fromException: (Error new messageText: 'Stream stopped.')); yourself).
	self assert: ((chat instVarNamed: 'history') text asString includesSubstring: 'Partial').
	self assert: ((chat instVarNamed: 'history') text asString includesSubstring: '[failed]').
	self assert: (chat instVarNamed: 'status') label equals: 'Stream stopped.'.
	self deny: (chat instVarNamed: 'busy')
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testCatalogSelectsDefaultsAndSupportedEfforts [
	| chat catalog |
	chat := self newChat.
	catalog := { Dictionary new at: 'slug' put: 'gpt-5.6-luna';
		at: 'supported_reasoning_levels' put: {
			Dictionary new at: 'effort' put: 'medium'; yourself.
			Dictionary new at: 'effort' put: 'high'; yourself }; yourself }.
	chat installModelOptions: catalog.
	self assert: (chat instVarNamed: 'models') selectedItem equals: 'gpt-5.6-luna'.
	self assert: (chat instVarNamed: 'effort') selectedItem equals: 'medium'.
	self assert: (chat instVarNamed: 'effort') items asArray equals: #('medium' 'high').
	self assert: (chat instVarNamed: 'sendButton') isEnabled
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testMissingDefaultDoesNotSelectAnotherModel [
	| chat |
	chat := self newChat.
	chat installModelOptions: { Dictionary new at: 'slug' put: 'another-model'; yourself }.
	self assert: (chat instVarNamed: 'models') selectedItem isNil.
	self deny: (chat instVarNamed: 'sendButton') isEnabled
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testNewChatPreservesPreviousConversationAndCopiesChoices [
	| original other conversation catalog |
	original := self newChat.
	catalog := { Dictionary new at: 'slug' put: 'gpt-5.6-luna';
		at: 'supported_reasoning_levels' put: {
			Dictionary new at: 'effort' put: 'medium'; yourself.
			Dictionary new at: 'effort' put: 'high'; yourself }; yourself }.
	original installModelOptions: catalog.
	original selectModel: 'gpt-5.6-luna' effort: 'high'.
	conversation := SmallGPTalkSession new.
	conversation addMessage: (SmallGPTalkMessage user: 'Previous message').
	original instVarNamed: 'session' put: conversation.
	(original instVarNamed: 'history') text: 'Previous message'.
	(original instVarNamed: 'input') text: 'Unsent draft'.
	other := original createChat.
	self assert: (original instVarNamed: 'session') identicalTo: conversation.
	self assert: conversation messages size equals: 1.
	self assert: (original instVarNamed: 'history') text asString equals: 'Previous message'.
	self assert: (original instVarNamed: 'input') text asString equals: 'Unsent draft'.
	self assert: (other instVarNamed: 'session') isNil.
	self assert: (other instVarNamed: 'history') text isEmpty.
	self assert: (other instVarNamed: 'models') selectedItem equals: 'gpt-5.6-luna'.
	self assert: (other instVarNamed: 'effort') selectedItem equals: 'high'.
	(other instVarNamed: 'effort') selectItem: 'medium'.
	self assert: (original instVarNamed: 'effort') selectedItem equals: 'high'.
	self deny: (original instVarNamed: 'provider') identicalTo: (other instVarNamed: 'provider')
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testCanCreateChatWhilePreviousChatIsBusy [
	| original other |
	original := self newChat.
	original setBusy: true status: 'Running...'.
	self assert: (original instVarNamed: 'newButton') isEnabled.
	other := original createChat.
	self assert: (original instVarNamed: 'busy').
	self deny: (other instVarNamed: 'busy').
	self assert: (other instVarNamed: 'models') selectedItem isNil
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testBrowserContextSurvivesConnection [
	| chat text |
	chat := self newChat.
	chat prepareQuestionAbout: SmallGPTalkSession >> #send:onEvent:.
	text := (chat instVarNamed: 'input') text asString.
	self assert: (text includesSubstring: 'SmallGPTalkSession >> send:onEvent:').
	self assert: (text includesSubstring: (SmallGPTalkSession >> #send:onEvent:) sourceCode).
	chat installModelOptions: #().
	self assert: (chat instVarNamed: 'input') text asString equals: text.
	self assert: (chat instVarNamed: 'session') isNil
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testClassAndClassSideMethodContext [
	| text |
	text := SmallGPTalkCodeContext textFor: SmallGPTalkSession.
	self assert: (text includesSubstring: SmallGPTalkSession definitionString).
	text := SmallGPTalkCodeContext textFor: SmallGPTalkAgent class >> #defaultInstructions.
	self assert: (text includesSubstring: 'SmallGPTalkAgent class >> defaultInstructions')
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testRetainedObjectsAreBoundedAndReleasedOnClose [
	| chat result object |
	chat := self newChat.
	object := OrderedCollection with: 42.
	result := SmallGPTalkEvaluationResult new value: object; expression: 'OrderedCollection with: 42'; yourself.
	chat retainEvaluation: result.
	self assert: (chat instVarNamed: 'evaluations') selectedItem value identicalTo: object.
	self assert: (chat instVarNamed: 'inspectButton') isEnabled.
	chat retainEvaluation: (SmallGPTalkToolResult error: 'Failed.').
	self assert: (chat instVarNamed: 'evaluations') items size equals: 1.
	101 timesRepeat: [ chat retainEvaluation: (SmallGPTalkEvaluationResult new expression: 'nil'; yourself) ].
	self assert: (chat instVarNamed: 'evaluations') items size equals: 100.
	self deny: ((chat instVarNamed: 'evaluations') items includes: result).
	chat closeChat.
	self assert: (chat instVarNamed: 'evaluations') items isEmpty
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testStreamKeepsHeadingStyle [
	| chat text |
	chat := self newChat.
	chat appendHeading: 'SmallGPTalk'.
	chat receiveEvent: (Dictionary new at: #type put: #text; at: #text put: 'First '; yourself).
	chat receiveEvent: (Dictionary new at: #type put: #text; at: #text put: 'second.'; yourself).
	text := (chat instVarNamed: 'history') text.
	self assert: (text asString includesSubstring: 'First second.').
	self assert: ((text attributesAt: 3) includes: TextEmphasis bold).
	self deny: ((text attributesAt: text size) includes: TextEmphasis bold)
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testToolDetailsStayOutsideConversation [
	| chat result text |
	chat := self newChat.
	result := SmallGPTalkEvaluateTool new
		execute: (Dictionary new at: 'source' put: '6 * 7'; yourself)
		context: SmallGPTalkRun new.
	chat receiveEvent: (Dictionary new at: #type put: #toolResult; at: #result put: result; yourself).
	text := (chat instVarNamed: 'history') text asString.
	self assert: (text includesSubstring: 'Evaluation complete.').
	self deny: (text includesSubstring: result text).
	self assert: (chat instVarNamed: 'evaluations') items first identicalTo: result
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testCommittedMessagesAndToolResultsKeepIdentityInView [
	| chat session view call response result final |
	chat := self newChat.
	session := SmallGPTalkSession new.
	chat instVarNamed: 'session' put: session.
	view := chat instVarNamed: 'history'.
	chat appendHeading: 'SmallGPTalk'.
	chat receiveEvent: (Dictionary new at: #type put: #text; at: #text put: 'I will evaluate.'; yourself).
	call := SmallGPTalkToolCall id: 'a' name: 'evaluate' arguments: Dictionary new.
	response := SmallGPTalkMessage assistant: 'I will evaluate.'.
	response toolCalls: { call }.
	session addMessage: response.
	chat receiveEvent: (Dictionary new at: #type put: #toolStarted; at: #call put: call; yourself).
	result := SmallGPTalkToolResult error: 'Invalid expression.'.
	chat receiveEvent: (Dictionary new at: #type put: #toolResult; at: #call put: call; at: #result put: result; yourself).
	final := SmallGPTalkMessage assistant: 'The expression failed.'.
	session addMessage: final.
	chat receiveEvent: (Dictionary new at: #type put: #finished; at: #state put: #completed; at: #error put: nil; at: #result put: final; yourself).
	self assert: (view entries collect: #object) asArray equals: { response. call. result. final }.
	self assert: view entries first object identicalTo: session messages first.
	self assert: view entries last object identicalTo: session messages last
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testNewChatKeepsSelectionsAfterOpeningWindow [
	| chat child |
	chat := self newChat.
	chat installModelOptions: { Dictionary new
		at: 'slug' put: 'gpt-5.6-luna';
		at: 'supported_reasoning_levels' put: {
			Dictionary new at: 'effort' put: 'medium'; yourself.
			Dictionary new at: 'effort' put: 'high'; yourself }; yourself }.
	chat selectModel: 'gpt-5.6-luna' effort: 'high'.
	[
		child := chat newChat.
		self assert: (child instVarNamed: 'models') selectedItem equals: 'gpt-5.6-luna'.
		self assert: (child instVarNamed: 'effort') selectedItem equals: 'high'.
		self assert: (child instVarNamed: 'sendButton') isEnabled
	] ensure: [ child ifNotNil: [ child window close ] ]
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testEmptyExpressionCanBeDisplayed [
	| chat result |
	chat := self newChat.
	result := SmallGPTalkEvaluationResult new expression: ''; yourself.
	chat retainEvaluation: result.
	self assert: (chat instVarNamed: 'evaluations') items first identicalTo: result.
	self assert: ((chat instVarNamed: 'evaluations') displayValueAt: 1) isString
]

{ #category : 'running' }
SmallGPTalkChatTest >> setUp [
	super setUp.
	chats := OrderedCollection new
]

{ #category : 'running' }
SmallGPTalkChatTest >> tearDown [
	[ chats do: [ :chat |
		chat closeChat.
		(chat instVarNamed: 'run') ifNotNil: [ :run | run wait ] ] ]
		ensure: [ super tearDown ]
]

{ #category : 'private' }
SmallGPTalkChatTest >> newChat [
	| chat |
	chat := SmallGPTalkChat new.
	chats add: chat.
	^ chat
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testCompactCommandDoesNotBecomeAUserMessage [
	| chat session provider run |
	chat := self newChat.
	provider := SmallGPTalkCoreTestProvider new responseBlock: [ :request :text :activeRun |
		SmallGPTalkMessage assistant: 'The fixture is ready.' ]; yourself.
	session := SmallGPTalkSession new provider: provider; model: 'fixture'; yourself.
	session addMessage: (SmallGPTalkMessage user: 'Prepare the fixture.');
		addMessage: (SmallGPTalkMessage assistant: 'Done.').
	chat instVarNamed: 'session' put: session.
	(chat instVarNamed: 'input') text: '/compact'.
	chat send.
	run := chat instVarNamed: 'run'.
	self assert: run isNotNil.
	run wait.
	self assert: run state equals: #completed.
	self assert: session messages size equals: 2.
	self assert: session context compactedThrough equals: 2.
	chat updateContextUsage.
	self assert: ((chat instVarNamed: 'contextUsage') label includesSubstring: '%').
	self assert: ((chat contextSnapshot at: #messages) first text includesSubstring: 'fixture is ready')
]
