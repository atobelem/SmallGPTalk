"A complete model reply can request tool calls."
Class {
 #name : 'SmallGPTalkReply',
 #superclass : 'Object',
 #instVars : [ 'text', 'calls', 'providerData', 'context', 'usage' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'instance creation' }
SmallGPTalkReply class >> text: aString calls: aCollection [
 ^ self new prepareText: aString calls: aCollection; yourself
]

{ #category : 'initialization' }
SmallGPTalkReply >> prepareText: aString calls: aCollection [
 text := aString copy.
 calls := aCollection asArray copy
]

{ #category : 'accessing' }
SmallGPTalkReply >> text [ ^ text copy ]

{ #category : 'accessing' }
SmallGPTalkReply >> usage [ ^ usage ]

{ #category : 'initialization' }
SmallGPTalkReply >> usage: measurement [ usage := measurement ]

{ #category : 'accessing' }
SmallGPTalkReply >> calls [ ^ calls copy ]

{ #category : 'accessing' }
SmallGPTalkReply >> context [ ^ context ]

{ #category : 'initialization' }
SmallGPTalkReply >> context: request [ context := request ]

{ #category : 'validation' }
SmallGPTalkReply >> validateWithUsedIds: identifiers [
 text isString ifFalse: [ self error: 'A reply must contain text.' ].
 calls do: [ :call |
  (call isKindOf: SmallGPTalkCall) ifFalse: [ self error: 'The reply contains an invalid tool call.' ].
  call validate.
  (identifiers includes: call id) ifTrue: [ self error: 'Tool call identifiers must not repeat.' ].
  identifiers add: call id ]
]

{ #category : 'copying' }
SmallGPTalkReply >> postCopy [
 super postCopy.
 text := text copy.
 calls := calls collect: #copy.
 providerData := providerData deepCopy
]

{ #category : 'measurement' }
SmallGPTalkReply >> characterCount [
 ^ text size + (calls inject: 0 into: [ :total :call | total + call characterCount ])
]

{ #category : 'accessing' }
SmallGPTalkReply >> providerData [ ^ providerData deepCopy ]

{ #category : 'initialization' }
SmallGPTalkReply >> providerData: data [ providerData := data deepCopy ]
