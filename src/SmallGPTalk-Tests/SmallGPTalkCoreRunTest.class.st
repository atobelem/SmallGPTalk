Class {
	#name : #SmallGPTalkCoreRunTest,
	#superclass : #TestCase,
	#instVars : [ 'provider', 'session', 'tool', 'events', 'runs' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : #'running' }
SmallGPTalkCoreRunTest >> setUp [
	super setUp.
	provider := SmallGPTalkCoreTestProvider new.
	provider responseBlock: [ :aSession :onText :aRun | SmallGPTalkMessage assistant: 'Complete.' ].
	tool := SmallGPTalkCoreTestTool new.
	session := SmallGPTalkSession new provider: provider; model: 'test-model'; tools: { tool }; yourself.
	events := OrderedCollection new.
	runs := OrderedCollection new
]

{ #category : #'running' }
SmallGPTalkCoreRunTest >> tearDown [
	runs do: [ :run | run isFinished ifFalse: [ run cancel. run wait ] ].
	super tearDown
]

{ #category : #'helpers' }
SmallGPTalkCoreRunTest >> start [
	^ runs add: (session send: 'Start.' onEvent: [ :event | events add: event ])
]

{ #category : #'helpers' }
SmallGPTalkCoreRunTest >> waitFor: run [
	| done waiter |
	done := Semaphore new.
	waiter := [ run wait. done signal ] fork.
	[ self deny: (done waitTimeoutMilliseconds: 3000) description: 'The run did not stop.' ] ensure: [ waiter terminate ]
]

{ #category : #'helpers' }
SmallGPTalkCoreRunTest >> call: anId [
	^ SmallGPTalkToolCall id: anId name: 'fixture' arguments: (Dictionary new at: 'text' put: anId; yourself)
]

{ #category : #'helpers' }
SmallGPTalkCoreRunTest >> responseWith: calls [
	^ (SmallGPTalkMessage assistant: '') toolCalls: calls; yourself
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testDefaultConfiguration [
	self assert: session maxTurns equals: 20.
	self assert: session requestTimeoutSeconds equals: 120.
	self assert: session toolOutputLimit equals: 20000.
	self assert: SmallGPTalkSession new tools isEmpty
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testSimpleRunAndContinuation [
	| run next |
	run := self start.
	self waitFor: run.
	self assert: run state equals: #completed.
	self assert: run wait identicalTo: run.
	self assert: run result text equals: 'Complete.'.
	self assert: (session messages collect: #role) asArray equals: #(user assistant).
	next := self start.
	self waitFor: next.
	self assert: session messages size equals: 4.
	self assert: provider requestCount equals: 2.
	self assert: (events select: [ :each | (each at: #type) = #finished ]) size equals: 2
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testToolsRunInOrderAndResultsKeepCallIds [
	| run seen |
	seen := OrderedCollection new.
	tool action: [ :arguments :aRun | seen add: (arguments at: 'text'). SmallGPTalkToolResult text: (arguments at: 'text') ].
	provider responseBlock: [ :aSession :onText :aRun |
		provider requestCount = 1
			ifTrue: [ self responseWith: { self call: 'one'. self call: 'two' } ]
			ifFalse: [ onText value: 'Complete.'. SmallGPTalkMessage assistant: 'Complete.' ] ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #completed.
	self assert: seen asArray equals: #('one' 'two').
	self assert: ((session messages select: [ :each | each role = #tool ]) collect: #callId) asArray equals: #('one' 'two').
	self assert: (events collect: [ :each | each at: #type ]) asArray equals: #(toolStarted toolResult toolStarted toolResult text finished)
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testToolFailureReturnsToModel [
	| run |
	tool action: [ :arguments :aRun | self error: 'The test operation failed.' ].
	provider responseBlock: [ :aSession :onText :aRun |
		provider requestCount = 1 ifTrue: [ self responseWith: { self call: 'one' } ] ifFalse: [ SmallGPTalkMessage assistant: 'Corrected.' ] ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #completed.
	self assert: (session messages at: 3) isError.
	self assert: tool executionCount equals: 1
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testInvalidArgumentsDoNotExecute [
	| run invalid |
	invalid := self call: 'one'.
	invalid arguments: Dictionary new.
	provider responseBlock: [ :aSession :onText :aRun |
		provider requestCount = 1 ifTrue: [ self responseWith: { invalid } ] ifFalse: [ SmallGPTalkMessage assistant: 'Corrected.' ] ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #completed.
	self assert: (session messages at: 3) isError.
	self assert: tool executionCount equals: 0
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testInvalidJsonArgumentsReturnToolError [
	| run invalid |
	invalid := (self call: 'one') argumentError: 'Tool arguments must be valid JSON.'; yourself.
	provider responseBlock: [ :aSession :onText :aRun |
		provider requestCount = 1 ifTrue: [ self responseWith: { invalid } ] ifFalse: [ SmallGPTalkMessage assistant: 'Corrected.' ] ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #completed.
	self assert: (session messages at: 3) text equals: 'Tool arguments must be valid JSON.'.
	self assert: tool executionCount equals: 0
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testUnknownToolReturnsToolError [
	| run invalid |
	invalid := (self call: 'one') name: 'missing'; yourself.
	provider responseBlock: [ :aSession :onText :aRun |
		provider requestCount = 1 ifTrue: [ self responseWith: { invalid } ] ifFalse: [ SmallGPTalkMessage assistant: 'Corrected.' ] ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #completed.
	self assert: (session messages at: 3) isError.
	self assert: tool executionCount equals: 0
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testIncompleteResponseIsNotCommitted [
	| run |
	provider responseBlock: [ :aSession :onText :aRun |
		onText value: 'Partial'.
		self error: 'The stream ended before completion.' ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #failed.
	self assert: session messages size equals: 1.
	self assert: tool executionCount equals: 0.
	self assert: run result isNil
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testTurnLimitPreservesCompleteToolWork [
	| run |
	session maxTurns: 2.
	provider responseBlock: [ :aSession :onText :aRun | self responseWith: { self call: provider requestCount asString } ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #failed.
	self assert: provider requestCount equals: 2.
	self assert: tool executionCount equals: 2.
	self assert: session messages size equals: 5
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testObserverFailureDoesNotRepeatToolWork [
	| run finishedState |
	provider responseBlock: [ :aSession :onText :aRun |
		provider requestCount = 1 ifTrue: [ self responseWith: { self call: 'one' } ] ifFalse: [ SmallGPTalkMessage assistant: 'Complete.' ] ].
	run := runs add: (session send: 'Start.' onEvent: [ :event |
		events add: event.
		(event at: #type) = #finished ifTrue: [ finishedState := event at: #state ].
		self error: 'The observer failed.' ]).
	self waitFor: run.
	self assert: run state equals: #completed.
	self assert: finishedState equals: #completed.
	self assert: run observerErrors size equals: 3.
	self assert: tool executionCount equals: 1.
	self assert: (events count: [ :each | (each at: #type) = #finished ]) equals: 1
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testCancellationPreservesCompletedWorkAndCancelsPendingCalls [
	| run |
	tool action: [ :arguments :aRun | aRun cancel. SmallGPTalkToolResult text: 'Changed.' ].
	provider responseBlock: [ :aSession :onText :aRun | self responseWith: { self call: 'one'. self call: 'two' } ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #cancelled.
	self assert: provider requestCount equals: 1.
	self assert: tool executionCount equals: 1.
	self assert: (session messages at: 3) text equals: 'Changed.'.
	self assert: (session messages at: 4) callId equals: 'two'.
	self assert: (session messages at: 4) isError
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testCancelStopsOrdinarySmalltalkAndRunsEnsure [
	| run entered stopped |
	entered := Semaphore new.
	stopped := false.
	tool action: [ :arguments :aRun |
		[ entered signal. [ true ] whileTrue ] ensure: [ stopped := true ] ].
	provider responseBlock: [ :aSession :onText :aRun | self responseWith: { self call: 'one' } ].
	run := self start.
	self deny: (entered waitTimeoutMilliseconds: 1000).
	run cancel.
	self waitFor: run.
	self assert: stopped.
	self assert: run state equals: #cancelled.
	self assert: (session messages at: 3) isError
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testRequestTimeoutStopsWorker [
	| run stopped |
	stopped := false.
	session requestTimeoutSeconds: 0.03.
	provider responseBlock: [ :aSession :onText :aRun |
		[ [ true ] whileTrue ] ensure: [ stopped := true ] ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #failed.
	self assert: run error exceptionClassName equals: 'SmallGPTalkTimeout'.
	self assert: stopped.
	self assert: session messages size equals: 1
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testNestedSupervisionStopsWorkers [
	| run stopped |
	stopped := false.
	provider responseBlock: [ :aSession :onText :aRun |
		aRun supervise: [ [ [ true ] whileTrue ] ensure: [ stopped := true ] ] timeoutSeconds: 0.03 ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #failed.
	self assert: run error exceptionClassName equals: 'SmallGPTalkTimeout'.
	self assert: stopped
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testSessionRejectsConcurrentRuns [
	| run entered gate |
	entered := Semaphore new.
	gate := Semaphore new.
	provider responseBlock: [ :aSession :onText :aRun | entered signal. gate wait. SmallGPTalkMessage assistant: 'Complete.' ].
	run := self start.
	self deny: (entered waitTimeoutMilliseconds: 1000).
	self should: [ self start ] raise: Error.
	self should: [ session model: 'other-model' ] raise: Error.
	gate signal.
	self waitFor: run.
	self assert: run state equals: #completed.
	self assert: session activeRun isNil
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testImageLeaseIsSharedAndReleased [
	| run entered gate other next |
	entered := Semaphore new.
	gate := Semaphore new.
	tool imageTool: true.
	provider responseBlock: [ :aSession :onText :aRun | entered signal. gate wait. SmallGPTalkMessage assistant: 'Complete.' ].
	run := self start.
	self deny: (entered waitTimeoutMilliseconds: 1000).
	other := SmallGPTalkSession new provider: provider; model: 'test-model'; tools: { tool }; yourself.
	self should: [ other send: 'Start.' onEvent: [ :event | ] ] raise: Error.
	gate signal.
	self waitFor: run.
	gate signal.
	next := runs add: (other send: 'Start.' onEvent: [ :event | ]).
	self waitFor: next.
	self assert: next state equals: #completed
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testImageLeaseIsReleasedAfterFailure [
	| run next |
	tool imageTool: true.
	provider responseBlock: [ :aSession :onText :aRun | self error: 'The request failed.' ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #failed.
	provider responseBlock: [ :aSession :onText :aRun | SmallGPTalkMessage assistant: 'Complete.' ].
	next := self start.
	self waitFor: next.
	self assert: next state equals: #completed
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testToolOutputIsBoundedAndMarked [
	| run toolEvent |
	session toolOutputLimit: 40.
	tool action: [ :arguments :aRun | SmallGPTalkToolResult text: (String new: 100 withAll: $x) ].
	provider responseBlock: [ :aSession :onText :aRun |
		provider requestCount = 1 ifTrue: [ self responseWith: { self call: 'one' } ] ifFalse: [ SmallGPTalkMessage assistant: 'Complete.' ] ].
	run := self start.
	self waitFor: run.
	toolEvent := events detect: [ :each | (each at: #type) = #toolResult ].
	self assert: (toolEvent at: #result) truncated.
	self assert: (toolEvent at: #result) text size equals: 40.
	self assert: ((session messages at: 3) text includesSubstring: '[Output truncated]')
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testModelSelectionIsRequired [
	session model: nil.
	self should: [ self start ] raise: Error.
	self assert: provider requestCount equals: 0
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testTerminalObserverCanWaitAndReadFinalState [
	| run gate observed |
	gate := Semaphore new.
	observed := Semaphore new.
	provider responseBlock: [ :aSession :onText :aRun | gate wait. SmallGPTalkMessage assistant: 'Complete.' ].
	run := runs add: (session send: 'Start.' onEvent: [ :event |
		(event at: #type) = #finished ifTrue: [
			self assert: run wait identicalTo: run.
			self assert: run state equals: #completed.
			self assert: session activeRun isNil.
			observed signal ] ]).
	gate signal.
	self deny: (observed waitTimeoutMilliseconds: 1000).
	self waitFor: run.
	self assert: run observerErrors isEmpty
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testInvalidProviderCallFailsBeforeCommitAndReleasesImage [
	| run next |
	tool imageTool: true.
	provider responseBlock: [ :aSession :onText :aRun | self responseWith: #(3) ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #failed.
	self assert: session messages size equals: 1.
	self assert: session activeRun isNil.
	self assert: (events count: [ :each | (each at: #type) = #finished ]) equals: 1.
	provider responseBlock: [ :aSession :onText :aRun | SmallGPTalkMessage assistant: 'Complete.' ].
	next := self start.
	self waitFor: next.
	self assert: next state equals: #completed
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testInvalidToolResultReturnsToModel [
	| run |
	tool action: [ :arguments :aRun | SmallGPTalkToolResult text: nil ].
	provider responseBlock: [ :aSession :onText :aRun |
		provider requestCount = 1 ifTrue: [ self responseWith: { self call: 'one' } ] ifFalse: [ SmallGPTalkMessage assistant: 'Corrected.' ] ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #completed.
	self assert: (session messages at: 3) isError.
	self assert: (session messages at: 3) text equals: 'The tool result must contain text.'.
	self assert: tool executionCount equals: 1
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testToolsAccessorDoesNotExposeCollectionMutation [
	| exposed |
	exposed := session tools.
	exposed at: 1 put: (SmallGPTalkCoreTestTool new imageTool: true; yourself).
	self assert: session tools first identicalTo: tool.
	self assert: session tools first executionResources isEmpty
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testImmediateCancellationDoesNotRequestModel [
	| run |
	run := self start.
	run cancel.
	self waitFor: run.
	self assert: run state equals: #cancelled.
	self assert: provider requestCount equals: 0.
	self assert: session messages size equals: 1
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testCancellationAfterCompletionDoesNotChangeState [
	| run |
	run := self start.
	self waitFor: run.
	run cancel.
	self assert: run state equals: #completed.
	self assert: run result text equals: 'Complete.'.
	self assert: (events count: [ :each | (each at: #type) = #finished ]) equals: 1
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testFailedSecondRequestDoesNotReplayCompletedMutation [
	| run |
	provider responseBlock: [ :aSession :onText :aRun |
		provider requestCount = 1 ifTrue: [ self responseWith: { self call: 'one' } ] ifFalse: [ self error: 'The next request failed.' ] ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #failed.
	self assert: session messages size equals: 3.
	self assert: (session messages at: 3) callId equals: 'one'.
	self assert: tool executionCount equals: 1.
	self assert: provider requestCount equals: 2
]

{ #category : #'tests' }
SmallGPTalkCoreRunTest >> testFailureDoesNotKeepExceptionContexts [
	| run |
	provider responseBlock: [ :aSession :onText :aRun | self error: 'The request failed.' ].
	run := self start.
	self waitFor: run.
	self assert: run error class equals: SmallGPTalkFailure.
	self assert: run error exceptionClassName equals: 'Error'.
	self assert: run error messageText equals: 'The request failed.'.
	self deny: (run error respondsTo: #signalContext).
	self assert: SmallGPTalkFailure allInstVarNames equals: #(exceptionClassName messageText status)
]

{ #category : 'tests' }
SmallGPTalkCoreRunTest >> testFailedResourceReservationReleasesEarlierResources [
	| run |
	tool executionResources: { SmallGPTalkImageAccess. Object new }.
	self should: [ self start ] raise: Error.
	self assert: session activeRun isNil.
	self assert: session messages isEmpty.
	tool executionResources: { SmallGPTalkImageAccess. SmallGPTalkImageAccess }.
	provider responseBlock: [ :aSession :onText :aRun | SmallGPTalkMessage assistant: 'Done.' ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #completed
]

{ #category : 'tests' }
SmallGPTalkCoreRunTest >> testReleaseFailureFinishesRunAndReleasesOtherResources [
	| broken other run terminal |
	broken := SmallGPTalkTestResource new failRelease: true; yourself.
	other := SmallGPTalkTestResource new.
	tool executionResources: { other. broken }.
	run := self start.
	self waitFor: run.
	self assert: run state equals: #failed.
	self assert: session activeRun isNil.
	self assert: run result isNil.
	self assert: run cleanupErrors size equals: 1.
	self assert: other releaseCount equals: 1.
	self assert: broken releaseCount equals: 1.
	terminal := events select: [ :event | (event at: #type) = #finished ].
	self assert: terminal size equals: 1.
	self assert: (terminal first at: #state) equals: #failed.
	self assert: session messages last text equals: 'Complete.'.
	broken failRelease: false.
	run := self start.
	self waitFor: run.
	self assert: run state equals: #completed
]

{ #category : 'tests' }
SmallGPTalkCoreRunTest >> testReservationFailureKeepsOriginalErrorWhenCleanupFails [
	| broken message |
	broken := SmallGPTalkTestResource new failRelease: true; yourself.
	tool executionResources: { broken. Object new }.
	[ self start ] on: Error do: [ :error | message := error messageText ].
	self assert: (message includesSubstring: 'reserveFor:').
	self assert: broken releaseCount equals: 1.
	self assert: session activeRun isNil
]

{ #category : 'tests' }
SmallGPTalkCoreRunTest >> testRepeatedCallIdDoesNotExecuteAgain [
	| run response |
	response := SmallGPTalkMessage assistant: ''.
	response toolCalls: { SmallGPTalkToolCall id: 'repeated' name: 'fixture'
		arguments: (Dictionary new at: 'text' put: 'Hello'; yourself) }.
	provider responseBlock: [ :aSession :onText :aRun | response copy ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #failed.
	self assert: tool executionCount equals: 1.
	self assert: session messages size equals: 3.
	self assert: (run error messageText includesSubstring: 'unique in the conversation')
]

{ #category : 'tests' }
SmallGPTalkCoreRunTest >> testRequestFailureKeepsOriginalErrorWhenCleanupFails [
	| broken run terminal |
	broken := SmallGPTalkTestResource new failRelease: true; yourself.
	tool executionResources: { broken }.
	provider responseBlock: [ :aSession :onText :aRun | self error: 'Model request failed.' ].
	run := self start.
	self waitFor: run.
	self assert: run state equals: #failed.
	self assert: run error messageText equals: 'Model request failed.'.
	self assert: run cleanupErrors size equals: 1.
	self assert: run cleanupErrors first messageText equals: 'Resource release failed.'.
	self assert: broken releaseCount equals: 1.
	self assert: session activeRun isNil.
	self assert: run result isNil.
	self assert: session messages size equals: 1.
	terminal := events select: [ :event | (event at: #type) = #finished ].
	self assert: terminal size equals: 1.
	self assert: (terminal first at: #error) identicalTo: run error
]

{ #category : 'tests' }
SmallGPTalkCoreRunTest >> testOutputLimitPreservesResultIdentityAndFlags [
	| run result |
	run := SmallGPTalkRun new session: session; yourself.
	session toolOutputLimit: 40.
	result := SmallGPTalkToolResult error: 'Short error.'.
	self assert: (run boundResult: result) identicalTo: result.
	self assert: result text equals: 'Short error.'.
	self assert: result isError.
	self deny: result truncated.
	result text: (String new: 100 withAll: $x).
	self assert: (run boundResult: result) identicalTo: result.
	self assert: result isError.
	self assert: result truncated.
	self assert: result text size equals: 40
]

{ #category : 'tests' }
SmallGPTalkCoreRunTest >> testOutputLimitSmallerThanMarker [
	| run result |
	run := SmallGPTalkRun new session: session; yourself.
	#(1 5 18 19 20) do: [ :limit |
		session toolOutputLimit: limit.
		result := run boundResult: (SmallGPTalkToolResult text: (String new: 100 withAll: $x)).
		self assert: result text size equals: limit.
		self assert: result truncated ]
]
