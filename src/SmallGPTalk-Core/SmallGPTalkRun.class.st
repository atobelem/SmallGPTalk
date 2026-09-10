Class {
	#name : #SmallGPTalkRun,
	#superclass : #Object,
	#instVars : [ 'session', 'input', 'observer', 'state', 'process', 'completion', 'observerErrors', 'result', 'error', 'cancellationRequested', 'imageLease', 'stateLock', 'pendingCalls' ],
	#classVars : [ 'ImageLock', 'ImageRun' ],
	#category : #'SmallGPTalk-Core'
}

{ #category : #'initialization' }
SmallGPTalkRun class >> initialize [
	ImageLock := Semaphore forMutualExclusion
]

{ #category : #'private' }
SmallGPTalkRun class >> reserveImageFor: aRun [
	ImageLock ifNil: [ self initialize ].
	ImageLock critical: [
		ImageRun ifNotNil: [ self error: 'This image has an active run with image tools.' ].
		ImageRun := aRun ]
]

{ #category : #'private' }
SmallGPTalkRun class >> releaseImageFor: aRun [
	ImageLock critical: [ ImageRun == aRun ifTrue: [ ImageRun := nil ] ]
]

{ #category : #'initialization' }
SmallGPTalkRun >> initialize [
	super initialize.
	state := #pending.
	completion := Semaphore new.
	observerErrors := OrderedCollection new.
	cancellationRequested := false.
	imageLease := false.
	stateLock := Semaphore forMutualExclusion.
	pendingCalls := OrderedCollection new.
	observer := [ :event | ]
]

{ #category : #'private' }
SmallGPTalkRun >> reserveImage [
	(session tools anySatisfy: #requiresImage) ifTrue: [
		self class reserveImageFor: self.
		imageLease := true ]
]

{ #category : #'private' }
SmallGPTalkRun >> releaseImage [
	imageLease ifTrue: [
		self class releaseImageFor: self.
		imageLease := false ]
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

{ #category : #'private' }
SmallGPTalkRun >> execute [
	| finalState |
	finalState := #failed.
	[
		[
			stateLock critical: [ cancellationRequested ifFalse: [ state := #running ] ].
			session addMessage: (SmallGPTalkMessage user: input).
			self checkCancellation.
			result := self agentLoop.
			self checkCancellation.
			finalState := #completed
		] on: SmallGPTalkCancelled do: [ :exception |
			error := SmallGPTalkFailure fromException: exception.
			finalState := #cancelled ]
	] on: Error , Halt do: [ :exception |
		error := SmallGPTalkFailure fromException: exception.
		finalState := #failed ].
	[
		[ self cancelPendingCalls ] on: Error , Halt do: [ :exception |
			error := SmallGPTalkFailure fromException: exception. finalState := #failed ].
		stateLock critical: [
			(cancellationRequested and: [ finalState = #completed ]) ifTrue: [
				finalState := #cancelled.
				error := SmallGPTalkFailure fromException: (SmallGPTalkCancelled new messageText: 'The run was cancelled.') ].
			state := finalState.
			state = #completed ifFalse: [ result := nil ] ].
		self releaseImage.
		session releaseRun: self.
		self emit: (Dictionary new
			at: #type put: #finished;
			at: #state put: state;
			at: #result put: result;
			at: #error put: error;
			yourself)
	] ensure: [ completion signal ]
]

{ #category : #'private' }
SmallGPTalkRun >> agentLoop [
	| response |
	1 to: session maxTurns do: [ :turn |
		self checkCancellation.
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
	| marker keep |
	aResult text size <= self toolOutputLimit ifTrue: [ ^ aResult ].
	marker := String lf , '[Output truncated]'.
	keep := (self toolOutputLimit - marker size) max: 0.
	aResult text: (aResult text first: keep) , (marker first: (marker size min: self toolOutputLimit)); truncated: true.
	^ aResult
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

{ #category : #'accessing' }
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
