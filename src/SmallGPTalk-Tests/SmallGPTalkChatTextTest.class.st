Class {
	#name : 'SmallGPTalkChatTextTest',
	#superclass : 'TestCase',
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkChatTextTest >> testCodeBlock [
	| text |
	text := SmallGPTalkChatText new render: '```smalltalk
| numero |
numero := 6.
numero factorial. "720"
```'.
	self deny: (text asString includesSubstring: '```').
	self assert: (text asString includesSubstring: 'numero factorial. "720"').
	self assert: ((text attributesAt: 5) anySatisfy: [ :each | each isKindOf: TextFontReference ])
]

{ #category : 'tests' }
SmallGPTalkChatTextTest >> testInlineCodeAndBold [
	| text |
	text := SmallGPTalkChatText new render: '**Result:** `6 factorial` gives `720`.'.
	self assert: text asString equals: 'Result: 6 factorial gives 720.'.
	self assert: ((text attributesAt: 1) includes: TextEmphasis bold).
	self assert: ((text attributesAt: 9) anySatisfy: [ :each | each isKindOf: TextFontReference ])
]

{ #category : 'tests' }
SmallGPTalkChatTextTest >> testCodePreservesLiteralMarkupAndEscapes [
	| text |
	text := SmallGPTalkChatText new render: '```smalltalk
''**literal** `literal` \"literal\"''
```'.
	self assert: (text asString includesSubstring: '''**literal** `literal` \"literal\"''')
]

{ #category : 'tests' }
SmallGPTalkChatTextTest >> testFragmentsRenderLikeCompleteResponse [
	| chat source expected |
	chat := SmallGPTalkChat new.
	chat appendHeading: 'SmallGPTalk'.
	source := 'Example:
```smalltalk
6 factorial
```
Result: `720`.'.
	expected := (chat instVarNamed: 'history') text asString,
		(SmallGPTalkChatText new render: source) asString.
	source do: [ :character |
		chat receiveEvent: (Dictionary new at: #type put: #text; at: #text put: character asString; yourself) ].
	self assert: (chat instVarNamed: 'history') text asString equals: expected
]

{ #category : 'tests' }
SmallGPTalkChatTextTest >> testUnclosedCodeBlock [
	| text |
	text := SmallGPTalkChatText new render: '```smalltalk
6 factorial'.
	self assert: text asString equals: '    6 factorial'
]

{ #category : 'tests' }
SmallGPTalkChatTextTest >> testCodeFenceDoesNotHideLiteralText [
	| text |
	text := SmallGPTalkChatText new render: '```smalltalk
''first
```literal
last''
```'.
	self assert: (text asString includesSubstring: '    ```literal').
	self assert: (text asString includesSubstring: '    last''')
]

{ #category : 'tests' }
SmallGPTalkChatTextTest >> testLongFencePreservesShortFenceInsideCode [
	| text |
	text := SmallGPTalkChatText new render: '````smalltalk
''first
```
last''
````'.
	self assert: (text asString includesSubstring: '    ```').
	self assert: (text asString includesSubstring: '    last''').
	self deny: (text asString includesSubstring: '````')
]

{ #category : 'tests' }
SmallGPTalkChatTextTest >> testLongClosingFenceReturnsToText [
	| text |
	text := SmallGPTalkChatText new render: '```smalltalk
6 factorial
````
**Result:** 720'.
	self assert: (text asString includesSubstring: 'Result: 720').
	self deny: (text asString includesSubstring: '```')
]

{ #category : 'tests' }
SmallGPTalkChatTextTest >> testInlineCodePreservesInnerBackticks [
	| text |
	text := SmallGPTalkChatText new render: 'Use ``a ` b``.'.
	self assert: text asString equals: 'Use a ` b.'.
	self assert: ((text attributesAt: 7) anySatisfy: [ :each | each isKindOf: TextFontReference ])
]

{ #category : 'tests' }
SmallGPTalkChatTextTest >> testUnmatchedBackticksStayVisible [
	self assert: (SmallGPTalkChatText new render: 'Use ``unfinished ` code') asString
		equals: 'Use ``unfinished ` code'
]
