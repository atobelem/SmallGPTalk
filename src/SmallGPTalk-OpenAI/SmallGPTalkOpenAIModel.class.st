"Compose request encoding, account authorization, and response transport."
Class {
 #name : 'SmallGPTalkOpenAIModel',
 #superclass : 'Object',
 #instVars : [ 'model', 'effort', 'account', 'transport', 'contextWindow' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'instance creation' }
SmallGPTalkOpenAIModel class >> model: identifier effort: level account: connection transport: http [
 ^ self new model: identifier effort: level account: connection transport: http; yourself
]

{ #category : 'initialization' }
SmallGPTalkOpenAIModel >> model: identifier effort: level account: connection transport: http [
 model := identifier copy.
 effort := level copy.
 account := connection.
 transport := http
]

{ #category : 'model protocol' }
SmallGPTalkOpenAIModel >> respondTo: request [
 | body reply |
 body := SmallGPTalkOpenAIRequest new encode: request model: model effort: effort.
 reply := account withHeadersDo: [ :headers |
  (transport respondsTo: #post:headers:onText:)
   ifTrue: [ transport post: body headers: headers onText: [ :text | request receiveText: text ] ]
   ifFalse: [ transport post: body headers: headers ] ].
 self recordUsageFor: reply.
 ^ reply
]

{ #category : 'private' }
SmallGPTalkOpenAIModel >> recordUsageFor: reply [
 | data count |
 contextWindow ifNil: [ ^ self ].
 (reply isKindOf: SmallGPTalkReply) ifFalse: [ ^ self ].
 reply providerData ifNil: [ ^ self ].
 data := reply providerData at: 'usage' ifAbsent: [ ^ self ].
 data isDictionary ifFalse: [ ^ self ].
 count := data at: 'input_tokens' ifAbsent: [ ^ self ].
 (count isInteger and: [ count >= 0 ]) ifFalse: [ ^ self ].
 reply usage: (SmallGPTalkContextUsage inputTokens: count capacity: contextWindow)
]

{ #category : 'accessing' }
SmallGPTalkOpenAIModel >> contextWindow [ ^ contextWindow ]

{ #category : 'configuration' }
SmallGPTalkOpenAIModel >> contextWindow: count [
 (count isNil or: [ count isInteger and: [ count > 0 ] ])
  ifFalse: [ self error: 'The model context window is invalid.' ].
 contextWindow := count
]

{ #category : 'accessing' }
SmallGPTalkOpenAIModel >> identifier [ ^ model copy ]

{ #category : 'accessing' }
SmallGPTalkOpenAIModel >> effort [ ^ effort copy ]
