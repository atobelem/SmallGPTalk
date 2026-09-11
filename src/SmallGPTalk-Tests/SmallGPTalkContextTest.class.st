"Check context reduction without deleting history or executing tools."
Class {
	#name : 'SmallGPTalkContextTest',
	#superclass : 'TestCase',
	#instVars : [ 'session', 'provider', 'run' ],
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkContextTest >> setUp [
	super setUp.
	provider := SmallGPTalkCoreTestProvider new responseBlock: [ :request :text :activeRun |
		SmallGPTalkMessage assistant: 'Keep the fixture and its passing tests.' ]; yourself.
	session := SmallGPTalkSession new provider: provider; model: 'fixture'; yourself.
	session addMessage: (SmallGPTalkMessage user: 'Repair the fixture.');
		addMessage: (SmallGPTalkMessage assistant: 'The fixture is repaired.')
]

{ #category : 'running' }
SmallGPTalkContextTest >> tearDown [
	[ run ifNotNil: [ run cancel; wait ] ] ensure: [ super tearDown ]
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testManualCompactionKeepsHistory [
	| history |
	history := session messages.
	run := session compactOnEvent: [ :event | ].
	run wait.
	self assert: run state equals: #completed.
	self assert: session messages equals: history.
	self assert: session messages first identicalTo: history first.
	self assert: session context messages size equals: 1.
	self assert: (session context messages first text includesSubstring: 'Keep the fixture').
	self assert: session context compactedThrough equals: 2
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testFailedCompactionKeepsContext [
	| before |
	before := session context messages.
	provider responseBlock: [ :request :text :activeRun | self error: 'Summary failed.' ].
	run := session compactOnEvent: [ :event | ].
	run wait.
	self assert: run state equals: #failed.
	self assert: session context messages equals: before.
	self assert: session context compactedThrough equals: 0
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testCompactionCannotExecuteTools [
	| tool |
	tool := SmallGPTalkCoreTestTool new.
	session tools: { tool }.
	provider responseBlock: [ :request :text :activeRun |
		self assert: request tools isEmpty.
		(SmallGPTalkMessage assistant: '') toolCalls: {
			SmallGPTalkToolCall id: 'unexpected' name: 'fixture' arguments: Dictionary new }; yourself ].
	run := session compactOnEvent: [ :event | ].
	run wait.
	self assert: run state equals: #failed.
	self assert: tool executionCount equals: 0.
	self assert: session context compactedThrough equals: 0
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testAutomaticCompactionKeepsCurrentRequest [
	| requests |
	requests := OrderedCollection new.
	session context autoCompactLimit: 1.
	provider responseBlock: [ :request :text :activeRun |
		requests add: request context messages.
		SmallGPTalkMessage assistant: (provider requestCount = 1 ifTrue: [ 'Summary.' ] ifFalse: [ 'Done.' ]) ].
	run := session send: 'Now explain the repair.' onEvent: [ :event | ].
	run wait.
	self assert: run state equals: #completed.
	self assert: provider requestCount equals: 2.
	self assert: requests last last text equals: 'Now explain the repair.'.
	self assert: (requests last first text includesSubstring: 'Summary.').
	self assert: session messages size equals: 4.
	self assert: session context messages size equals: 3
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testCanDisableAutomaticCompaction [
	session context autoCompactLimit: nil.
	run := session send: 'Continue.' onEvent: [ :event | ].
	run wait.
	self assert: run state equals: #completed.
	self assert: provider requestCount equals: 1.
	self assert: session context compactedThrough equals: 0
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testCancelCompactionKeepsContext [
	| started before |
	started := Semaphore new.
	before := session messages.
	provider responseBlock: [ :request :text :activeRun | started signal. Semaphore new wait ].
	run := session compactOnEvent: [ :event | ].
	self deny: (started waitTimeoutMilliseconds: 2000).
	self should: [ session send: 'Concurrent.' onEvent: [ :event | ] ] raise: Error.
	run cancel; wait.
	self assert: run state equals: #cancelled.
	self assert: session context messages equals: before
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testInspectableContextContainsActiveObjects [
	| snapshot |
	snapshot := session context snapshot.
	self assert: (snapshot at: #messages) first identicalTo: session messages first.
	self assert: (snapshot at: #model) equals: 'fixture'.
	self assert: (snapshot at: #instructions) equals: session instructions.
	self assert: (snapshot at: #tools) isEmpty.
	self deny: (snapshot includesKey: #provider).
	self assert: session context characterCount > 0
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testUsagePercentageUsesConfiguredCharacterLimit [
	| size |
	size := session context characterCount.
	session context autoCompactLimit: size * 2.
	self assert: session context usagePercent equals: 50.
	session context autoCompactLimit: nil.
	self assert: session context usagePercent isNil
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testAutomaticCompactionKeepsCurrentToolTurnTogether [
	| tool |
	tool := SmallGPTalkCoreTestTool new.
	session tools: { tool }.
	session context autoCompactLimit: 1.
	provider responseBlock: [ :request :text :activeRun |
		provider requestCount = 1 ifTrue: [ SmallGPTalkMessage assistant: 'Summary.' ] ifFalse: [
			provider requestCount = 2 ifTrue: [
				(SmallGPTalkMessage assistant: '') toolCalls: {
					SmallGPTalkToolCall id: 'one' name: 'fixture'
						arguments: (Dictionary new at: 'text' put: 'work'; yourself) }; yourself ] ifFalse: [
				self assert: request context messages size equals: 4.
				self assert: request context messages last callId equals: 'one'.
				SmallGPTalkMessage assistant: 'Done.' ] ] ].
	run := session send: 'Use the fixture.' onEvent: [ :event | ].
	run wait.
	self assert: run state equals: #completed.
	self assert: provider requestCount equals: 3.
	self assert: tool executionCount equals: 1.
	self assert: session context compactedThrough equals: 2
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testProviderUsesCompactedContext [
	| body |
	run := session compactOnEvent: [ :event | ].
	run wait.
	body := SmallGPTalkOpenAIProvider new requestBodyFor: session.
	self assert: (body at: 'input') size equals: 1.
	self assert: (((body at: 'input') first at: 'content') includesSubstring: 'Keep the fixture').
	self assert: session messages size equals: 2
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testLaterCompactionUsesSummaryAndNewMessages [
	| seen |
	run := session compactOnEvent: [ :event | ].
	run wait.
	session addMessage: (SmallGPTalkMessage user: 'Add a second check.');
		addMessage: (SmallGPTalkMessage assistant: 'The second check passes.').
	provider responseBlock: [ :request :text :activeRun |
		seen := request context messages.
		SmallGPTalkMessage assistant: 'The fixture and both checks are ready.' ].
	run := session compactOnEvent: [ :event | ].
	run wait.
	self assert: run state equals: #completed.
	self assert: seen size equals: 4.
	self assert: (seen first text includesSubstring: 'Keep the fixture').
	self assert: seen second text equals: 'Add a second check.'.
	self assert: session messages size equals: 4.
	self assert: session context compactedThrough equals: 4
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testAutomaticFailurePreservesCurrentUserMessage [
	session context autoCompactLimit: 1.
	provider responseBlock: [ :request :text :activeRun | self error: 'Summary failed.' ].
	run := session send: 'Keep this request.' onEvent: [ :event | ].
	run wait.
	self assert: run state equals: #failed.
	self assert: session messages last text equals: 'Keep this request.'.
	self assert: session context compactedThrough equals: 0.
	self assert: provider requestCount equals: 1
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testEmptyConversationDoesNotRequestSummary [
	session := SmallGPTalkSession new provider: provider; model: 'fixture'; yourself.
	run := session compactOnEvent: [ :event | ].
	run wait.
	self assert: run state equals: #completed.
	self assert: provider requestCount equals: 0.
	self assert: session messages isEmpty
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testInvalidAutomaticLimitsAreRejected [
	#(0 -1 1.5 'large') do: [ :limit |
		self should: [ session context autoCompactLimit: limit ] raise: Error ].
	self assert: session context autoCompactLimit equals: 60000
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testAutomaticSummaryUsesTheRunTurnBudget [
	session context autoCompactLimit: 1.
	session maxTurns: 1.
	run := session send: 'Continue.' onEvent: [ :event | ].
	run wait.
	self assert: run state equals: #failed.
	self assert: provider requestCount equals: 1.
	self assert: (run error messageText includesSubstring: 'turn limit').
	self assert: session messages last text equals: 'Continue.'
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testEmptySummaryPreservesContext [
 | before |
 before := session context messages.
 provider responseBlock: [ :request :text :activeRun | SmallGPTalkMessage assistant: '   ' ].
 run := session compactOnEvent: [ :event | ].
 run wait.
 self assert: run state equals: #failed.
 self assert: session context messages equals: before.
 self assert: session context summary isNil
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testSummaryTimeoutStopsWorkerAndPreservesContext [
 | before stopped |
 before := session context messages.
 stopped := false.
 session requestTimeoutSeconds: 0.1.
 provider responseBlock: [ :request :text :activeRun |
  [ Semaphore new wait ] ensure: [ stopped := true ] ].
 run := session compactOnEvent: [ :event | ].
 run wait.
 self assert: run state equals: #failed.
 self assert: (run error messageText includesSubstring: 'time limit').
 self assert: stopped.
 self assert: session context messages equals: before.
 self assert: session activeRun isNil
]

{ #category : 'tests' }
SmallGPTalkContextTest >> testObserverFailuresDoNotRepeatCompaction [
 | events |
 events := OrderedCollection new.
 run := session compactOnEvent: [ :event |
  events add: (event at: #type).
  (event at: #type) = #finished ifTrue: [ self assert: (event at: #state) equals: #completed ].
  self error: 'The observer failed.' ].
 run wait.
 self assert: run state equals: #completed.
 self assert: events asArray equals: #(compactionStarted compacted finished).
 self assert: run observerErrors size equals: 3.
 self assert: provider requestCount equals: 1.
 self assert: session context compactedThrough equals: 2.
 self assert: session messages size equals: 2
]
