"Execute an exchange in the background. The exchange retains its outcome."
Class {
 #name : 'SmallGPTalkRun',
 #superclass : 'Object',
 #instVars : [ 'completion', 'exchange', 'lock', 'onSuccess' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'instance creation' }
SmallGPTalkRun class >> on: anExchange [
 ^ self new useExchange: anExchange; yourself
]

{ #category : 'initialization' }
SmallGPTalkRun >> initialize [
 super initialize.
 completion := Semaphore new.
 onSuccess := [ :value | ].
 lock := Semaphore forMutualExclusion
]

{ #category : 'initialization' }
SmallGPTalkRun >> useExchange: anExchange [
 exchange := anExchange
]

{ #category : 'private' }
SmallGPTalkRun >> start: work whenFinished: cleanup [
 exchange begin.
 [
  [ self execute: work ] ensure: [ cleanup ensure: [ completion signal ] ]
 ] forkAt: Processor userBackgroundPriority
]

{ #category : 'private' }
SmallGPTalkRun >> execute: work [
 | worker finished value failure |
 finished := Semaphore new.
 worker := [
  [ [ value := work value ] on: Error , Halt do: [ :exception |
    failure := exception messageText copy ] ] ensure: [ finished signal ]
 ] newProcess.
 worker priority: (Processor activePriority - 1 max: 1).
 [
  lock critical: [ self state = #running ifTrue: [ worker resume ] ].
  [ (finished waitTimeoutMilliseconds: 10) and: [ self state = #running ] ] whileTrue
 ] ensure: [
  worker isTerminated ifFalse: [ worker terminate ].
  [ worker isTerminated ] whileFalse: [ (Delay forMilliseconds: 10) wait ] ].
 lock critical: [
  self state = #cancelling
   ifTrue: [ exchange finishCancellation ]
   ifFalse: [ failure
    ifNil: [
     [ onSuccess value: value. exchange completeWith: value ]
      on: Error , Halt do: [ :error | exchange failWith: error messageText ] ]
    ifNotNil: [ exchange failWith: failure ] ] ]
]

{ #category : 'execution' }
SmallGPTalkRun >> cancel [
 lock critical: [ exchange requestCancellation ].
 ^ self
]

{ #category : 'waiting' }
SmallGPTalkRun >> wait [
 completion critical: [ ].
 ^ self
]

{ #category : 'accessing' }
SmallGPTalkRun >> result [ ^ exchange response ]

{ #category : 'accessing' }
SmallGPTalkRun >> state [ ^ exchange state ]

{ #category : 'accessing' }
SmallGPTalkRun >> error [ ^ exchange error ]

{ #category : 'accessing' }
SmallGPTalkRun >> exchange [ ^ exchange ]

{ #category : 'initialization' }
SmallGPTalkRun >> whenSucceeded: aBlock [ onSuccess := aBlock ]

{ #category : 'execution' }
SmallGPTalkRun >> whileRunningDo: aBlock [
 ^ lock critical: [ self state = #running ifTrue: [ aBlock value ] ]
]
