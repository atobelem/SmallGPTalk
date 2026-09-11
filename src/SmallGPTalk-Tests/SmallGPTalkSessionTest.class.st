Class {
 #name : 'SmallGPTalkSessionTest',
 #superclass : 'TestCase',
 #instVars : [ 'answer', 'received', 'entered', 'release', 'stopped', 'operation' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'model protocol' }
SmallGPTalkSessionTest >> respondTo: request [
 operation ifNotNil: [ ^ operation value: request ].
 received := request.
 entered ifNotNil: [
  [ entered signal. release wait ] ensure: [ stopped ifNotNil: [ stopped signal ] ] ].
 (answer isKindOf: Exception) ifTrue: [ answer signal ].
 ^ answer
]

{ #category : 'tests' }
SmallGPTalkSessionTest >> testRequestReturnsAnInspectableResponse [
 | session run |
 answer := Object new.
 session := SmallGPTalkSession withModel: self.
 run := session send: 'Hello'.
 self assert: run wait identicalTo: run.
 self assert: received text equals: 'Hello'.
 self assert: run result identicalTo: answer.
 self assert: run state equals: #completed
]

{ #category : 'tests - waiting' }
SmallGPTalkSessionTest >> testTerminatingAnAwakenedWaiterDoesNotLoseCompletion [
 | session run first second done observed completion priority deadline |
 entered := Semaphore new.
 release := Semaphore new.
 done := Semaphore new.
 observed := Semaphore new.
 answer := 'Done.'.
 priority := Processor activePriority.
 session := SmallGPTalkSession withModel: self.
 session whenFinished: [ :finished |
  Processor activeProcess priority: priority + 1.
  done signal ].
 run := session send: 'Finish once'.
 "Inspect the wait queue to reproduce the interrupted-wait race."
 completion := run instVarNamed: 'completion'.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  first := [ run wait ] forkAt: (priority - 10 max: 1).
  deadline := Time microsecondClockValue + 1000000.
  [ (completion includes: first) not and: [ Time microsecondClockValue < deadline ] ]
   whileTrue: [ (Delay forMilliseconds: 1) wait ].
  self assert: (completion includes: first).
  release signal.
  self deny: (done waitTimeoutMilliseconds: 1000).
  first terminate.
  second := [ run wait. observed signal ] fork.
  self deny: (observed waitTimeoutMilliseconds: 1000).
  self assert: run state equals: #completed.
  self assert: run result equals: 'Done.'
 ] ensure: [
  release signal. completion signal.
  first ifNotNil: [ first terminate ].
  second ifNotNil: [ second terminate ].
  run cancel; wait ]
]

{ #category : 'tests - waiting' }
SmallGPTalkSessionTest >> testInterruptingAWaitDoesNotCompleteRunningWork [
 | session run first second interrupter observed terminated completion deadline |
 entered := Semaphore new.
 release := Semaphore new.
 observed := Semaphore new.
 terminated := Semaphore new.
 answer := 'Done.'.
 session := SmallGPTalkSession withModel: self.
 run := session send: 'Keep running'.
 "Inspect the wait queue to reproduce the interrupted-wait race."
 completion := run instVarNamed: 'completion'.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  first := [ run wait ] fork.
  deadline := Time microsecondClockValue + 1000000.
  [ (completion includes: first) not and: [ Time microsecondClockValue < deadline ] ]
   whileTrue: [ (Delay forMilliseconds: 1) wait ].
  self assert: (completion includes: first).
  interrupter := [ first terminate. terminated signal ] fork.
  second := [ run wait. observed signal ] fork.
  self assert: (observed waitTimeoutMilliseconds: 50).
  self assert: run state equals: #running.
  release signal.
  self deny: (observed waitTimeoutMilliseconds: 1000).
  self deny: (terminated waitTimeoutMilliseconds: 1000).
  self assert: run state equals: #completed
 ] ensure: [
  release signal. completion signal.
  first ifNotNil: [ first terminate ].
  second ifNotNil: [ second terminate ].
  interrupter ifNotNil: [ interrupter terminate ].
  run cancel; wait ]
]

{ #category : 'tests' }
SmallGPTalkSessionTest >> testModelCannotChangeWhileTheRunIsActive [
 | session run |
 entered := Semaphore new.
 release := Semaphore new.
 answer := 'Done.'.
 session := SmallGPTalkSession withModel: self.
 run := session send: 'Wait'.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  self should: [ session useModel: Object new ] raise: Error.
  release signal. run wait.
  self assert: run result equals: 'Done.'
 ] ensure: [ release signal. run cancel; wait ]
]

{ #category : 'tests' }
SmallGPTalkSessionTest >> testSendingDoesNotWaitForTheModel [
 | session returned run sender |
 entered := Semaphore new.
 release := Semaphore new.
 returned := Semaphore new.
 answer := 'Complete.'.
 session := SmallGPTalkSession withModel: self.
 sender := [ run := session send: 'Wait'. returned signal ] fork.
 [
  self deny: (entered waitTimeoutMilliseconds: 2000).
  self deny: (returned waitTimeoutMilliseconds: 2000).
  self assert: run state equals: #running.
  release signal.
  run wait.
  self assert: run result equals: answer
 ] ensure: [
  release signal.
  sender isTerminated ifFalse: [ sender terminate ].
  run ifNotNil: [ run wait ] ]
]

{ #category : 'tests' }
SmallGPTalkSessionTest >> testModelFailureFinishesTheRunWithoutADebugger [
 | run |
 answer := Error new messageText: 'The test model failed.'.
 run := (SmallGPTalkSession withModel: self) send: 'Fail'.
 run wait.
 self assert: run state equals: #failed.
 self assert: run error equals: 'The test model failed.'.
 self assert: run result isNil
]

{ #category : 'tests' }
SmallGPTalkSessionTest >> testConversationRetainsRequestsAndTheirResponses [
 | session first second history |
 session := SmallGPTalkSession withModel: self.
 answer := Object new.
 first := session send: 'First'.
 first wait.
 answer := 'Second answer.'.
 second := session send: 'Second'.
 second wait.
 history := session conversation.
 self assert: history size equals: 2.
 self assert: history first identicalTo: first exchange.
 self assert: history first request equals: 'First'.
 self assert: history first response identicalTo: first result.
 self assert: history last request equals: 'Second'.
 self assert: history last response equals: 'Second answer.'.
 history removeAll.
 self assert: session conversation size equals: 2
]

{ #category : 'tests' }
SmallGPTalkSessionTest >> testConversationRetainsAFailedExchange [
 | session run exchange |
 answer := Error new messageText: 'Fixture failure.'.
 session := SmallGPTalkSession withModel: self.
 run := session send: 'A failed request'.
 run wait.
 exchange := session conversation first.
 self assert: exchange request equals: 'A failed request'.
 self assert: exchange state equals: #failed.
 self assert: exchange error equals: 'Fixture failure.'.
 self assert: exchange response isNil
]

{ #category : 'tests' }
SmallGPTalkSessionTest >> testNamedAgentCreatesIndependentSessions [
 | agent first second run |
 agent := SmallGPTalkAgent named: 'Ada'.
 first := agent newSessionWith: self.
 second := agent newSessionWith: self.
 answer := 'Hello.'.
 run := first send: 'Hello'.
 run wait.
 self assert: first agent identicalTo: agent.
 self assert: second agent name equals: 'Ada'.
 self assert: first conversation size equals: 1.
 self assert: second conversation isEmpty
]

{ #category : 'tests' }
SmallGPTalkSessionTest >> testSessionRejectsOverlappingRequestsWithoutAddingHistory [
 | session run failure |
 entered := Semaphore new.
 release := Semaphore new.
 session := SmallGPTalkSession withModel: self.
 run := session send: 'First'.
 [
  self deny: (entered waitTimeoutMilliseconds: 2000).
  [ session send: 'Second' ] on: Error do: [ :error | failure := error messageText ].
  self assert: failure equals: 'Wait for the active request to finish.'.
  self assert: session conversation size equals: 1
 ] ensure: [ release signal. release signal. run wait ]
]

{ #category : 'tests - model context' }
SmallGPTalkSessionTest >> testNextRequestContainsEarlierExchanges [
 | session first second firstContext |
 session := SmallGPTalkSession withModel: self.
 answer := 'First reply.'.
 first := session send: 'First'.
 first wait.
 firstContext := received.
 answer := 'Second reply.'.
 second := session send: 'Second'.
 second wait.
 self assert: received text equals: 'Second'.
 self assert: received history size equals: 1.
 self assert: received history first request equals: 'First'.
 self assert: received history first response equals: 'First reply.'.
 self assert: firstContext history isEmpty.
 self assert: second exchange context identicalTo: received.
 received history removeAll.
 self assert: received history size equals: 1.
 self assert: session conversation size equals: 2
]

{ #category : 'tests - model context' }
SmallGPTalkSessionTest >> testAgentChangesApplyOnlyToFutureRequests [
 | agent session firstContext run |
 agent := SmallGPTalkAgent named: 'Ada'.
 agent instructions: 'Inspect before changing code.'.
 session := agent newSessionWith: self.
 run := session send: 'First'.
 run wait.
 firstContext := received.
 agent name: 'Grace'; instructions: 'Explain the result.'.
 run := session send: 'Second'.
 run wait.
 self assert: firstContext agentName equals: 'Ada'.
 self assert: firstContext instructions equals: 'Inspect before changing code.'.
 self assert: received agentName equals: 'Grace'.
 self assert: received instructions equals: 'Explain the result.'
]

{ #category : 'tests - cancellation' }
SmallGPTalkSessionTest >> testCancellationStopsWorkAndAllowsTheNextRequest [
 | session run waiter finished next |
 entered := Semaphore new.
 release := Semaphore new.
 stopped := Semaphore new.
 finished := Semaphore new.
 session := SmallGPTalkSession withModel: self.
 run := session send: 'Stop this request'.
 waiter := [ run wait. finished signal ] fork.
 [
  self deny: (entered waitTimeoutMilliseconds: 2000).
  run cancel.
  self deny: (finished waitTimeoutMilliseconds: 2000).
  self deny: (stopped waitTimeoutMilliseconds: 2000).
  self assert: run state equals: #cancelled.
  self assert: run result isNil.
  self assert: received text equals: 'Stop this request'.
  self assert: session conversation first state equals: #cancelled.
  entered := nil.
  answer := 'Next answer.'.
  next := session send: 'Continue'.
  next wait.
  self assert: next result equals: 'Next answer.'.
  self assert: session conversation size equals: 2
 ] ensure: [ release signal. run wait. waiter terminate ]
]

{ #category : 'tests - cancellation' }
SmallGPTalkSessionTest >> testCancellingAFinishedRunKeepsItsResult [
 | run |
 answer := Object new.
 run := (SmallGPTalkSession withModel: self) send: 'Finish'.
 run wait.
 run cancel; cancel.
 self assert: run state equals: #completed.
 self assert: run result identicalTo: answer
]

{ #category : 'tests - cancellation' }
SmallGPTalkSessionTest >> testCancellationStopsBusySmalltalkAndPreservesItsEffect [
 | started stoppedWork effect run done waiter |
 started := Semaphore new.
 stoppedWork := Semaphore new.
 done := Semaphore new.
 effect := OrderedCollection new.
 operation := [ :request |
  [ effect add: request text. started signal. [ true ] whileTrue ]
   ensure: [ stoppedWork signal ] ].
 run := (SmallGPTalkSession withModel: self) send: 'Recorded before cancellation'.
 waiter := [ run wait. done signal ] fork.
 [
  self deny: (started waitTimeoutMilliseconds: 2000).
  run cancel.
  self deny: (done waitTimeoutMilliseconds: 2000).
  self deny: (stoppedWork waitTimeoutMilliseconds: 2000).
  self assert: run state equals: #cancelled.
  self assert: effect asArray equals: #('Recorded before cancellation')
 ] ensure: [ run cancel. run wait. waiter terminate ]
]

{ #category : 'tests - fork' }
SmallGPTalkSessionTest >> testForkCopiesThroughAnExchangeAndContinuesIndependently [
 | session first second fork third branch |
 session := (SmallGPTalkAgent named: 'Ada') newSessionWith: self.
 session maxTurns: 5.
 answer := 'Reply.'.
 first := session send: 'First'. first wait.
 second := session send: 'Second'. second wait.
 fork := session forkAt: first exchange.
 self assert: fork conversation size equals: 1.
 self deny: fork conversation first identicalTo: first exchange.
 self assert: fork agent identicalTo: session agent.
 self assert: fork maxTurns equals: 5.
 branch := fork send: 'Branch'. branch wait.
 third := session send: 'Original'. third wait.
 self assert: fork conversation size equals: 2.
 self assert: session conversation size equals: 3.
 self assert: branch exchange context history first identicalTo: fork conversation first.
 self assert: third exchange context history size equals: 2
]

{ #category : 'tests - fork' }
SmallGPTalkSessionTest >> testForkFromAFailedExchangeCanContinue [
 | session failed fork next |
 session := SmallGPTalkSession withModel: self.
 answer := Error new messageText: 'Fixture failure.'.
 failed := session send: 'Fail'. failed wait.
 fork := session forkAt: failed exchange.
 self assert: fork conversation first state equals: #failed.
 self assert: fork conversation first error equals: 'Fixture failure.'.
 answer := 'Recovered.'.
 next := fork send: 'Continue'. next wait.
 self assert: next result equals: 'Recovered.'.
 self assert: session conversation size equals: 1
]

{ #category : 'tests - fork' }
SmallGPTalkSessionTest >> testForkRejectsActiveAndForeignExchanges [
 | session run failure |
 entered := Semaphore new.
 release := Semaphore new.
 session := SmallGPTalkSession withModel: self.
 run := session send: 'Active'.
 [
  self deny: (entered waitTimeoutMilliseconds: 2000).
  [ session forkAt: run exchange ] on: Error do: [ :error | failure := error messageText ].
  self assert: failure equals: 'Choose a finished exchange.'.
  failure := nil.
  [ session forkAt: (SmallGPTalkExchange request: run exchange context) ]
   on: Error do: [ :error | failure := error messageText ].
  self assert: failure equals: 'Choose an exchange from this session.'
 ] ensure: [ release signal. run wait ]
]

{ #category : 'tests - timeout' }
SmallGPTalkSessionTest >> testModelTimeoutStopsTheWorker [
 | session run done |
 stopped := Semaphore new.
 operation := [ :request | [ Semaphore new wait ] ensure: [ stopped signal ] ].
 session := SmallGPTalkSession withModel: self.
 session requestTimeoutSeconds: 0.03.
 run := session send: 'Time out'.
 done := Semaphore new.
 [ run wait. done signal ] fork.
 [
  self deny: (done waitTimeoutMilliseconds: 2000).
  self deny: (stopped waitTimeoutMilliseconds: 2000).
  self assert: run state equals: #failed.
  self assert: run error equals: 'The operation exceeded its time limit.'
 ] ensure: [ run cancel. run wait ]
]
