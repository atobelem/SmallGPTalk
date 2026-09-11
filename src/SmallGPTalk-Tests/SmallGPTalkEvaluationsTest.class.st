Class {
 #name : 'SmallGPTalkEvaluationsTest',
 #superclass : 'TestCase',
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'model protocol' }
SmallGPTalkEvaluationsTest >> respondTo: request [
 ^ request calls ifEmpty: [ SmallGPTalkReply text: '' calls: {
  SmallGPTalkCall id: 'one' name: 'evaluate' arguments:
   (Dictionary new at: 'source' put: '6 factorial'; yourself) } ]
  ifNotEmpty: [ 'Done.' ]
]

{ #category : 'tests' }
SmallGPTalkEvaluationsTest >> testViewKeepsTheCallAndShowsItsSourceOutputAndContext [
 | session run view |
 session := SmallGPTalkSession withModel: self.
 session tools: { SmallGPTalkEvaluate new }.
 run := session send: 'Compute'. run wait.
 view := (Smalltalk globals at: #SmallGPTalkEvaluations) forExchange: run exchange.
 self assert: view selectedCall identicalTo: run exchange calls first.
 self assert: view sourceText equals: '6 factorial'.
 self assert: (view outputText includesSubstring: '720').
 self assert: view selectedContext identicalTo: (run exchange contextForCall: view selectedCall).
 self assert: view selectedCall result equals: 720
]
