Class {
 #name : 'SmallGPTalkContextEstimateTest',
 #superclass : 'TestCase',
 #instVars : [ 'model', 'bodies', 'bodyAction' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkContextEstimateTest >> setUp [
 super setUp.
 bodies := OrderedCollection new.
 model := SmallGPTalkOpenAIModel model: 'fixture' effort: 'low' account: self transport: self.
 model contextWindow: 10000.
 bodyAction := [ :body | self reply: 'Done.' tokens: 2000 ]
]

{ #category : 'account protocol' }
SmallGPTalkContextEstimateTest >> withHeadersDo: block [ ^ block value: Dictionary new ]

{ #category : 'transport protocol' }
SmallGPTalkContextEstimateTest >> post: body headers: headers [
 bodies add: body.
 ^ bodyAction value: body
]

{ #category : 'fixtures' }
SmallGPTalkContextEstimateTest >> reply: text tokens: count [
 ^ (SmallGPTalkReply text: text calls: #())
  providerData: (Dictionary new
   at: 'usage' put: (Dictionary new at: 'input_tokens' put: count; yourself);
   at: 'output' put: { Dictionary new at: 'role' put: 'assistant'; at: 'content' put: text; yourself };
   yourself);
  yourself
]

{ #category : 'tests' }
SmallGPTalkContextEstimateTest >> testNewMessageGrowthTriggersCompaction [
 | session run |
 session := SmallGPTalkSession withModel: model.
 (session send: 'First') wait.
 run := session send: (String new: 6500 withAll: $x). run wait.
 self assert: run state equals: #completed.
 self assert: bodies size equals: 3.
 self assert: ((bodies second at: 'instructions') beginsWith: 'Summarize').
 self assert: session conversation size equals: 2
]

{ #category : 'tests' }
SmallGPTalkContextEstimateTest >> testUnicodeInputIsRejectedBeforeTransport [
 | session run |
 session := SmallGPTalkSession withModel: model.
 run := session send: (String new: 11000 withAll: $á). run wait.
 self assert: run state equals: #failed.
 self assert: (run error includesSubstring: 'estimated input').
 self assert: bodies isEmpty.
 self assert: session conversation size equals: 1
]

{ #category : 'tests' }
SmallGPTalkContextEstimateTest >> testPredictionIncludesDraftAndDoesNotChangeMeasuredUsage [
 | session run small large |
 session := SmallGPTalkSession withModel: model.
 run := session send: 'First'. run wait.
 small := session estimateFor: 'Next'.
 large := session estimateFor: (String new: 1000 withAll: $x).
 self assert: large inputTokens > small inputTokens.
 self assert: run exchange modelUsage inputTokens equals: 2000.
 self assert: bodies size equals: 1
]

{ #category : 'tests' }
SmallGPTalkContextEstimateTest >> testLargeToolOutputIsRetainedWhenTheNextRequestCannotFit [
 | session run call |
 call := SmallGPTalkCall id: 'once' name: 'evaluate' arguments:
  (Dictionary new at: 'source' put: 'String new: 15000 withAll: $x'; yourself).
 bodyAction := [ :body |
  bodies size = 1 ifTrue: [
   (SmallGPTalkReply text: '' calls: { call })
    usage: (SmallGPTalkContextUsage inputTokens: 2000 capacity: 10000); yourself ]
   ifFalse: [ self reply: 'Summary.' tokens: 1000 ] ].
 session := SmallGPTalkSession withModel: model.
 session tools: { SmallGPTalkEvaluate new }.
 run := session send: 'Make a string'. run wait.
 self assert: run state equals: #failed.
 self assert: call state equals: #completed.
 self assert: call result size equals: 15000.
 self assert: run exchange calls size equals: 1.
 self assert: bodies size equals: 1
]

{ #category : 'tests - UI' }
SmallGPTalkContextEstimateTest >> testDraftUpdatesEstimateWithoutSendingOrChangingMeasuredText [
 | session chat initial measured |
 session := SmallGPTalkSession withModel: model.
 (session send: 'First') wait.
 chat := SmallGPTalkChat forSession: session.
 [
  initial := chat estimateText.
  measured := chat contextText.
  chat messageText: (String new: 1000 withAll: $x).
  self deny: chat estimateText equals: initial.
  self assert: (chat estimateText includesSubstring: 'estimate').
  self assert: chat contextText equals: measured.
  self assert: bodies size equals: 1
 ] ensure: [ chat disconnect ]
]

{ #category : 'tests' }
SmallGPTalkContextEstimateTest >> testToolGrowthCompactsAndKeepsTheCompletedCall [
 | session run call |
 call := SmallGPTalkCall id: 'once' name: 'evaluate' arguments:
  (Dictionary new at: 'source' put: 'String new: 7000 withAll: $x'; yourself).
 bodyAction := [ :body |
  bodies size = 1 ifTrue: [
   (SmallGPTalkReply text: '' calls: { call })
    usage: (SmallGPTalkContextUsage inputTokens: 2000 capacity: 10000); yourself ]
   ifFalse: [ self reply: 'The string was created.' tokens: 1000 ] ].
 session := SmallGPTalkSession withModel: model.
 session tools: { SmallGPTalkEvaluate new }.
 run := session send: 'Make a string'. run wait.
 self assert: run state equals: #completed.
 self assert: bodies size equals: 3.
 self assert: ((bodies second at: 'instructions') beginsWith: 'Summarize').
 self assert: call state equals: #completed.
 self assert: call result size equals: 7000.
 self assert: run exchange calls size equals: 1
]

{ #category : 'tests' }
SmallGPTalkContextEstimateTest >> testManualSummaryAndModelChangeDoNotReuseOldSize [
 | session before after replacement |
 bodyAction := [ :body | self reply: 'Done.' tokens: 7000 ].
 session := SmallGPTalkSession withModel: model.
 (session send: 'First') wait.
 before := session estimateFor: 'Next'.
 session compact wait.
 after := session estimateFor: 'Next'.
 self assert: after inputTokens < before inputTokens.
 (session send: 'Continue') wait.
 replacement := SmallGPTalkOpenAIModel model: 'other' effort: 'low' account: self transport: self.
 replacement contextWindow: 20000.
 session useModel: replacement.
 after := session estimateFor: 'Next'.
 self assert: after capacity equals: 20000.
 self assert: after inputTokens < 7000
]

{ #category : 'tests' }
SmallGPTalkContextEstimateTest >> testForkKeepsEstimateAndUnicodeAddsMoreBytes [
 | session run fork ascii unicode |
 session := SmallGPTalkSession withModel: model.
 run := session send: 'First'. run wait.
 fork := session forkAt: run exchange.
 self assert: (fork estimateFor: 'Next') inputTokens equals: (session estimateFor: 'Next') inputTokens.
 ascii := session estimateFor: (String new: 100 withAll: $a).
 unicode := session estimateFor: (String new: 100 withAll: $á).
 self assert: unicode inputTokens > ascii inputTokens
]

{ #category : 'tests' }
SmallGPTalkContextEstimateTest >> testActiveRequestDoesNotEstimatePartialToolCalls [
 | session run entered |
 entered := Semaphore new.
 bodyAction := [ :body | entered signal. Semaphore new wait ].
 session := SmallGPTalkSession withModel: model.
 run := session send: 'First'.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  self assert: (session estimateFor: 'Next') isNil
 ] ensure: [ run cancel; wait ]
]
