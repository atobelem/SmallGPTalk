"Execute one user request, supervise operations, and publish ordered progress events."
Class {
	#name : #SmallGPTalkRun,
	#superclass : #Object,
	#instVars : [ 'session', 'input', 'observer', 'state', 'process', 'completion', 'observerErrors', 'result', 'error', 'cancellationRequested', 'reservedResources', 'stateLock', 'pendingCalls', 'cleanupErrors', 'modelTurns' ],
	#category : #'SmallGPTalk-Core'
}


{ #category : #'initialization' }
SmallGPTalkRun >> initialize [
	super initialize.
	state := #pending.
	modelTurns := 0.
	completion := Semaphore new.
	observerErrors := OrderedCollection new.
	cleanupErrors := OrderedCollection new.
	cancellationRequested := false.
	reservedResources := OrderedCollection new.
	stateLock := Semaphore forMutualExclusion.
	pendingCalls := OrderedCollection new.
	observer := [ :event | ]
]

{ #category : #'private' }
SmallGPTalkRun >> start [
	process := [ self execute ] forkAt: Processor userBackgroundPriority
]

{ #category : #'running' }
SmallGPTalkRun >> wait [
	(self isFinished and: [ Processor activeProcess == process ]) ifTrue: [ ^ self ].
	completion wait.
	completion signal.
	^ self
]

{ #category : #'running' }
SmallGPTalkRun >> cancel [
	stateLock critical: [
		self isFinished ifFalse: [
			cancellationRequested := true.
			state := #cancelling ] ].
	^ self
]

{ #category : #'testing' }
SmallGPTalkRun >> isFinished [
	^ #(completed failed cancelled) includes: state
]

{ #category : #'running' }
SmallGPTalkRun >> checkCancellation [
	cancellationRequested ifTrue: [ SmallGPTalkCancelled signal: 'The run was cancelled.' ]
]

{ #category : #'running' }
SmallGPTalkRun >> supervise: aBlock timeoutSeconds: seconds [
	| worker finished value failure deadline |
	self checkCancellation.
	finished := Semaphore new.
	deadline := seconds ifNotNil: [ Time microsecondClockValue + (seconds * 1000000) ].
	worker := [
		[ [ value := aBlock value ]
			on: Error , Halt
			do: [ :exception | failure := exception ] ]
			ensure: [ finished signal ]
	] newProcess.
	worker priority: ((Processor activePriority - 1) max: 1).
	[
		stateLock critical: [ self checkCancellation. worker resume ].
		[ finished waitTimeoutMilliseconds: 10 ] whileTrue: [
			self checkCancellation.
			(deadline notNil and: [ Time microsecondClockValue >= deadline ]) ifTrue: [
				SmallGPTalkTimeout signal: 'The operation exceeded its time limit.' ] ].
		failure ifNotNil: [ failure signal ].
		^ value
	] ensure: [
		worker isTerminated ifFalse: [ worker terminate ].
		[ worker isTerminated ] whileFalse: [ (Delay forMilliseconds: 10) wait ] ]
]

{ #category : 'private' }
SmallGPTalkRun >> execute [
	self finishWithState: self executeRequest
]

{ #category : 'private' }
SmallGPTalkRun >> executeRequest [
	| finalState |
	finalState := #failed.
	[
		[
			stateLock critical: [ cancellationRequested ifFalse: [ state := #running ] ].
			result := self performRequest.
			self checkCancellation.
			finalState := #completed
		] on: SmallGPTalkCancelled do: [ :exception |
			error := SmallGPTalkFailure fromException: exception.
			finalState := #cancelled ]
	] on: Error , Halt do: [ :exception |
		error := SmallGPTalkFailure fromException: exception.
		finalState := #failed ].
	^ finalState
]

{ #category : 'private' }
SmallGPTalkRun >> finishWithState: requestedState [
	| finalState |
	finalState := requestedState.
	[
		[ self cancelPendingCalls ] on: Error , Halt do: [ :exception |
			error := SmallGPTalkFailure fromException: exception. finalState := #failed ].
		[ self releaseResources ] on: Error , Halt do: [ :exception |
			error ifNil: [ error := SmallGPTalkFailure fromException: exception ].
			finalState := #failed ].
		self setFinalState: finalState.
		session releaseRun: self.
		self emit: (Dictionary new
			at: #type put: #finished;
			at: #state put: state;
			at: #result put: result;
			at: #error put: error;
			yourself)
	] ensure: [ completion signal ]
]

{ #category : 'private' }
SmallGPTalkRun >> setFinalState: requestedState [
	| finalState |
	finalState := requestedState.
	stateLock critical: [
		(cancellationRequested and: [ finalState = #completed ]) ifTrue: [
			finalState := #cancelled.
			error := SmallGPTalkFailure fromException: (SmallGPTalkCancelled new messageText: 'The run was cancelled.') ].
		state := finalState.
		state = #completed ifFalse: [ result := nil ] ].
]

{ #category : #'private' }
SmallGPTalkRun >> agentLoop [
	| response |
	1 to: session maxTurns do: [ :turn |
		self checkCancellation.
		session context compactIfNeededUsing: self.
		response := self requestResponse.
		self validateResponse: response.
		session addMessage: response.
		pendingCalls := response toolCalls asOrderedCollection.
		self checkCancellation.
		pendingCalls ifEmpty: [ ^ response ].
		[ pendingCalls notEmpty ] whileTrue: [
			self checkCancellation.
			self executeCall: pendingCalls first ] ].
	self error: 'The run reached its model turn limit.'
]

{ #category : #'private' }
SmallGPTalkRun >> requestResponse [
	self consumeModelTurn.
	^ self supervise: [
		session provider
			respondTo: session
			onText: [ :text |
				self emit: (Dictionary new at: #type put: #text; at: #text put: text; yourself) ]
			run: self
	] timeoutSeconds: self requestTimeoutSeconds
]

{ #category : #'private' }
SmallGPTalkRun >> executeCall: aCall [
	| tool toolResult |
	self emit: (Dictionary new at: #type put: #toolStarted; at: #call put: aCall; yourself).
	self checkCancellation.
	[
		tool := session tools detect: [ :each | each name = aCall name ]
			ifNone: [ self error: 'The requested tool is not supplied.' ].
		aCall argumentError ifNotNil: [ self error: aCall argumentError ].
		tool validateArguments: aCall arguments.
		toolResult := self supervise: [ tool execute: aCall arguments context: self ] timeoutSeconds: nil.
		(toolResult isKindOf: SmallGPTalkToolResult) ifFalse: [ self error: 'The tool did not return a tool result.' ].
		toolResult text isString ifFalse: [ self error: 'The tool result must contain text.' ].
		toolResult := self boundResult: toolResult
	] on: Error , Halt do: [ :exception |
		(exception isKindOf: SmallGPTalkCancelled) ifTrue: [ exception pass ].
		toolResult := self boundResult: (SmallGPTalkToolResult error: exception messageText) ].
	self recordResult: toolResult for: aCall.
	pendingCalls removeFirst
]

{ #category : #'private' }
SmallGPTalkRun >> boundResult: aResult [
	^ aResult limitTextTo: self toolOutputLimit
]

{ #category : #'private' }
SmallGPTalkRun >> recordResult: aResult for: aCall [
	session addMessage: (SmallGPTalkMessage toolResult: aResult for: aCall).
	self emit: (Dictionary new
		at: #type put: #toolResult;
		at: #call put: aCall;
		at: #result put: aResult;
		yourself)
]

{ #category : #'private' }
SmallGPTalkRun >> cancelPendingCalls [
	[ pendingCalls notEmpty ] whileTrue: [
		self recordResult: (self boundResult: (SmallGPTalkToolResult error: 'The tool call was cancelled.')) for: pendingCalls removeFirst ]
]

{ #category : #'private' }
SmallGPTalkRun >> emit: anEvent [
	[ observer value: anEvent ] on: Error , Halt do: [ :exception |
		observerErrors add: (SmallGPTalkFailure fromException: exception) ]
]

{ #category : #'accessing' }
SmallGPTalkRun >> requestTimeoutSeconds [
	^ session ifNil: [ 120 ] ifNotNil: [ session requestTimeoutSeconds ]
]

{ #category : #'accessing' }
SmallGPTalkRun >> toolOutputLimit [
	^ session ifNil: [ 20000 ] ifNotNil: [ session toolOutputLimit ]
]

{ #category : #'accessing' }
SmallGPTalkRun >> state [
	^ state
]

{ #category : #'accessing' }
SmallGPTalkRun >> result [
	^ result
]

{ #category : 'error handling' }
SmallGPTalkRun >> error [
	^ error
]

{ #category : #'accessing' }
SmallGPTalkRun >> observerErrors [
	^ observerErrors copy
]

{ #category : #'private' }
SmallGPTalkRun >> session: anObject [
	session := anObject
]

{ #category : #'private' }
SmallGPTalkRun >> input: anObject [
	input := anObject
]

{ #category : #'private' }
SmallGPTalkRun >> observer: anObject [
	observer := anObject
]

{ #category : #'private' }
SmallGPTalkRun >> validateResponse: aMessage [
	| identifiers |
	(aMessage isKindOf: SmallGPTalkMessage) ifFalse: [ self error: 'The provider did not return a complete message.' ].
	aMessage role = #assistant ifFalse: [ self error: 'The provider message must have the assistant role.' ].
	aMessage text isString ifFalse: [ self error: 'The provider message must contain text.' ].
	(aMessage toolCalls isKindOf: SequenceableCollection) ifFalse: [ self error: 'The provider tool calls must be a sequence.' ].
	identifiers := Set new.
	aMessage toolCalls do: [ :call |
		(call isKindOf: SmallGPTalkToolCall) ifFalse: [ self error: 'The provider returned an invalid tool call.' ].
		(call id isString and: [ call id isNotEmpty ]) ifFalse: [ self error: 'A tool call must have an identifier.' ].
		(call name isString and: [ call name isNotEmpty ]) ifFalse: [ self error: 'A tool call must have a name.' ].
		(identifiers includes: call id) ifTrue: [ self error: 'Tool call identifiers must be unique.' ].
		identifiers add: call id ]
]

{ #category : 'private' }
SmallGPTalkRun >> reserveResources [
	[
		session tools do: [ :tool |
			tool executionResources do: [ :resource |
				(reservedResources includes: resource) ifFalse: [
					resource reserveFor: self.
					reservedResources add: resource ] ] ]
	] on: Error , Halt do: [ :exception |
		[ self releaseResources ] on: Error , Halt do: [ :ignored | ].
		exception pass ]
]

{ #category : 'private' }
SmallGPTalkRun >> releaseResources [
	| firstFailure |
	reservedResources reverseDo: [ :resource |
		[ resource releaseFor: self ] on: Error , Halt do: [ :exception |
			cleanupErrors add: (SmallGPTalkFailure fromException: exception).
			firstFailure ifNil: [ firstFailure := exception ] ] ].
	reservedResources removeAll.
	firstFailure ifNotNil: [ firstFailure signal ]
]

{ #category : 'accessing' }
SmallGPTalkRun >> cleanupErrors [
	^ cleanupErrors copy
]

{ #category : 'private' }
SmallGPTalkRun >> performRequest [
	session addMessage: (SmallGPTalkMessage user: input).
	self checkCancellation.
	^ self agentLoop
]

{ #category : 'private' }
SmallGPTalkRun >> commitContext: aBlock [
	stateLock critical: [ self checkCancellation. aBlock value ]
]

{ #category : 'accessing' }
SmallGPTalkRun >> contextSnapshot [
	| snapshot |
	snapshot := session ifNil: [ Dictionary new ] ifNotNil: [ session context snapshot ].
	^ snapshot
		at: #run put: self;
		at: #toolCall put: (pendingCalls ifEmpty: [ nil ] ifNotEmpty: [ pendingCalls first ]);
		yourself
]

{ #category : 'private' }
SmallGPTalkRun >> consumeModelTurn [
	self checkCancellation.
	modelTurns >= session maxTurns ifTrue: [ self error: 'The run reached its model turn limit.' ].
	modelTurns := modelTurns + 1
]
