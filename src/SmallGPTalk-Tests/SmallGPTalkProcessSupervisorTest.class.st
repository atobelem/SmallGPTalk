Class {
 #name : 'SmallGPTalkProcessSupervisorTest',
 #superclass : 'TestCase',
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkProcessSupervisorTest >> testReturnsTheSameValueAfterWorkerCleanup [
 | value result worker cleaned |
 value := Object new.
 cleaned := false.
 result := SmallGPTalkProcessSupervisor new
  value: [ [ worker := Processor activeProcess. value ] ensure: [ cleaned := true ] ]
  startWhen: [ :start | start value ] whileWaiting: [ true ].
 self assert: result identicalTo: value.
 self assert: cleaned.
 self assert: worker isTerminated
]

{ #category : 'tests' }
SmallGPTalkProcessSupervisorTest >> testDeniedStartDoesNotExecuteWorkOrWait [
 | executed result |
 executed := false.
 result := SmallGPTalkProcessSupervisor new
  value: [ executed := true ] startWhen: [ :start | ]
  whileWaiting: [ self error: 'The denied work must not wait.' ].
 self deny: executed.
 self assert: result isNil
]

{ #category : 'tests' }
SmallGPTalkProcessSupervisorTest >> testReportsErrorsAndHaltsAfterCleanup [
 { Error new messageText: 'Work failed.'. Halt new messageText: 'Work halted.' } do: [ :failure |
  | message cleaned worker |
  cleaned := false.
  [ SmallGPTalkProcessSupervisor new
   value: [ [ worker := Processor activeProcess. failure signal ] ensure: [ cleaned := true ] ]
   startWhen: [ :start | start value ] whileWaiting: [ true ] ]
    on: Error do: [ :error | message := error messageText ].
  self assert: message equals: failure messageText.
  self assert: cleaned.
  self assert: worker isTerminated ]
]

{ #category : 'tests' }
SmallGPTalkProcessSupervisorTest >> testStopPolicyWaitsForWorkerCleanup [
 | worker cleaned result |
 cleaned := false.
 result := SmallGPTalkProcessSupervisor new
  value: [ [ worker := Processor activeProcess. Semaphore new wait ] ensure: [ cleaned := true ] ]
  startWhen: [ :start | start value ] whileWaiting: [ false ].
 self assert: result isNil.
 self assert: cleaned.
 self assert: worker isTerminated
]

{ #category : 'tests' }
SmallGPTalkProcessSupervisorTest >> testPolicyFailureStopsTheWorkerBeforeItEscapes [
 | worker cleaned message |
 cleaned := false.
 [ SmallGPTalkProcessSupervisor new
  value: [ [ worker := Processor activeProcess. Semaphore new wait ] ensure: [ cleaned := true ] ]
  startWhen: [ :start | start value ] whileWaiting: [ self error: 'The deadline passed.' ] ]
   on: Error do: [ :error | message := error messageText ].
 self assert: message equals: 'The deadline passed.'.
 self assert: cleaned.
 self assert: worker isTerminated
]
