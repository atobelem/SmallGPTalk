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
