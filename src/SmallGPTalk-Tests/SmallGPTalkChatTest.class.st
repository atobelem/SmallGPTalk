Class {
	#name : 'SmallGPTalkChatTest',
	#superclass : 'TestCase',
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkChatTest >> testRequiresExplicitModel [
	| chat |
	chat := SmallGPTalkChat new.
	self assert: (chat instVarNamed: 'models') selectedItem isNil.
	self deny: (chat instVarNamed: 'sendButton') isEnabled
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testSendAndContinueConversation [
	| chat provider pending firstRun |
	chat := SmallGPTalkChat new.
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
	chat := SmallGPTalkChat new.
	started := Semaphore new.
	provider := SmallGPTalkCoreTestProvider new responseBlock: [ :session :text :run |
		started signal.
		Semaphore new wait ].
	chat instVarNamed: 'provider' put: provider.
	(chat instVarNamed: 'models') items: #('test-model'); selectFirst.
	(chat instVarNamed: 'input') text: 'Wait'.
	chat send.
	started wait.
	chat closeChat.
	(chat instVarNamed: 'run') wait.
	self assert: (chat instVarNamed: 'run') state equals: #cancelled
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testFailureKeepsPartialTextAndShowsState [
	| chat |
	chat := SmallGPTalkChat new.
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
	chat := SmallGPTalkChat new.
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
	chat := SmallGPTalkChat new.
	chat installModelOptions: { Dictionary new at: 'slug' put: 'another-model'; yourself }.
	self assert: (chat instVarNamed: 'models') selectedItem isNil.
	self deny: (chat instVarNamed: 'sendButton') isEnabled
]
