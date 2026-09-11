Class {
 #name : 'SmallGPTalkWorkspaceTest',
 #superclass : 'TestCase',
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkWorkspaceTest >> testEvaluationBindsWorkspaceAndRecordsRealTargets [
 | evaluation interaction |
 evaluation := SmallGPTalkEvaluation source: 'pharo browse: (SmallGPTalkEvaluation >> #execute). pharo inspect: nil'.
 evaluation execute.
 self assert: evaluation state equals: #completed.
 self assert: evaluation interactions size equals: 2.
 interaction := evaluation interactions first.
 self assert: interaction kind equals: #browse.
 self assert: interaction target identicalTo: SmallGPTalkEvaluation >> #execute.
 self assert: interaction evaluation identicalTo: evaluation.
 self assert: evaluation interactions last target isNil.
 self deny: (Smalltalk globals includesKey: #pharo)
]

{ #category : 'tests' }
SmallGPTalkWorkspaceTest >> testInteractionArrivesDuringEvaluationAndObserverErrorsDoNotFailIt [
 | tool evaluation seen subscription |
 tool := SmallGPTalkEvaluate new.
 seen := OrderedCollection new.
 subscription := tool whenInteraction: [ :interaction |
  self assert: interaction evaluation state equals: #running.
  seen add: interaction ].
 tool whenInteraction: [ :interaction | Error signal: 'Observer failure.' ].
 evaluation := tool prepare: (Dictionary new at: 'source' put: 'pharo browse: Object'; yourself).
 evaluation execute.
 self assert: evaluation state equals: #completed.
 self assert: seen first identicalTo: evaluation interactions first.
 self assert: tool interactionErrors asArray equals: #('Observer failure.').
 tool removeInteractionObserver: subscription
]

{ #category : 'tests' }
SmallGPTalkWorkspaceTest >> testFailureKeepsEarlierInteractions [
 | evaluation |
 evaluation := SmallGPTalkEvaluation source: 'pharo browse: Object. Error signal: ''Failed after browsing.'''.
 evaluation execute.
 self assert: evaluation state equals: #failed.
 self assert: evaluation interactions size equals: 1
]

{ #category : 'tests' }
SmallGPTalkWorkspaceTest >> testCopiedEvaluationKeepsTargetsAndChangesOrigin [
 | evaluation copied target |
 evaluation := SmallGPTalkEvaluation source: 'pharo inspect: OrderedCollection new'.
 evaluation execute.
 target := evaluation result.
 copied := evaluation copy.
 self deny: copied interactions first == evaluation interactions first.
 self assert: copied interactions first evaluation identicalTo: copied.
 self assert: copied interactions first target identicalTo: target
]

{ #category : 'tests' }
SmallGPTalkWorkspaceTest >> testFinishedWorkspaceCannotPublishNewActions [
 | evaluation workspace |
 evaluation := SmallGPTalkEvaluation source: 'pharo'.
 evaluation execute.
 workspace := evaluation result.
 self should: [ workspace browse: Object ] raise: Error.
 self assert: evaluation interactions isEmpty
]

{ #category : 'tests' }
SmallGPTalkWorkspaceTest >> testCopiedToolDoesNotKeepViewSubscriptions [
 | tool copied count evaluation |
 count := 0.
 tool := SmallGPTalkEvaluate new.
 tool whenInteraction: [ :interaction | count := count + 1 ].
 copied := tool copy.
 evaluation := copied prepare: (Dictionary new at: 'source' put: 'pharo browse: Object'; yourself).
 evaluation execute.
 self assert: evaluation state equals: #completed.
 self assert: count equals: 0
]

{ #category : 'tests' }
SmallGPTalkWorkspaceTest >> testFollowerDefersAndStopsPendingActions [
 | tool follower tasks shown evaluation |
 tool := SmallGPTalkEvaluate new.
 tasks := OrderedCollection new.
 shown := OrderedCollection new.
 follower := SmallGPTalkFollower schedule: [ :work | tasks add: work ] open: [ :interaction | shown add: interaction ].
 follower follow: { tool }.
 evaluation := tool prepare: (Dictionary new at: 'source' put: 'pharo browse: Object. pharo inspect: 42'; yourself).
 evaluation execute.
 self assert: tasks size equals: 2.
 self assert: shown isEmpty.
 tasks first value.
 self assert: shown first identicalTo: evaluation interactions first.
 follower stop.
 tasks last value.
 self assert: shown size equals: 1.
 evaluation := tool prepare: (Dictionary new at: 'source' put: 'pharo browse: Object'; yourself).
 evaluation execute.
 self assert: tasks size equals: 2
]

{ #category : 'tests' }
SmallGPTalkWorkspaceTest >> testFollowerRetainsWindowErrorsWithoutFailingEvaluation [
 | tool follower tasks evaluation |
 tool := SmallGPTalkEvaluate new.
 tasks := OrderedCollection new.
 follower := SmallGPTalkFollower schedule: [ :work | tasks add: work ] open: [ :interaction | Error signal: 'Cannot open.' ].
 [
  follower follow: { tool }.
  evaluation := tool prepare: (Dictionary new at: 'source' put: 'pharo inspect: 42'; yourself).
  evaluation execute.
  tasks first value.
  self assert: follower errors asArray equals: #('Cannot open.').
  self assert: evaluation state equals: #completed
 ] ensure: [ follower stop ]
]

{ #category : 'tests' }
SmallGPTalkWorkspaceTest >> testResumingDoesNotOpenOldPendingInteractions [
 | tool follower tasks shown evaluation |
 tool := SmallGPTalkEvaluate new.
 tasks := OrderedCollection new.
 shown := OrderedCollection new.
 follower := SmallGPTalkFollower schedule: [ :work | tasks add: work ] open: [ :interaction | shown add: interaction ].
 [
  follower follow: { tool }.
  evaluation := tool prepare: (Dictionary new at: 'source' put: 'pharo browse: Object'; yourself).
  evaluation execute.
  follower stop; follow: { tool }.
  tasks first value.
  self assert: shown isEmpty
 ] ensure: [ follower stop ]
]

{ #category : 'model protocol' }
SmallGPTalkWorkspaceTest >> respondTo: request [
 ^ request calls ifEmpty: [ SmallGPTalkReply text: '' calls: {
  SmallGPTalkCall id: 'workspace' name: 'evaluate' arguments:
   (Dictionary new at: 'source' put: request text; yourself) } ]
  ifNotEmpty: [ 'Done.' ]
]

{ #category : 'tests' }
SmallGPTalkWorkspaceTest >> testSessionForkAndEvaluationViewRetainInteractions [
 | session run fork view original copied |
 session := SmallGPTalkSession withModel: self.
 session tools: { SmallGPTalkEvaluate new }.
 run := session send: 'pharo browse: Object. pharo inspect: OrderedCollection new'.
 run wait.
 self assert: run state equals: #completed.
 original := run exchange calls first operation.
 fork := session forkAt: run exchange.
 copied := fork conversation first calls first operation.
 view := SmallGPTalkEvaluations forExchange: fork conversation first.
 self assert: view selectedInteraction evaluation identicalTo: copied.
 self deny: view selectedInteraction == original interactions first.
 self assert: copied interactions last target identicalTo: original result.
 self assert: view sourceText equals: original source
]
