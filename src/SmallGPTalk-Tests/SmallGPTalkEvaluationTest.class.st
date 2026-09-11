Class {
 #name : 'SmallGPTalkEvaluationTest',
 #superclass : 'TestCase',
 #instVars : [ 'activeEvaluation' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkEvaluationTest >> testEvaluationKeepsTheSourceAndRealObject [
 | evaluation |
 evaluation := (Smalltalk globals at: #SmallGPTalkEvaluation) source: 'SmallGPTalkEvaluationTest'.
 self assert: evaluation state equals: #pending.
 self assert: evaluation execute identicalTo: evaluation.
 self assert: evaluation state equals: #completed.
 self assert: evaluation source equals: 'SmallGPTalkEvaluationTest'.
 self assert: evaluation result identicalTo: self class
]

{ #category : 'tests' }
SmallGPTalkEvaluationTest >> testNilIsASuccessfulResult [
 | evaluation |
 evaluation := (Smalltalk globals at: #SmallGPTalkEvaluation) source: 'nil'.
 evaluation execute.
 self assert: evaluation state equals: #completed.
 self assert: evaluation result isNil.
 self assert: evaluation error isNil
]

{ #category : 'tests' }
SmallGPTalkEvaluationTest >> testSyntaxAndRuntimeFailuresRemainInspectable [
 #('1 + ]' 'Error signal: ''Fixture failure.''') do: [ :source |
  | evaluation |
  evaluation := (Smalltalk globals at: #SmallGPTalkEvaluation) source: source.
  evaluation execute.
  self assert: evaluation state equals: #failed.
  self assert: evaluation source equals: source.
  self assert: evaluation error isNotEmpty.
  self assert: evaluation result isNil ]
]

{ #category : 'tests' }
SmallGPTalkEvaluationTest >> testAnEvaluationCannotExecuteTwice [
 | evaluation |
 evaluation := (Smalltalk globals at: #SmallGPTalkEvaluation) source: 'Object new'.
 evaluation execute.
 self should: [ evaluation execute ] raise: Error.
 self assert: evaluation state equals: #completed
]

{ #category : 'model protocol' }
SmallGPTalkEvaluationTest >> respondTo: request [
 ^ activeEvaluation execute
]

{ #category : 'tests' }
SmallGPTalkEvaluationTest >> testRunCancellationStopsAnEvaluation [
 | run done waiter deadline |
 activeEvaluation := SmallGPTalkEvaluation source: '[ true ] whileTrue'.
 run := (SmallGPTalkSession withModel: self) send: 'Evaluate'.
 done := Semaphore new.
 waiter := [ run wait. done signal ] fork.
 [
  deadline := Time millisecondClockValue + 2000.
  [ activeEvaluation state = #pending and: [ Time millisecondClockValue < deadline ] ]
   whileTrue: [ (Delay forMilliseconds: 1) wait ].
  self assert: activeEvaluation state equals: #running.
  run cancel.
  self deny: (done waitTimeoutMilliseconds: 2000).
  self assert: activeEvaluation state equals: #cancelled.
  self assert: activeEvaluation source equals: '[ true ] whileTrue'.
  self assert: run state equals: #cancelled
 ] ensure: [ run cancel. run wait. waiter terminate ]
]

{ #category : 'tests - output' }
SmallGPTalkEvaluationTest >> testOutputIsBoundedWithoutChangingTheRealValue [
 | evaluation |
 evaluation := SmallGPTalkEvaluation source: 'String new: 1000 withAll: $x'.
 evaluation outputLimit: 64.
 evaluation execute.
 self assert: evaluation result size equals: 1000.
 self assert: evaluation output size <= 64.
 self assert: evaluation truncated.
 self assert: evaluation output last equals: $…
]

{ #category : 'tests - output' }
SmallGPTalkEvaluationTest >> testOutputIsARecordOfTheEvaluationTime [
 | evaluation output |
 evaluation := SmallGPTalkEvaluation source: 'OrderedCollection with: 42'.
 evaluation execute.
 output := evaluation output.
 evaluation result add: 7.
 self assert: evaluation result asArray equals: #(42 7).
 self assert: evaluation output equals: output.
 self deny: evaluation truncated
]
