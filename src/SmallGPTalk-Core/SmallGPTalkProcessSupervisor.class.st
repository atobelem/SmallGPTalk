"Run work in a child process. Stop that process before returning control."
Class {
 #name : 'SmallGPTalkProcessSupervisor',
 #superclass : 'Object',
 #category : 'SmallGPTalk-Core'
}

{ #category : 'execution' }
SmallGPTalkProcessSupervisor >> value: work startWhen: permission whileWaiting: continue [
 | worker finished result failure started |
 started := false.
 finished := Semaphore new.
 worker := [
  [ [ result := work value ] on: Error , Halt do: [ :error | failure := error messageText copy ] ]
   ensure: [ finished signal ]
 ] newProcess.
 worker priority: (Processor activePriority - 1 max: 1).
 [
  permission value: [ worker resume. started := true ].
  started ifFalse: [ ^ nil ].
  [ (finished waitTimeoutMilliseconds: 10) and: [ continue value ] ] whileTrue.
  failure ifNotNil: [ self error: failure ].
  ^ result
 ] ensure: [ self stop: worker ]
]

{ #category : 'private' }
SmallGPTalkProcessSupervisor >> stop: worker [
 worker isTerminated ifFalse: [ worker terminate ].
 [ worker isTerminated ] whileFalse: [ (Delay forMilliseconds: 10) wait ]
]
