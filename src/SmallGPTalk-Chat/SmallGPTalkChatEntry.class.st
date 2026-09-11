"A display entry keeps its object and source. A draft is not committed history."
Class {
	#name : 'SmallGPTalkChatEntry',
	#superclass : 'Object',
	#instVars : [ 'object', 'title', 'source', 'markdown', 'start', 'stop' ],
	#category : 'SmallGPTalk-Chat',
	#package : 'SmallGPTalk-Chat'
}

{ #category : 'initialization' }
SmallGPTalkChatEntry >> initialize [
	super initialize.
	title := ''. source := ''. markdown := false.
	start := 1. stop := 0
]

{ #category : 'accessing' }
SmallGPTalkChatEntry >> object [ ^ object ]

{ #category : 'accessing' }
SmallGPTalkChatEntry >> object: anObject [ object := anObject ]

{ #category : 'accessing' }
SmallGPTalkChatEntry >> title: aString [ title := aString ]

{ #category : 'accessing' }
SmallGPTalkChatEntry >> source [ ^ source ]

{ #category : 'accessing' }
SmallGPTalkChatEntry >> source: aString [ source := aString ]

{ #category : 'accessing' }
SmallGPTalkChatEntry >> markdown: aBoolean [ markdown := aBoolean ]

{ #category : 'accessing' }
SmallGPTalkChatEntry >> rangeFrom: first to: last [ start := first. stop := last ]

{ #category : 'testing' }
SmallGPTalkChatEntry >> includesPosition: index [ ^ index between: start and: stop ]

{ #category : 'rendering' }
SmallGPTalkChatEntry >> rendered [
	| text |
	text := title asText addAttribute: TextEmphasis bold; yourself.
	title ifNotEmpty: [ text append: String cr ].
	text append: (markdown
		ifTrue: [ SmallGPTalkChatText new render: source ]
		ifFalse: [ source asText ]).
	^ text
]
