Class {
 #name : 'SmallGPTalkTurnTest',
 #superclass : 'TestCase',
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'model protocol' }
SmallGPTalkTurnTest >> respondTo: request [
 ^ request calls ifEmpty: [ SmallGPTalkReply text: '' calls: {
  SmallGPTalkCall id: 'once' name: 'evaluate' arguments:
   (Dictionary new at: 'source' put: '6 factorial'; yourself) } ]
  ifNotEmpty: [ 'Done.' ]
]

{ #category : 'tests' }
SmallGPTalkTurnTest >> testTurnExecutesWithoutASessionAndLeavesItsRecords [
 | exchange run turn |
 exchange := SmallGPTalkExchange request: (SmallGPTalkRequest text: 'Compute' history: #() agent: nil).
 run := SmallGPTalkRun on: exchange.
 turn := SmallGPTalkTurn for: run model: self tools: { SmallGPTalkEvaluate new }
  limit: 3 requestLimit: (SmallGPTalkTimeLimit seconds: 1) contextPolicy: SmallGPTalkContext new.
 run start: [ turn execute ] whenFinished: [ ].
 [
  run wait.
  self assert: run state equals: #completed.
  self assert: run result equals: 'Done.'.
  self assert: exchange replies size equals: 2.
  self assert: exchange calls first result equals: 720.
  self assert: exchange calls first state equals: #completed.
  self assert: exchange replies first context identicalTo: exchange context
 ] ensure: [ run cancel; wait ]
]

{ #category : 'tests' }
SmallGPTalkTurnTest >> testRecordingValidatesTheWholeReplyWithoutExecutingCalls [
 | exchange call valid invalid changes seen |
 exchange := SmallGPTalkExchange request: (SmallGPTalkRequest text: 'Compute' history: #() agent: nil).
 call := SmallGPTalkCall id: 'one' name: 'evaluate' arguments:
  (Dictionary new at: 'source' put: '6 factorial'; yourself).
 invalid := SmallGPTalkReply text: '' calls: { call. Object new }.
 seen := OrderedCollection new.
 changes := SmallGPTalkObservers new.
 changes add: [ :record | seen add: record replies size ].
 exchange reportTo: changes; begin.
 self should: [ exchange recordReply: invalid for: exchange context ] raise: Error.
 self assert: exchange replies isEmpty.
 self assert: seen isEmpty.
 valid := SmallGPTalkReply text: '' calls: { call }.
 exchange recordReply: valid for: exchange context.
 self assert: exchange replies first identicalTo: valid.
 self assert: valid context identicalTo: exchange context.
 self assert: call state equals: #pending.
 self assert: call operation isNil.
 self assert: seen asArray equals: #(1).
 self should: [ exchange recordReply: valid for: exchange context ] raise: Error.
 self assert: exchange replies size equals: 1
]
