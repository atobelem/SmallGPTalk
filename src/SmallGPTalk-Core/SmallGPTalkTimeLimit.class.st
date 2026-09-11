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
 | worker finished deadline result failure started |
 started := false.
 finished := Semaphore new.
 deadline := Time microsecondClockValue + (seconds * 1000000).
 worker := [
  [ [ result := work value ] on: Error , Halt do: [ :error | failure := error messageText copy ] ]
   ensure: [ finished signal ]
 ] newProcess.
 worker priority: (Processor activePriority - 1 max: 1).
 [
  permission value: [ worker resume. started := true ].
  started ifFalse: [ ^ nil ].
  [ finished waitTimeoutMilliseconds: 10 ] whileTrue: [
   Time microsecondClockValue >= deadline ifTrue: [ self error: 'The operation exceeded its time limit.' ] ].
  failure ifNotNil: [ self error: failure ].
  ^ result
 ] ensure: [
  worker isTerminated ifFalse: [ worker terminate ].
  [ worker isTerminated ] whileFalse: [ (Delay forMilliseconds: 10) wait ] ]
]

{ #category : 'accessing' }
SmallGPTalkTimeLimit >> seconds [ ^ seconds ]
