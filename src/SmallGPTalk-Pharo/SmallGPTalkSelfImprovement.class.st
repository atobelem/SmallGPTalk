"Run improvement cycles until cancelled. Each cycle uses a fresh session and a bounded summary."
Class {
	#name : 'SmallGPTalkSelfImprovement',
	#superclass : 'Object',
	#instVars : [ 'sessionFactory', 'session', 'activeRun', 'state', 'cycleCount', 'summary', 'error', 'observer', 'observerErrors', 'process', 'completion', 'wakeUp', 'lock', 'pauseMilliseconds', 'errorPauseMilliseconds' ],
	#category : 'SmallGPTalk-Pharo',
	#package : 'SmallGPTalk-Pharo'
}

{ #category : 'initialization' }
SmallGPTalkSelfImprovement >> initialize [
	super initialize.
	state := #idle. cycleCount := 0. summary := ''.
	observerErrors := OrderedCollection new.
	completion := Semaphore new. wakeUp := Semaphore new.
	lock := Semaphore forMutualExclusion.
	pauseMilliseconds := 1000. errorPauseMilliseconds := 30000
]

{ #category : 'accessing' }
SmallGPTalkSelfImprovement >> sessionFactory: aBlock [
	state = #idle ifFalse: [ self error: 'Configure improvement before starting it.' ].
	sessionFactory := aBlock
]

{ #category : 'accessing' }
SmallGPTalkSelfImprovement >> pauseMilliseconds: milliseconds [
	milliseconds > 0 ifFalse: [ self error: 'The pause must be positive.' ].
	pauseMilliseconds := milliseconds
]

{ #category : 'accessing' }
SmallGPTalkSelfImprovement >> errorPauseMilliseconds: milliseconds [
	milliseconds > 0 ifFalse: [ self error: 'The error pause must be positive.' ].
	errorPauseMilliseconds := milliseconds
]

{ #category : 'running' }
SmallGPTalkSelfImprovement >> startOnEvent: aBlock [
	lock critical: [
		state = #idle ifFalse: [ self error: 'This improvement process has already started.' ].
		sessionFactory ifNil: [ self error: 'Set an improvement session factory.' ].
		observer := aBlock.
		state := #running.
		process := [ self execute ] newProcess.
		process priority: Processor userBackgroundPriority.
		process resume ].
	^ self
]

{ #category : 'running' }
SmallGPTalkSelfImprovement >> cancel [
	lock critical: [
		self isActive ifTrue: [
			state := #stopping.
			activeRun ifNotNil: [ activeRun cancel ].
			wakeUp signal ] ].
	^ self
]

{ #category : 'running' }
SmallGPTalkSelfImprovement >> wait [
	(state = #stopped and: [ Processor activeProcess == process ]) ifTrue: [ ^ self ].
	completion wait. completion signal.
	^ self
]

{ #category : 'private' }
SmallGPTalkSelfImprovement >> execute [
	[ [ state = #running ] whileTrue: [ self runNextCycle ] ]
		ensure: [ self finish ]
]

{ #category : 'private' }
SmallGPTalkSelfImprovement >> runCycle [
	| input |
	error := nil.
	activeRun := nil.
	session := sessionFactory value.
	cycleCount := cycleCount + 1.
	input := 'Inspect SmallGPTalk and complete one useful improvement. Run relevant tests and report the result.'.
	summary ifNotEmpty: [ input := input, String cr, 'Previous cycle: ', summary ].
	self emit: (Dictionary new at: #type put: #cycleStarted;
		at: #cycle put: cycleCount; at: #session put: session; at: #input put: input; yourself).
	lock critical: [
		state = #running ifTrue: [
			activeRun := session send: input onEvent: [ :event | self emit: event ] ] ].
	activeRun ifNil: [ ^ self ].
	activeRun wait.
	error := activeRun error.
	summary := activeRun result
		ifNil: [ 'The last cycle did not complete. Inspect the current image before changing code. ',
			(error ifNil: [ '' ] ifNotNil: [ error messageText ]) ]
		ifNotNil: [ :message | message text ].
	summary := summary truncateTo: 2000
]

{ #category : 'private' }
SmallGPTalkSelfImprovement >> emit: event [
	[ observer value: event ] on: Error , Halt do: [ :exception |
		observerErrors add: (SmallGPTalkFailure fromException: exception) ]
]

{ #category : 'testing' }
SmallGPTalkSelfImprovement >> isActive [ ^ #(running stopping) includes: state ]

{ #category : 'accessing' }
SmallGPTalkSelfImprovement >> state [ ^ state ]

{ #category : 'accessing' }
SmallGPTalkSelfImprovement >> activeRun [ ^ activeRun ]

{ #category : 'accessing' }
SmallGPTalkSelfImprovement >> session [ ^ session ]

{ #category : 'accessing' }
SmallGPTalkSelfImprovement >> cycleCount [ ^ cycleCount ]

{ #category : 'error handling' }
SmallGPTalkSelfImprovement >> error [ ^ error ]

{ #category : 'accessing' }
SmallGPTalkSelfImprovement >> observerErrors [ ^ observerErrors copy ]

{ #category : 'private' }
SmallGPTalkSelfImprovement >> runNextCycle [
	[ self runCycle ] on: Error , Halt do: [ :exception |
		error := SmallGPTalkFailure fromException: exception.
		self emit: (Dictionary new at: #type put: #cycleFailed; at: #error put: error; yourself) ].
	state = #running ifTrue: [
		wakeUp waitTimeoutMilliseconds: (error
			ifNil: [ pauseMilliseconds ] ifNotNil: [ errorPauseMilliseconds ]) ]
]

{ #category : 'private' }
SmallGPTalkSelfImprovement >> finish [
	activeRun ifNotNil: [ activeRun isFinished ifFalse: [ activeRun cancel. activeRun wait ] ].
	state := #stopped.
	[ self emit: (Dictionary new at: #type put: #improvementStopped; yourself) ]
		ensure: [ completion signal ]
]
