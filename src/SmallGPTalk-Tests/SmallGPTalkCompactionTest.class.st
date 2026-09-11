Class {
 #name : 'SmallGPTalkCompactionTest',
 #superclass : 'TestCase',
 #instVars : [ 'modelAction' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'model protocol' }
SmallGPTalkCompactionTest >> respondTo: request [ ^ modelAction value: request ]

{ #category : 'tests' }
SmallGPTalkCompactionTest >> testCompactionChangesFutureContextButKeepsHistory [
 | session run original received |
 modelAction := [ :request | 'Original answer.' ].
 session := SmallGPTalkSession withModel: self.
 run := session send: 'Remember 42'. run wait.
 original := session conversation first.
 modelAction := [ :request | received := request. 'The remembered number is 42.' ].
 run := session compact.
 run wait.
 self assert: run state equals: #completed.
 self assert: received isCompaction.
 self assert: received history first identicalTo: original.
 self assert: session conversation size equals: 1.
 self assert: session conversation first identicalTo: original.
 modelAction := [ :request | received := request. '42' ].
 run := session send: 'What number?'. run wait.
 self deny: received isCompaction.
 self assert: received history isEmpty.
 self assert: received summary equals: 'The remembered number is 42.'.
 self assert: session conversation size equals: 2
]

{ #category : 'tests' }
SmallGPTalkCompactionTest >> testSummaryRequestDoesNotOfferToolsOrChangeTheOriginal [
 | request summary |
 request := (SmallGPTalkRequest text: 'Continue' history: #() agent: nil)
  withTools: { SmallGPTalkEvaluate new }.
 summary := request forCompaction.
 self assert: summary isCompaction.
 self assert: summary tools isEmpty.
 self assert: request tools size equals: 1.
 self deny: request isCompaction.
 self assert: summary text equals: request text
]

{ #category : 'tests' }
SmallGPTalkCompactionTest >> testCancelOnCompactionStartPreventsTheModelRequest [
 | session run requested |
 modelAction := [ :request | 'First answer.' ].
 session := SmallGPTalkSession withModel: self.
 run := session send: 'First'. run wait.
 requested := false.
 modelAction := [ :request | requested := true. 'Summary.' ].
 session whenChanged: [ :exchange |
  (exchange context isCompaction and: [ exchange state = #running ])
   ifTrue: [ session cancel ] ].
 run := session compact. run wait.
 self assert: run state equals: #cancelled.
 self deny: requested.
 self assert: session context summary isNil.
 self assert: session conversation size equals: 1
]

{ #category : 'tests' }
SmallGPTalkCompactionTest >> testInvalidSummaryPreservesThePreviousContext [
 | session run history |
 modelAction := [ :request | 'Answer.' ].
 session := SmallGPTalkSession withModel: self.
 run := session send: 'First'. run wait.
 history := session conversation.
 modelAction := [ :request | '   ' ].
 run := session compact.
 run wait.
 self assert: run state equals: #failed.
 self assert: session context summary isNil.
 self assert: session conversation equals: history
]

{ #category : 'tests' }
SmallGPTalkCompactionTest >> testCancellationPreservesTheLastSummaryAndItsBoundary [
 | session run started previous received |
 modelAction := [ :request | 'Original summary.' ].
 session := SmallGPTalkSession withModel: self.
 run := session send: 'First'. run wait.
 run := session compact. run wait.
 previous := session context summary.
 run := session send: 'Second'. run wait.
 started := Semaphore new.
 modelAction := [ :request | started signal. Semaphore new wait ].
 run := session compact.
 [
  self deny: (started waitTimeoutMilliseconds: 2000).
  run cancel; wait.
  self assert: run state equals: #cancelled.
  self assert: session context summary equals: previous.
  self assert: session conversation size equals: 2
 ] ensure: [ run cancel; wait ].
 modelAction := [ :request | received := request. 'Continue.' ].
 run := session send: 'Third'. run wait.
 self assert: received history size equals: 1.
 self assert: received history first request equals: 'Second'
]

{ #category : 'tests - usage' }
SmallGPTalkCompactionTest >> testContextUsageCountsSelectedTextAndSummary [
 | context agent request |
 context := SmallGPTalkContext new.
 agent := SmallGPTalkAgent named: 'Ada'.
 agent instructions: '1234'.
 request := context requestFor: '123456' history: #() agent: agent.
 self assert: request characterCount equals: 10.
 context autoCompactLimit: 20.
 self assert: (context usageFor: request) equals: 50.
 context absorb: '12345' through: 0.
 request := context requestFor: '123456' history: #() agent: agent.
 self assert: request characterCount equals: 15.
 self assert: (context usageFor: request) equals: 75.
 context autoCompactLimit: nil.
 self assert: (context usageFor: request) isNil
]

{ #category : 'tests - usage' }
SmallGPTalkCompactionTest >> testContextMeasurementCountsHistoryOnlyOnce [
 | session run request |
 modelAction := [ :input | 'abc' ].
 session := SmallGPTalkSession withModel: self.
 run := session send: '12'. run wait.
 run := session send: '345'. run wait.
 request := session context requestFor: '6' history: session conversation agent: nil.
 self assert: request characterCount equals: 12
]

{ #category : 'tests - automatic' }
SmallGPTalkCompactionTest >> testAutomaticCompactionPrecedesTheNextRequest [
 | session run original requests |
 modelAction := [ :request | String new: 100 withAll: $x ].
 session := SmallGPTalkSession withModel: self.
 run := session send: 'First'. run wait.
 original := run exchange.
 session context autoCompactLimit: 50.
 requests := OrderedCollection new.
 modelAction := [ :request |
  requests add: request.
  request isCompaction ifTrue: [ 'Summary.' ] ifFalse: [ 'Done.' ] ].
 run := session send: 'Next'. run wait.
 self assert: run state equals: #completed.
 self assert: requests size equals: 2.
 self assert: requests first isCompaction.
 self assert: requests last summary equals: 'Summary.'.
 self assert: requests last history isEmpty.
 self assert: run exchange context identicalTo: requests last.
 self assert: session conversation first identicalTo: original.
 self assert: session conversation size equals: 2
]

{ #category : 'tests - automatic' }
SmallGPTalkCompactionTest >> testFailedAutomaticSummaryDoesNotSendTheNextRequest [
 | session run count |
 modelAction := [ :request | String new: 100 withAll: $x ].
 session := SmallGPTalkSession withModel: self.
 run := session send: 'First'. run wait.
 session context autoCompactLimit: 50.
 count := 0.
 modelAction := [ :request | count := count + 1. ' ' ].
 run := session send: 'Next'. run wait.
 self assert: run state equals: #failed.
 self assert: count equals: 1.
 self assert: session context summary isNil.
 self assert: run exchange request equals: 'Next'.
 self assert: session conversation size equals: 2
]

{ #category : 'tests - automatic' }
SmallGPTalkCompactionTest >> testCancelledAutomaticSummaryPreservesContext [
 | session run entered |
 modelAction := [ :request | String new: 100 withAll: $x ].
 session := SmallGPTalkSession withModel: self.
 run := session send: 'First'. run wait.
 session context autoCompactLimit: 50.
 entered := Semaphore new.
 modelAction := [ :request |
  request isCompaction ifTrue: [ entered signal. Semaphore new wait ]. 'Done.' ].
 run := session send: 'Next'.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  run cancel; wait.
  self assert: run state equals: #cancelled.
  self assert: session context summary isNil
 ] ensure: [ run cancel; wait ]
]

{ #category : 'tests - automatic' }
SmallGPTalkCompactionTest >> testAutomaticCompactionCanBeDisabled [
 | session run requests |
 requests := OrderedCollection new.
 modelAction := [ :request | requests add: request. String new: 100 withAll: $x ].
 session := SmallGPTalkSession withModel: self.
 session context autoCompactLimit: nil.
 run := session send: 'First'. run wait.
 run := session send: 'Next'. run wait.
 self assert: run state equals: #completed.
 self assert: requests size equals: 2.
 self deny: requests last isCompaction.
 self assert: requests last history size equals: 1
]

{ #category : 'tests - automatic' }
SmallGPTalkCompactionTest >> testLongToolTurnCompactsCompletedResultsBeforeContinuing [
 | session run requests call fork |
 requests := OrderedCollection new.
 call := SmallGPTalkCall id: 'once' name: 'evaluate' arguments:
  (Dictionary new at: 'source' put: 'String new: 200 withAll: $x'; yourself).
 modelAction := [ :request |
  requests add: request.
  requests size = 1
   ifTrue: [ SmallGPTalkReply text: '' calls: { call } ]
   ifFalse: [ request isCompaction ifTrue: [ 'The string was created.' ] ifFalse: [ 'Done.' ] ] ].
 session := SmallGPTalkSession withModel: self.
 session tools: { SmallGPTalkEvaluate new }.
 session context autoCompactLimit: 100.
 run := session send: 'Create a string'. run wait.
 self assert: run state equals: #completed.
 self assert: requests size equals: 3.
 self assert: requests second isCompaction.
 self assert: requests second calls first identicalTo: call.
 self assert: call state equals: #completed.
 self assert: requests last summary equals: 'The string was created.'.
 self assert: requests last calls size equals: 1.
 self assert: requests last calls first identicalTo: call.
 self assert: run exchange calls size equals: 1.
 self assert: call result equals: (String new: 200 withAll: $x).
 self assert: run exchange modelContext identicalTo: requests last.
 self assert: (run exchange contextForCall: call) identicalTo: requests first.
 self assert: (run exchange contextForCall: call) summary isNil.
 fork := session forkAt: run exchange.
 self assert: fork conversation last modelContext summary equals: requests last summary.
 self assert: fork conversation last modelContext calls first identicalTo: fork conversation last calls first.
 self assert: fork conversation last calls first result identicalTo: call result
]

{ #category : 'tests - automatic' }
SmallGPTalkCompactionTest >> testFailedMidTurnSummaryKeepsTheCompletedEvaluation [
 | session run count call |
 count := 0.
 call := SmallGPTalkCall id: 'once' name: 'evaluate' arguments:
  (Dictionary new at: 'source' put: 'String new: 200 withAll: $x'; yourself).
 modelAction := [ :request |
  count := count + 1.
  count = 1 ifTrue: [ SmallGPTalkReply text: '' calls: { call } ]
   ifFalse: [ ' ' ] ].
 session := SmallGPTalkSession withModel: self.
 session tools: { SmallGPTalkEvaluate new }.
 session context autoCompactLimit: 100.
 run := session send: 'Create a string'. run wait.
 self assert: run state equals: #failed.
 self assert: count equals: 2.
 self assert: run exchange calls first identicalTo: call.
 self assert: call state equals: #completed.
 self assert: call result size equals: 200
]

{ #category : 'tests - automatic' }
SmallGPTalkCompactionTest >> testCompactionDoesNotForgetUsedCallIdentifiers [
 | session run count first duplicate |
 count := 0.
 first := SmallGPTalkCall id: 'once' name: 'evaluate' arguments:
  (Dictionary new at: 'source' put: 'String new: 200 withAll: $x'; yourself).
 duplicate := SmallGPTalkCall id: 'once' name: 'evaluate' arguments:
  (Dictionary new at: 'source' put: '1 + 1'; yourself).
 modelAction := [ :request |
  request isCompaction ifTrue: [ 'The operation is complete.' ] ifFalse: [
   count := count + 1.
   SmallGPTalkReply text: '' calls: { count = 1 ifTrue: [ first ] ifFalse: [ duplicate ] } ] ].
 session := SmallGPTalkSession withModel: self.
 session tools: { SmallGPTalkEvaluate new }.
 session context autoCompactLimit: 100.
 run := session send: 'Create a string'. run wait.
 self assert: run state equals: #failed.
 self assert: run error equals: 'Tool call identifiers must not repeat.'.
 self assert: run exchange calls size equals: 1.
 self assert: first state equals: #completed.
 self assert: duplicate operation isNil
]

{ #category : 'tests - automatic' }
SmallGPTalkCompactionTest >> testCancelDuringMidTurnCompactionPreservesCompletedResults [
 | session run entered call |
 entered := Semaphore new.
 call := SmallGPTalkCall id: 'once' name: 'evaluate' arguments:
  (Dictionary new at: 'source' put: 'String new: 200 withAll: $x'; yourself).
 modelAction := [ :request |
  request isCompaction ifTrue: [ entered signal. Semaphore new wait ].
  SmallGPTalkReply text: '' calls: { call } ].
 session := SmallGPTalkSession withModel: self.
 session tools: { SmallGPTalkEvaluate new }.
 session context autoCompactLimit: 100.
 run := session send: 'Create a string'.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  run cancel; wait.
  self assert: run state equals: #cancelled.
  self assert: run exchange calls first identicalTo: call.
  self assert: call state equals: #completed.
  self assert: call result size equals: 200.
  self assert: session context summary isNil
 ] ensure: [ run cancel; wait ]
]

{ #category : 'tests - fork' }
SmallGPTalkCompactionTest >> testForkPreservesTheSelectedContextOfCopiedExchanges [
 | session run fork original copied |
 modelAction := [ :request | 'Answer.' ].
 session := SmallGPTalkSession withModel: self.
 run := session send: 'First'. run wait.
 run := session compact. run wait.
 run := session send: 'Second'. run wait.
 run := session send: 'Third'. run wait.
 original := run exchange.
 fork := session forkAt: original.
 copied := fork conversation last.
 self assert: copied context history size equals: 1.
 self assert: copied context history first identicalTo: fork conversation second.
 self deny: copied context history first == session conversation second.
 self assert: copied context summary equals: original context summary.
 self assert: copied context characterCount equals: original context characterCount
]

{ #category : 'tests - fork' }
SmallGPTalkCompactionTest >> testForkCopiesTheLimitWithoutUsingALaterSummary [
 | session run point fork received |
 modelAction := [ :request | 'Answer.' ].
 session := SmallGPTalkSession withModel: self.
 session context autoCompactLimit: nil.
 run := session send: 'First'. run wait.
 point := run exchange.
 run := session send: 'A later secret'. run wait.
 modelAction := [ :request | 'A summary with the later secret.' ].
 run := session compact. run wait.
 fork := session forkAt: point.
 self assert: fork context autoCompactLimit isNil.
 self assert: fork context summary isNil.
 modelAction := [ :request | received := request. 'Continue.' ].
 run := fork send: 'Next'. run wait.
 self assert: run state equals: #completed.
 self assert: received summary isNil.
 self assert: received history size equals: 1.
 self assert: received history first request equals: 'First'.
 fork context autoCompactLimit: 100.
 self assert: session context autoCompactLimit isNil
]

{ #category : 'tests - tokens' }
SmallGPTalkCompactionTest >> testMeasuredTokensTriggerCompactionBeforeNextRequest [
 | session run requests |
 modelAction := [ :request | (SmallGPTalkReply text: 'A' calls: #())
  usage: (SmallGPTalkContextUsage inputTokens: 80 capacity: 100); yourself ].
 session := SmallGPTalkSession withModel: self.
 (session send: 'First') wait.
 requests := OrderedCollection new.
 modelAction := [ :request | requests add: request. 'Summary or answer.' ].
 run := session send: 'Next'. run wait.
 self assert: run state equals: #completed.
 self assert: requests size equals: 2.
 self assert: requests first isCompaction.
 self assert: requests last history isEmpty
]

{ #category : 'tests - tokens' }
SmallGPTalkCompactionTest >> testMeasuredTokensTakePriorityOverCharactersWithoutRounding [
 | session requests |
 modelAction := [ :request | (SmallGPTalkReply text: 'A' calls: #())
  usage: (SmallGPTalkContextUsage inputTokens: 799 capacity: 1000); yourself ].
 session := SmallGPTalkSession withModel: self.
 (session send: 'First') wait.
 session context autoCompactLimit: 1.
 requests := OrderedCollection new.
 modelAction := [ :request | requests add: request. 'Answer.' ].
 (session send: 'Next') wait.
 self assert: requests size equals: 1.
 self deny: requests first isCompaction
]

{ #category : 'tests - tokens' }
SmallGPTalkCompactionTest >> testTokenPolicyConfigurationAndFork [
 | context fork |
 context := SmallGPTalkContext new.
 self assert: context autoCompactPercentage equals: 80.
 context autoCompactPercentage: 70.
 fork := context forFork.
 self assert: fork autoCompactPercentage equals: 70.
 fork autoCompactPercentage: nil.
 self assert: context autoCompactPercentage equals: 70.
 #(0 101 -1 1.5) do: [ :invalid |
  self should: [ context autoCompactPercentage: invalid ] raise: Error ]
]

{ #category : 'tests - tokens' }
SmallGPTalkCompactionTest >> testTokenCompactionWithinToolTurnKeepsCompletedCall [
 | session run requests call |
 call := SmallGPTalkCall id: 'once' name: 'evaluate' arguments:
  (Dictionary new at: 'source' put: '6 factorial'; yourself).
 requests := OrderedCollection new.
 modelAction := [ :request |
  requests add: request.
  requests size = 1
   ifTrue: [ (SmallGPTalkReply text: '' calls: { call })
    usage: (SmallGPTalkContextUsage inputTokens: 90 capacity: 100); yourself ]
   ifFalse: [ 'The evaluation is complete.' ] ].
 session := SmallGPTalkSession withModel: self.
 session tools: { SmallGPTalkEvaluate new }.
 run := session send: 'Evaluate'. run wait.
 self assert: run state equals: #completed.
 self assert: requests size equals: 3.
 self assert: requests second isCompaction.
 self assert: requests last calls first identicalTo: call.
 self assert: call result equals: 720.
 self assert: run exchange calls size equals: 1
]

{ #category : 'tests - tokens' }
SmallGPTalkCompactionTest >> testChangingModelDoesNotReuseItsTokenMeasurement [
 | session replacement requests |
 modelAction := [ :request | (SmallGPTalkReply text: 'A' calls: #())
  usage: (SmallGPTalkContextUsage inputTokens: 90 capacity: 100); yourself ].
 session := SmallGPTalkSession withModel: self.
 (session send: 'First') wait.
 replacement := self copy.
 session useModel: replacement.
 requests := OrderedCollection new.
 replacement answerWith: [ :request | requests add: request. 'Answer.' ].
 (session send: 'Next') wait.
 self assert: requests size equals: 1.
 self deny: requests first isCompaction
]

{ #category : 'model protocol' }
SmallGPTalkCompactionTest >> answerWith: block [ modelAction := block ]

{ #category : 'tests - tokens' }
SmallGPTalkCompactionTest >> testManualSummaryDoesNotReuseOldTokenMeasurement [
 | session requests |
 modelAction := [ :request | (SmallGPTalkReply text: 'A' calls: #())
  usage: (SmallGPTalkContextUsage inputTokens: 90 capacity: 100); yourself ].
 session := SmallGPTalkSession withModel: self.
 (session send: 'First') wait.
 modelAction := [ :request | 'Summary.' ].
 session compact wait.
 requests := OrderedCollection new.
 modelAction := [ :request | requests add: request. 'Answer.' ].
 (session send: 'Next') wait.
 self assert: requests size equals: 1.
 self deny: requests first isCompaction
]

{ #category : 'tests - tokens' }
SmallGPTalkCompactionTest >> testForkUsesItsCopiedMeasurementAndThreshold [
 | session run fork requests |
 modelAction := [ :request | (SmallGPTalkReply text: 'A' calls: #())
  usage: (SmallGPTalkContextUsage inputTokens: 75 capacity: 100); yourself ].
 session := SmallGPTalkSession withModel: self.
 session context autoCompactPercentage: 70.
 run := session send: 'First'. run wait.
 fork := session forkAt: run exchange.
 requests := OrderedCollection new.
 modelAction := [ :request | requests add: request. 'Summary or answer.' ].
 (fork send: 'Next') wait.
 self assert: requests size equals: 2.
 self assert: requests first isCompaction.
 self assert: session conversation size equals: 1
]

{ #category : 'tests - tokens' }
SmallGPTalkCompactionTest >> testAutomaticCompactionCanBeDisabledWithMeasuredTokens [
 | session requests |
 modelAction := [ :request | (SmallGPTalkReply text: 'A' calls: #())
  usage: (SmallGPTalkContextUsage inputTokens: 90 capacity: 100); yourself ].
 session := SmallGPTalkSession withModel: self.
 session context autoCompactPercentage: nil; autoCompactLimit: nil.
 (session send: 'First') wait.
 requests := OrderedCollection new.
 modelAction := [ :request | requests add: request. 'Answer.' ].
 (session send: 'Next') wait.
 self assert: requests size equals: 1.
 self deny: requests first isCompaction
]

{ #category : 'tests - tokens' }
SmallGPTalkCompactionTest >> testDisablingTokenThresholdSelectsCharacterPolicy [
 | session requests |
 modelAction := [ :request | (SmallGPTalkReply text: 'A' calls: #())
  usage: (SmallGPTalkContextUsage inputTokens: 1 capacity: 100); yourself ].
 session := SmallGPTalkSession withModel: self.
 (session send: 'First') wait.
 session context autoCompactPercentage: nil; autoCompactLimit: 1.
 requests := OrderedCollection new.
 modelAction := [ :request | requests add: request. 'Summary or answer.' ].
 (session send: 'Next') wait.
 self assert: requests size equals: 2.
 self assert: requests first isCompaction
]
