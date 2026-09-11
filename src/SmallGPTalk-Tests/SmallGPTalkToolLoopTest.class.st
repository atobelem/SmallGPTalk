Class {
 #name : 'SmallGPTalkToolLoopTest',
 #superclass : 'TestCase',
 #instVars : [ 'modelAction' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'model protocol' }
SmallGPTalkToolLoopTest >> respondTo: request [ ^ modelAction value: request ]

{ #category : 'helpers' }
SmallGPTalkToolLoopTest >> call: id source: text [
 ^ (Smalltalk globals at: #SmallGPTalkCall) id: id name: 'evaluate'
  arguments: (Dictionary new at: 'source' put: text; yourself)
]

{ #category : 'helpers' }
SmallGPTalkToolLoopTest >> replyWith: calls [
 ^ (Smalltalk globals at: #SmallGPTalkReply) text: 'Evaluate.' calls: calls
]

{ #category : 'helpers' }
SmallGPTalkToolLoopTest >> session [
 ^ (SmallGPTalkSession withModel: self)
  tools: { (Smalltalk globals at: #SmallGPTalkEvaluate) new }; yourself
]

{ #category : 'tests' }
SmallGPTalkToolLoopTest >> testModelReceivesOrderedResultsAndHistoryKeepsEvaluations [
 | session run seen |
 seen := nil.
 modelAction := [ :request |
  request calls ifEmpty: [ self replyWith: {
   self call: 'one' source: 'OrderedCollection with: 42'.
   self call: 'two' source: '6 factorial' } ]
  ifNotEmpty: [ seen := request calls. 'Done.' ] ].
 session := self session.
 run := session send: 'Evaluate both'.
 run wait.
 self assert: run state equals: #completed.
 self assert: run result equals: 'Done.'.
 self assert: (seen collect: #id) asArray equals: #('one' 'two').
 self assert: seen first result asArray equals: #(42).
 self assert: seen last result equals: 720.
 self assert: session conversation first calls first operation source equals: 'OrderedCollection with: 42'.
 self assert: seen first result identicalTo: session conversation first calls first result
]

{ #category : 'tests' }
SmallGPTalkToolLoopTest >> testModelCanCorrectAFailedEvaluation [
 | run |
 modelAction := [ :request |
  request calls size = 0 ifTrue: [ self replyWith: { self call: 'bad' source: '1 + ]' } ]
  ifFalse: [ request calls size = 1
   ifTrue: [ self assert: request calls first state equals: #failed.
    self replyWith: { self call: 'fixed' source: '1 + 1' } ]
   ifFalse: [ 'Corrected.' ] ] ].
 run := self session send: 'Correct errors'.
 run wait.
 self assert: run state equals: #completed.
 self assert: run exchange calls first operation error isNotEmpty.
 self assert: run exchange calls last result equals: 2
]

{ #category : 'tests' }
SmallGPTalkToolLoopTest >> testCancellationKeepsCompletedCallsAndCancelsTheRest [
 | run done waiter deadline calls |
 modelAction := [ :request | self replyWith: {
  self call: 'completed' source: 'OrderedCollection with: 42'.
  self call: 'running' source: '[ true ] whileTrue'.
  self call: 'pending' source: '2 + 2' } ].
 run := self session send: 'Cancel midway'.
 done := Semaphore new.
 waiter := [ run wait. done signal ] fork.
 [
  deadline := Time millisecondClockValue + 2000.
  [ (run exchange calls size < 2 or: [ run exchange calls second state ~= #running ])
    and: [ Time millisecondClockValue < deadline ] ]
   whileTrue: [ (Delay forMilliseconds: 1) wait ].
  self assert: run exchange calls second state equals: #running.
  run cancel.
  self deny: (done waitTimeoutMilliseconds: 2000).
  calls := run exchange calls.
  self assert: run state equals: #cancelled.
  self assert: (calls collect: #state) asArray equals: #(completed cancelled cancelled).
  self assert: calls first result asArray equals: #(42).
  self assert: calls last operation isNil
 ] ensure: [ run cancel. run wait. waiter terminate ]
]

{ #category : 'tests' }
SmallGPTalkToolLoopTest >> testModelFailureDoesNotDiscardACompletedEvaluation [
 | run |
 modelAction := [ :request |
  request calls ifEmpty: [ self replyWith: { self call: 'saved' source: 'SmallGPTalkToolLoopTest' } ]
   ifNotEmpty: [ self error: 'The model connection failed.' ] ].
 run := self session send: 'Keep the evaluation'.
 run wait.
 self assert: run state equals: #failed.
 self assert: run exchange calls first state equals: #completed.
 self assert: run exchange calls first result identicalTo: self class
]

{ #category : 'tests - validation' }
SmallGPTalkToolLoopTest >> testDuplicateIdentifiersRejectTheWholeReply [
 | run first second |
 first := self call: 'duplicate' source: 'Object new'.
 second := self call: 'duplicate' source: 'Object new'.
 modelAction := [ :request | self replyWith: { first. second } ].
 run := self session send: 'Reject duplicates'.
 run wait.
 self assert: run state equals: #failed.
 self assert: run exchange replies isEmpty.
 self assert: first operation isNil.
 self assert: second operation isNil
]

{ #category : 'tests - validation' }
SmallGPTalkToolLoopTest >> testInvalidLaterCallDoesNotExecuteTheFirstCall [
 | run first |
 first := self call: 'valid' source: 'Object new'.
 modelAction := [ :request | self replyWith: { first. Object new } ].
 run := self session send: 'Reject the whole reply'.
 run wait.
 self assert: run state equals: #failed.
 self assert: run exchange replies isEmpty.
 self assert: first operation isNil
]

{ #category : 'tests - validation' }
SmallGPTalkToolLoopTest >> testIdentifiersCannotRepeatInLaterExchanges [
 | session first second original |
 session := self session.
 modelAction := [ :request |
  request calls ifEmpty: [ self replyWith: { self call: 'once' source: 'Object new' } ]
   ifNotEmpty: [ 'Complete.' ] ].
 first := session send: 'First'.
 first wait.
 original := first exchange calls first result.
 second := session send: 'Duplicate in another exchange'.
 second wait.
 self assert: first state equals: #completed.
 self assert: second state equals: #failed.
 self assert: second exchange replies isEmpty.
 self assert: first exchange calls first result identicalTo: original
]

{ #category : 'tests - limits' }
SmallGPTalkToolLoopTest >> testConfiguredLimitStopsRepeatedModelRequests [
 | session run requests |
 requests := 0.
 modelAction := [ :request |
  requests := requests + 1.
  self replyWith: { self call: requests asString source: 'nil' } ].
 session := self session.
 session maxTurns: 3.
 run := session send: 'Stop at the limit'.
 run wait.
 self assert: run state equals: #failed.
 self assert: run error equals: 'The model request limit was reached.'.
 self assert: requests equals: 3.
 self assert: run exchange calls size equals: 3.
 self assert: (run exchange calls allSatisfy: [ :call | call state = #completed ])
]

{ #category : 'tests - fork' }
SmallGPTalkToolLoopTest >> testForkCopiesEvaluationRecordsButSharesTheirLiveValues [
 | session run fork original copied next |
 modelAction := [ :request |
  (request history isEmpty and: [ request calls isEmpty ])
   ifTrue: [ self replyWith: { self call: 'once' source: 'OrderedCollection with: 42' } ]
   ifFalse: [ 'Done.' ] ].
 session := self session.
 run := session send: 'Evaluate'. run wait.
 fork := session forkAt: run exchange.
 original := run exchange calls first.
 copied := fork conversation first calls first.
 self deny: copied identicalTo: original.
 self deny: copied operation identicalTo: original operation.
 self assert: copied result identicalTo: original result.
 self assert: fork conversation first modelContext calls first identicalTo: copied.
 self assert: run exchange modelContext calls first identicalTo: original.
 copied result add: 7.
 self assert: original result asArray equals: #(42 7).
 self assert: copied state equals: #completed.
 next := fork send: 'Continue'. next wait.
 self assert: next state equals: #completed.
 self assert: next exchange calls isEmpty.
 self assert: original result asArray equals: #(42 7)
]

{ #category : 'tests - timeout' }
SmallGPTalkToolLoopTest >> testEvaluationTimeoutReturnsToTheModel [
 | session run |
 modelAction := [ :request |
  request calls ifEmpty: [ self replyWith: { self call: 'timeout' source: '[ true ] whileTrue' } ]
   ifNotEmpty: [ self assert: request calls first state equals: #failed.
    self assert: request calls first error equals: 'The operation exceeded its time limit.'.
    'Stopped the long evaluation.' ] ].
 session := self session.
 session tools: { SmallGPTalkEvaluate new timeoutSeconds: 0.03; yourself }.
 run := session send: 'Time out the evaluation'.
 run wait.
 self assert: run state equals: #completed.
 self assert: run result equals: 'Stopped the long evaluation.'.
 self assert: run exchange calls first operation state equals: #failed
]

{ #category : 'tests - image access' }
SmallGPTalkToolLoopTest >> testImageAccessIsExclusiveAndReleasedAfterCancellation [
 | started first second next done waiter free |
 started := Semaphore new.
 modelAction := [ :request | started signal. Semaphore new wait ].
 first := self session send: 'Hold the image'.
 second := nil.
 waiter := nil.
 [
  self deny: (started waitTimeoutMilliseconds: 2000).
  second := self session send: 'Compete for the image'.
  done := Semaphore new.
  waiter := [ second wait. done signal ] fork.
  self deny: (done waitTimeoutMilliseconds: 2000).
  self assert: second state equals: #failed.
  self assert: second error equals: 'Another run is using the image.'.
  modelAction := [ :request | 'A plain request can continue.' ].
  free := (SmallGPTalkSession withModel: self) send: 'No image tools'.
  free wait.
  self assert: free state equals: #completed.
  self assert: first state equals: #running.
  first cancel; wait.
  modelAction := [ :request | 'The image is available.' ].
  next := self session send: 'Use the released image'.
  next wait.
  self assert: next state equals: #completed
 ] ensure: [
  first cancel; wait.
  second ifNotNil: [ second cancel; wait ].
  waiter ifNotNil: [ waiter terminate ] ]
]

{ #category : 'tests - compaction' }
SmallGPTalkToolLoopTest >> testCompactionDoesNotForgetUsedToolIdentifiers [
 | session run |
 modelAction := [ :request |
  request isCompaction ifTrue: [ 'The evaluation completed.' ]
  ifFalse: [ request calls ifEmpty: [ self replyWith: { self call: 'retained' source: 'Object new' } ]
   ifNotEmpty: [ 'Done.' ] ] ].
 session := self session.
 run := session send: 'First'. run wait.
 run := session compact. run wait.
 self assert: run state equals: #completed.
 run := session send: 'Try the same identifier'. run wait.
 self assert: run state equals: #failed.
 self assert: run exchange calls isEmpty.
 self assert: session conversation first calls first state equals: #completed
]

{ #category : 'tests - usage' }
SmallGPTalkToolLoopTest >> testContextUsageIncludesToolArgumentsAndRecordedOutput [
 | session run measured |
 modelAction := [ :request |
  request calls ifEmpty: [ self replyWith: { self call: 'output' source: 'String new: 100 withAll: $x' } ]
   ifNotEmpty: [ measured := request characterCount. 'Done.' ] ].
 session := self session.
 run := session send: 'Evaluate'. run wait.
 self assert: run state equals: #completed.
 self assert: measured > 100.
 self assert: run exchange characterCount > 100
]

{ #category : 'tests - usage' }
SmallGPTalkToolLoopTest >> testContextMeasurementDoesNotReadTheLiveValueAgain [
 | session run call count |
 modelAction := [ :request |
  request calls ifEmpty: [ self replyWith: { self call: 'live' source: 'OrderedCollection with: 42' } ]
   ifNotEmpty: [ 'Done.' ] ].
 session := self session.
 run := session send: 'Evaluate'. run wait.
 self assert: run state equals: #completed.
 call := run exchange calls first.
 count := run exchange characterCount.
 call result add: (String new: 1000 withAll: $x).
 self assert: run exchange characterCount equals: count
]

{ #category : 'tests - compaction' }
SmallGPTalkToolLoopTest >> testAutomaticCompactionKeepsCompletedEvaluationWithoutReplay [
 | session run original value summaries |
 modelAction := [ :request |
  request calls ifEmpty: [ self replyWith: { self call: 'once' source: 'OrderedCollection with: 42' } ]
   ifNotEmpty: [ 'Done.' ] ].
 session := self session.
 run := session send: 'Evaluate'. run wait.
 original := run exchange calls first.
 value := original result.
 session context autoCompactLimit: 1.
 summaries := 0.
 modelAction := [ :request |
  request isCompaction
   ifTrue: [ summaries := summaries + 1. 'The evaluation is complete.' ]
   ifFalse: [ self assert: request calls isEmpty. 'Continue.' ] ].
 run := session send: 'Next'. run wait.
 self assert: run state equals: #completed.
 self assert: summaries equals: 1.
 self assert: session conversation first calls first identicalTo: original.
 self assert: original result identicalTo: value.
 self assert: value asArray equals: #(42).
 self assert: run exchange calls isEmpty
]

{ #category : 'tests - observation' }
SmallGPTalkToolLoopTest >> testProgressExposesCompletedEvaluationBeforeTheRunFinishes [
 | session run entered states values seen |
 entered := Semaphore new.
 modelAction := [ :request |
  request calls ifEmpty: [ self replyWith: { self call: 'progress' source: '6 factorial' } ]
   ifNotEmpty: [ entered signal. Semaphore new wait ] ].
 session := self session.
 states := OrderedCollection new.
 values := OrderedCollection new.
 seen := OrderedCollection new.
 session whenChanged: [ :exchange |
  seen add: exchange.
  states add: exchange state.
  exchange calls do: [ :call | call state = #completed ifTrue: [ values add: call result ] ] ].
 run := session send: 'Compute'.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  self assert: run state equals: #running.
  self assert: (values includes: 720).
  self assert: (seen allSatisfy: [ :exchange | exchange == run exchange ]).
  self assert: states first equals: #running.
  run cancel; wait.
  self assert: states last equals: #cancelled
 ] ensure: [ run cancel; wait ]
]

{ #category : 'tests - observation' }
SmallGPTalkToolLoopTest >> testBrokenProgressObserverDoesNotRepeatEvaluation [
 | session run observer |
 modelAction := [ :request |
  request calls ifEmpty: [ self replyWith: { self call: 'once-observed' source: 'OrderedCollection with: 42' } ]
   ifNotEmpty: [ 'Done.' ] ].
 session := self session.
 observer := session whenChanged: [ :exchange | self error: 'Progress observer failed.' ].
 run := session send: 'Evaluate'. run wait.
 self assert: run state equals: #completed.
 self assert: run exchange calls size equals: 1.
 self assert: run exchange calls first result asArray equals: #(42).
 self assert: session observerErrors notEmpty.
 session removeObserver: observer
]

{ #category : 'tests - observation' }
SmallGPTalkToolLoopTest >> testCancelAtToolStartDoesNotExecuteItsOperation [
 | session run started |
 started := false.
 modelAction := [ :request |
  request calls ifEmpty: [ self replyWith: {
   self call: 'first' source: '1 + 1'.
   self call: 'second' source: '2 + 2' } ] ifNotEmpty: [ 'Done.' ] ].
 session := self session.
 session whenChanged: [ :exchange |
  (exchange calls anySatisfy: [ :call | call state = #running ]) ifTrue: [
   started := true.
   session cancel ] ].
 run := session send: 'Evaluate'. run wait.
 self assert: started.
 self assert: run state equals: #cancelled.
 self assert: (run exchange calls allSatisfy: [ :call | call state = #cancelled ]).
 self assert: (run exchange calls allSatisfy: [ :call | call operation isNil ])
]

{ #category : 'tests - context' }
SmallGPTalkToolLoopTest >> testEachCallKeepsItsGeneratingContextInAFork [
 | session run requests first second fork copied |
 modelAction := [ :request | 'Earlier answer.' ].
 session := self session.
 run := session send: 'Earlier'. run wait.
 first := self call: 'first' source: 'OrderedCollection with: 42'.
 second := self call: 'second' source: '6 factorial'.
 requests := OrderedCollection new.
 modelAction := [ :request |
  requests add: request.
  requests size = 1 ifTrue: [ self replyWith: { first } ] ifFalse: [
   requests size = 2 ifTrue: [ self replyWith: { second } ] ifFalse: [ 'Done.' ] ] ].
 run := session send: 'Evaluate'. run wait.
 self assert: run state equals: #completed.
 self assert: (run exchange contextForCall: first) identicalTo: requests first.
 self assert: (run exchange contextForCall: second) identicalTo: requests second.
 fork := session forkAt: run exchange.
 copied := fork conversation last.
 self assert: (copied contextForCall: copied calls second) history first identicalTo: fork conversation first.
 self assert: (copied contextForCall: copied calls second) calls first identicalTo: copied calls first.
 self deny: copied calls first identicalTo: first.
 self assert: copied calls first result identicalTo: first result
]

{ #category : 'tests - observation' }
SmallGPTalkToolLoopTest >> testNotificationsOrderRepliesCallsAndFinalOutcome [
 | session run seen |
 modelAction := [ :request |
  request calls ifEmpty: [ self replyWith: {
   self call: 'bad' source: '1 + ]'.
   self call: 'good' source: '6 factorial' } ]
  ifNotEmpty: [ 'Done.' ] ].
 session := self session.
 seen := OrderedCollection new.
 session whenChanged: [ :exchange |
  seen add: { exchange state. exchange replies size.
   (exchange calls collect: #state) asArray } ].
 session whenFinished: [ :finished | seen add: { #finished. finished state } ].
 run := session send: 'Evaluate both'. run wait.
 self assert: seen asArray equals: #(
  (running 0 ())
  (running 1 (pending pending))
  (running 1 (running pending))
  (running 1 (failed pending))
  (running 1 (failed running))
  (running 1 (failed completed))
  (running 2 (failed completed))
  (completed 2 (failed completed))
  (finished completed)).
 self assert: run exchange calls last result equals: 720.
 self assert: session observerErrors isEmpty
]

{ #category : 'tests - observation' }
SmallGPTalkToolLoopTest >> testCancelAfterAResultPublishesCancelledCallsBeforeCompletion [
 | session run seen requests |
 requests := 0.
 modelAction := [ :request |
  requests := requests + 1.
  self replyWith: {
   self call: 'saved' source: 'OrderedCollection with: 42'.
   self call: 'skipped' source: '6 factorial' } ].
 session := self session.
 seen := OrderedCollection new.
 session whenChanged: [ :exchange |
  seen add: { exchange state. (exchange calls collect: #state) asArray }.
  (exchange state = #running and: [ exchange calls notEmpty and: [
   exchange calls first state = #completed ] ]) ifTrue: [ session cancel ] ].
 session whenFinished: [ :finished |
  seen add: { #finished. (finished exchange calls collect: #state) asArray } ].
 run := session send: 'Cancel after the first result'. run wait.
 self assert: seen asArray equals: #(
  (running ())
  (running (pending pending))
  (running (running pending))
  (running (completed pending))
  (cancelled (completed cancelled))
  (finished (completed cancelled))).
 self assert: requests equals: 1.
 self assert: run exchange calls first result asArray equals: #(42).
 self assert: run exchange calls last operation isNil.
 self assert: session observerErrors isEmpty
]
