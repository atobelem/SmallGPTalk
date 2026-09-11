Class {
 #name : 'SmallGPTalkReplyTest',
 #superclass : 'TestCase',
 #instVars : [ 'answer' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'model protocol' }
SmallGPTalkReplyTest >> respondTo: request [ ^ answer ]

{ #category : 'tests' }
SmallGPTalkReplyTest >> testTextHistoryUsesAReplyAndKeepsThePublicResult [
 | session run reply |
 answer := 'Hello.'.
 session := SmallGPTalkSession withModel: self.
 run := session send: 'First'. run wait.
 self assert: run state equals: #completed.
 self assert: run result identicalTo: answer.
 reply := run exchange replies first.
 self assert: reply text equals: answer.
 self assert: reply calls isEmpty.
 self assert: reply context identicalTo: run exchange modelContext.
 self assert: reply characterCount equals: answer size
]

{ #category : 'tests' }
SmallGPTalkReplyTest >> testOpaqueAndNilResultsRemainRealObjects [
 { Object new. nil } do: [ :value |
  | run reply |
  answer := value.
  run := (SmallGPTalkSession withModel: self) send: 'Return an object'. run wait.
  self assert: run state equals: #completed.
  self assert: run result identicalTo: value.
  reply := run exchange replies first.
  self assert: reply result identicalTo: value.
  self assert: reply text isEmpty.
  self assert: reply calls isEmpty.
  self assert: reply characterCount equals: 0 ]
]

{ #category : 'tests' }
SmallGPTalkReplyTest >> testForkCopiesTextRecordsAndKeepsResultIdentity [
 | session run fork original copied |
 answer := 'Hello.'.
 session := SmallGPTalkSession withModel: self.
 run := session send: 'First'. run wait.
 fork := session forkAt: run exchange.
 original := run exchange replies first.
 copied := fork conversation first replies first.
 self deny: copied identicalTo: original.
 self assert: copied text equals: original text.
 self assert: copied context identicalTo: fork conversation first modelContext.
 self assert: fork conversation first response identicalTo: answer.
 self assert: copied result identicalTo: answer
]

{ #category : 'tests' }
SmallGPTalkReplyTest >> testStructuredReplyRemainsTheResultAndIsCopiedOnFork [
 | session run fork |
 answer := SmallGPTalkReply text: 'Done.' calls: #().
 session := SmallGPTalkSession withModel: self.
 run := session send: 'First'. run wait.
 self assert: run result identicalTo: answer.
 self assert: answer result identicalTo: answer.
 fork := session forkAt: run exchange.
 self assert: fork conversation first response identicalTo: fork conversation first replies first.
 self deny: fork conversation first response identicalTo: answer
]

{ #category : 'tests' }
SmallGPTalkReplyTest >> testRequestAdaptsSimpleHistoryForMeasurementAndEncoding [
 | request input |
 request := (SmallGPTalkRequest text: 'Continue' history: #() agent: nil) following: #('Earlier.').
 self assert: request replies first text equals: 'Earlier.'.
 self assert: request replyCharacterCount equals: 8.
 self assert: request calls isEmpty.
 input := (SmallGPTalkOpenAIRequest new encode: request model: 'fixture' effort: 'low') at: 'input'.
 self assert: (input last at: 'role') equals: 'assistant'.
 self assert: (input last at: 'content') equals: 'Earlier.'
]

{ #category : 'conversion protocol' }
SmallGPTalkReplyTest >> asSmallGPTalkReply [
 ^ SmallGPTalkReply text: 'Adapted.' calls: #()
]

{ #category : 'tests' }
SmallGPTalkReplyTest >> testModelCanSupplyConversionWithoutInheritingFromReply [
 | run |
 answer := self.
 run := (SmallGPTalkSession withModel: self) send: 'Adapt'. run wait.
 self assert: run state equals: #completed.
 self assert: run result text equals: 'Adapted.'.
 self assert: run exchange replies first identicalTo: run result
]

{ #category : 'tests' }
SmallGPTalkReplyTest >> testStoredTextDoesNotChangeWithTheOriginalString [
 | run |
 answer := 'Hello.' copy.
 run := (SmallGPTalkSession withModel: self) send: 'Record'. run wait.
 answer at: 1 put: $J.
 self assert: run result identicalTo: answer.
 self assert: run result equals: 'Jello.'.
 self assert: run exchange replies first text equals: 'Hello.'
]

{ #category : 'tests' }
SmallGPTalkReplyTest >> testOpaqueValuesCannotBecomeProviderTextOrSummaries [
 | request |
 request := (SmallGPTalkRequest text: 'Continue' history: #() agent: nil)
  following: { Object new }.
 self should: [ SmallGPTalkOpenAIRequest new encode: request model: 'fixture' effort: 'low' ]
  raise: Error withExceptionDo: [ :error |
   self assert: error messageText equals: 'The provider requires a text reply.' ].
 self should: [ SmallGPTalkContext new absorb: Object new through: 0 ]
  raise: Error withExceptionDo: [ :error |
   self assert: error messageText equals: 'A summary must contain text.' ]
]
