"Run work within a time limit and stop its process before returning."
Class {
 #name : 'SmallGPTalkTimeLimit',
 #superclass : 'Object',
 #instVars : [ 'seconds' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'instance creation' }
SmallGPTalkTimeLimit class >> seconds: duration [
 ^ self new configure: duration; yourself
]

{ #category : 'initialization' }
SmallGPTalkTimeLimit >> configure: duration [
 (duration isNumber and: [ duration > 0 ]) ifFalse: [ self error: 'The time limit must be positive.' ].
 seconds := duration
]

{ #category : 'execution' }
SmallGPTalkTimeLimit >> value: work [
 ^ self value: work startWhen: [ :start | start value ]
]

{ #category : 'execution' }
SmallGPTalkTimeLimit >> value: work startWhen: permission [
 | deadline |
 deadline := Time microsecondClockValue + (seconds * 1000000).
 ^ SmallGPTalkProcessSupervisor new value: work startWhen: permission whileWaiting: [
  Time microsecondClockValue >= deadline ifTrue: [ self error: 'The operation exceeded its time limit.' ].
  true ]
]

{ #category : 'accessing' }
SmallGPTalkTimeLimit >> seconds [ ^ seconds ]
