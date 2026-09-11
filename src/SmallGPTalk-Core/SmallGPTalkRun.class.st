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
 | value failure |
 [ value := SmallGPTalkProcessSupervisor new
  value: work startWhen: [ :start | self whileRunningDo: start ]
  whileWaiting: [ self state = #running ] ]
   on: Error , Halt do: [ :error | failure := error messageText copy ].
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
