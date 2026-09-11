"Convert a complete provider response without executing its tool calls."
Class {
 #name : 'SmallGPTalkOpenAIResponse',
 #superclass : 'Object',
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'decoding' }
SmallGPTalkOpenAIResponse >> decode: response [
 | output text calls reply |
 (response isKindOf: Dictionary) ifFalse: [ self error: 'The response must be an object.' ].
 (response at: 'status' ifAbsent: [ nil ]) = 'completed'
  ifFalse: [ self error: 'The model response did not complete.' ].
 output := response at: 'output' ifAbsent: [ nil ].
 output isArray ifFalse: [ self error: 'The response output must be an array.' ].
 text := String new writeStream.
 calls := OrderedCollection new.
 output do: [ :item |
  | type |
  (item isKindOf: Dictionary) ifFalse: [ self error: 'An output item must be an object.' ].
  (item at: 'status' ifAbsent: [ 'completed' ]) = 'completed'
   ifFalse: [ self error: 'An output item did not complete.' ].
  type := self stringAt: 'type' in: item.
  type = 'message' ifTrue: [ self appendMessage: item to: text ].
  type = 'function_call' ifTrue: [ calls add: (self callFrom: item) ] ].
 reply := SmallGPTalkReply text: text contents calls: calls.
 reply validateWithUsedIds: Set new.
 ^ reply providerData: response; yourself
]

{ #category : 'private' }
SmallGPTalkOpenAIResponse >> appendMessage: item to: stream [
 | content |
 content := item at: 'content' ifAbsent: [ nil ].
 content isArray ifFalse: [ self error: 'Message content must be an array.' ].
 content do: [ :part |
  | type |
  type := self stringAt: 'type' in: part.
  type = 'output_text' ifTrue: [ stream nextPutAll: (self stringAt: 'text' in: part) ].
  type = 'refusal' ifTrue: [ stream nextPutAll: (self stringAt: 'refusal' in: part) ] ]
]

{ #category : 'private' }
SmallGPTalkOpenAIResponse >> callFrom: item [
 | raw arguments |
 raw := self stringAt: 'arguments' in: item.
 arguments := [ STONJSON fromString: raw ] on: Error do: [ :error | raw ].
 ^ SmallGPTalkCall id: (self stringAt: 'call_id' in: item)
  name: (self stringAt: 'name' in: item) arguments: arguments
]

{ #category : 'private' }
SmallGPTalkOpenAIResponse >> stringAt: key in: object [
 | value |
 (object isKindOf: Dictionary) ifFalse: [ self error: 'The response field must be an object.' ].
 value := object at: key ifAbsent: [ nil ].
 value isString ifFalse: [ self error: 'The response field ', key, ' must be text.' ].
 ^ value
]
