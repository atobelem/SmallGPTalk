"Check continuous improvement without account access or background work left running."
Class {
	#name : 'SmallGPTalkSelfImprovementTest',
	#superclass : 'TestCase',
	#instVars : [ 'improvement' ],
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkSelfImprovementTest >> tearDown [
	improvement ifNotNil: [ improvement isActive ifTrue: [ improvement cancel. self waitForStop ] ].
	super tearDown
]

{ #category : 'private' }
SmallGPTalkSelfImprovementTest >> waitForStop [
	| done waiter |
	done := Semaphore new.
	waiter := [ improvement wait. done signal ] fork.
	[ self deny: (done waitTimeoutMilliseconds: 3000) ] ensure: [ waiter terminate ]
]

{ #category : 'tests' }
SmallGPTalkSelfImprovementTest >> testContinuesWithFreshSessionsUntilCancelled [
	| provider sessions events |
	sessions := OrderedCollection new. events := OrderedCollection new.
	provider := SmallGPTalkCoreTestProvider new responseBlock: [ :session :text :run |
		sessions add: session.
		SmallGPTalkMessage assistant: 'Change verified.' ]; yourself.
	improvement := self improvementWithProvider: provider.
	improvement pauseMilliseconds: 1.
	improvement startOnEvent: [ :event |
		events add: event.
		((event at: #type) = #finished and: [ improvement cycleCount = 3 ]) ifTrue: [ improvement cancel ] ].
	self waitForStop.
	self assert: provider requestCount equals: 3.
	self deny: sessions first identicalTo: sessions last.
	self assert: (sessions last messages first text includesSubstring: 'Change verified.').
	self assert: sessions last messages size equals: 2.
	self assert: (events last at: #type) equals: #improvementStopped
]

{ #category : 'tests' }
SmallGPTalkSelfImprovementTest >> testFailureDoesNotStopFollowingCycles [
	| provider |
	provider := SmallGPTalkCoreTestProvider new.
	provider responseBlock: [ :session :text :run |
		provider requestCount = 1 ifTrue: [ self error: 'Fixture failure.' ].
		SmallGPTalkMessage assistant: 'Recovered.' ].
	improvement := self improvementWithProvider: provider.
	improvement errorPauseMilliseconds: 1.
	improvement startOnEvent: [ :event |
		((event at: #type) = #finished and: [ improvement cycleCount = 2 ]) ifTrue: [ improvement cancel ] ].
	self waitForStop.
	self assert: provider requestCount equals: 2.
	self assert: improvement session messages last text equals: 'Recovered.'
]

{ #category : 'tests' }
SmallGPTalkSelfImprovementTest >> testCancelAtCycleStartPreventsRequest [
	| provider |
	provider := SmallGPTalkCoreTestProvider new.
	improvement := self improvementWithProvider: provider.
	improvement startOnEvent: [ :event | (event at: #type) = #cycleStarted ifTrue: [ improvement cancel ] ].
	self waitForStop.
	self assert: provider requestCount equals: 0
]

{ #category : 'tests' }
SmallGPTalkSelfImprovementTest >> testCancelStopsActiveRun [
	| started provider |
	started := Semaphore new.
	provider := SmallGPTalkCoreTestProvider new responseBlock: [ :session :text :run |
		started signal. Semaphore new wait ]; yourself.
	improvement := self improvementWithProvider: provider.
	improvement startOnEvent: [ :event | ].
	self deny: (started waitTimeoutMilliseconds: 2000).
	improvement cancel.
	self waitForStop.
	self assert: improvement activeRun state equals: #cancelled.
	self assert: provider requestCount equals: 1
]

{ #category : 'tests' }
SmallGPTalkSelfImprovementTest >> testImprovementAgentDoesNotChangeOriginal [
	| original derived |
	original := SmallGPTalkAgent new tools: SmallGPTalkImageTools all; yourself.
	derived := original forSelfImprovement.
	self assert: original name equals: 'SmallGPTalk'.
	self deny: (original instructions includesSubstring: 'Self-improvement mode is active').
	self assert: (derived instructions includesSubstring: 'without further approval').
	self assert: (derived newSession tools collect: #name) equals: #('evaluate')
]

{ #category : 'tests' }
SmallGPTalkSelfImprovementTest >> testCancelInterruptsErrorPause [
	| failed |
	failed := Semaphore new.
	improvement := SmallGPTalkSelfImprovement new errorPauseMilliseconds: 60000;
		sessionFactory: [ self error: 'Cannot create the session.' ]; yourself.
	improvement startOnEvent: [ :event | (event at: #type) = #cycleFailed ifTrue: [ failed signal ] ].
	self deny: (failed waitTimeoutMilliseconds: 2000).
	improvement cancel.
	self waitForStop.
	self assert: improvement cycleCount equals: 0
]

{ #category : 'tests' }
SmallGPTalkSelfImprovementTest >> testObserverErrorsDoNotStopCycles [
	| provider |
	provider := SmallGPTalkCoreTestProvider new responseBlock: [ :session :text :run |
		SmallGPTalkMessage assistant: 'Done.' ]; yourself.
	improvement := self improvementWithProvider: provider.
	improvement pauseMilliseconds: 1.
	improvement startOnEvent: [ :event |
		(event at: #type) = #finished ifTrue: [
			improvement cycleCount = 2 ifTrue: [ improvement cancel ].
			self error: 'Observer failed.' ] ].
	self waitForStop.
	self assert: provider requestCount equals: 2.
	self assert: improvement observerErrors size equals: 2
]

{ #category : 'private' }
SmallGPTalkSelfImprovementTest >> improvementWithProvider: aProvider [
	^ SmallGPTalkSelfImprovement new
		sessionFactory: [ SmallGPTalkSession new provider: aProvider; model: 'fixture'; yourself ];
		yourself
]
