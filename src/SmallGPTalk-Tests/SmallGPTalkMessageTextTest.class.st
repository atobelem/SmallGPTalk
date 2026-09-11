Class {
 #name : 'SmallGPTalkMessageTextTest',
 #superclass : 'TestCase',
 #instVars : [ 'requests' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkMessageTextTest >> testCodeAndEmphasisAreRenderedWithoutMarkdownDelimiters [
 | text index |
 text := (Smalltalk globals at: #SmallGPTalkMessageText) from:
  'Here is **code**:', String lf, '```smalltalk', String lf, '6 factorial.', String lf, '```'.
 self assert: text isText.
 self assert: (text asString includesSubstring: '6 factorial.').
 self deny: (text asString includesSubstring: '```').
 self deny: (text asString includesSubstring: '**').
 index := text asString findString: '6 factorial.'.
 self assert: ((text attributesAt: index) anySatisfy: [ :attribute | attribute isKindOf: TextFontReference ])
]

{ #category : 'tests' }
SmallGPTalkMessageTextTest >> testScriptMarkupIsDisplayedWithoutExecution [
 | text |
 [
  text := (Smalltalk globals at: #SmallGPTalkMessageText) from:
   '<!script', String lf, 'Smalltalk globals at: #SmallGPTalkRenderProbe put: true.', String lf, '!>'.
  self deny: (Smalltalk globals includesKey: #SmallGPTalkRenderProbe).
  self assert: (text asString includesSubstring: 'SmallGPTalkRenderProbe')
 ] ensure: [ Smalltalk globals removeKey: #SmallGPTalkRenderProbe ifAbsent: [ ] ]
]

{ #category : 'server protocol' }
SmallGPTalkMessageTextTest >> handleRequest: request [
 requests := requests + 1.
 ^ ZnResponse ok: (ZnEntity text: 'Unexpected resource request')
]

{ #category : 'tests' }
SmallGPTalkMessageTextTest >> testImageMarkupShowsItsLabelWithoutFetchingTheResource [
 | server text |
 requests := 0.
 server := ZnServer startOn: 20000 + 20000 atRandom.
 server delegate: self.
 [
  text := SmallGPTalkMessageText from: '![A picture](http://127.0.0.1:', server port asString, '/image)'.
  self assert: (text asString includesSubstring: 'A picture').
  self assert: requests equals: 0
 ] ensure: [ server stop ]
]

{ #category : 'model protocol' }
SmallGPTalkMessageTextTest >> respondTo: request [
 requests := requests + 1.
 requests = 4 ifTrue: [ ^ SmallGPTalkReply text: 'Fibonacci example.' calls: #() ].
 ^ SmallGPTalkReply text: (requests = 2 ifTrue: [ '  ', String lf ] ifFalse: [ '' ])
  calls: { SmallGPTalkCall id: requests asString name: 'evaluate' arguments:
   (Dictionary new at: 'source' put: '6 factorial'; yourself) }
]

{ #category : 'tests' }
SmallGPTalkMessageTextTest >> testToolOnlyRepliesShowEvaluationsInOrder [
 | session run text first second third assistant snapshots |
 requests := 0.
 session := SmallGPTalkSession withModel: self.
 session tools: { SmallGPTalkEvaluate new }.
 snapshots := OrderedCollection new.
 session whenChanged: [ :exchange | snapshots add: (SmallGPTalkMessageText forExchange: exchange) asString ].
 run := session send: 'Make Fibonacci'. run wait.
 self assert: run state equals: #completed.
 text := SmallGPTalkMessageText forExchange: run exchange.
 first := text asString findString: 'evaluate #1 — completed'.
 second := text asString findString: 'evaluate #2 — completed'.
 third := text asString findString: 'evaluate #3 — completed'.
 assistant := text asString findString: 'Assistant'.
 self assert: first > 0.
 self assert: second > first.
 self assert: third > second.
 self assert: assistant > third.
 self assert: (text asString findString: 'Assistant' startingAt: assistant + 1) equals: 0.
 self assert: (text asString includesSubstring: '6 factorial').
 self assert: (text asString includesSubstring: '720').
 self assert: (text asString includesSubstring: 'Fibonacci example.').
 self assert: (snapshots anySatisfy: [ :snapshot | snapshot includesSubstring: 'evaluate #1 — running' ]).
 self assert: run exchange replies size equals: 4.
 self assert: run exchange calls size equals: 3.
 self assert: (run exchange calls allSatisfy: [ :call | call state = #completed ])
]


{ #category : 'tests' }
SmallGPTalkMessageTextTest >> testPendingCancelledAndFailedCallsRemainVisible [
 | call text |
 call := SmallGPTalkCall id: 'pending' name: 'evaluate' arguments:
  (Dictionary new at: 'source' put: '6 factorial'; yourself).
 text := SmallGPTalkMessageText forCall: call.
 self assert: (text asString includesSubstring: 'pending').
 self assert: (text asString includesSubstring: '6 factorial').
 call cancelIfPending.
 self assert: ((SmallGPTalkMessageText forCall: call) asString includesSubstring: 'cancelled').
 call := SmallGPTalkCall id: 'failed' name: 'missing' arguments: Dictionary new.
 call executeWith: #().
 text := SmallGPTalkMessageText forCall: call.
 self assert: (text asString includesSubstring: 'failed').
 self assert: (text asString includesSubstring: call error)
]
