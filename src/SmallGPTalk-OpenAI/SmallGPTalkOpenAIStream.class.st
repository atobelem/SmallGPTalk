"Read text event frames and commit only a validated terminal response."
Class {
 #name : 'SmallGPTalkOpenAIStream',
 #superclass : 'Object',
 #instVars : [ 'line', 'data', 'afterCR', 'arguments', 'reply', 'failure', 'items', 'added', 'textObserver' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'initialization' }
SmallGPTalkOpenAIStream >> initialize [
 super initialize.
 line := String new writeStream.
 data := OrderedCollection new.
 arguments := Dictionary new.
 items := Dictionary new.
 added := Dictionary new.
 afterCR := false
]

{ #category : 'reading' }
SmallGPTalkOpenAIStream >> consume: text [
 failure ifNotNil: [ self error: failure ].
 [ text do: [ :character | self acceptCharacter: character ] ]
  on: Error do: [ :error |
   reply := nil.
   failure := error messageText copy.
   error pass ]
]

{ #category : 'private - framing' }
SmallGPTalkOpenAIStream >> acceptCharacter: character [
 | skip |
 skip := afterCR and: [ character = Character lf ].
 afterCR := character = Character cr.
 skip ifTrue: [ ^ self ].
 (character = Character cr or: [ character = Character lf ])
  ifTrue: [ self acceptLine: line contents. line := String new writeStream ]
  ifFalse: [ line nextPut: character ]
]

{ #category : 'private - framing' }
SmallGPTalkOpenAIStream >> acceptLine: text [
 | value |
 text isEmpty ifTrue: [ ^ self dispatch ].
 text = 'data' ifTrue: [ data add: ''. ^ self ].
 (text beginsWith: 'data:') ifFalse: [ ^ self ].
 value := text allButFirst: 5.
 (value notEmpty and: [ value first = Character space ]) ifTrue: [ value := value allButFirst ].
 data add: value
]

{ #category : 'private - framing' }
SmallGPTalkOpenAIStream >> dispatch [
 | json event |
 data ifEmpty: [ ^ self ].
 json := String lf join: data.
 data removeAll.
 json = '[DONE]' ifTrue: [ ^ self ].
 reply ifNotNil: [ ^ self ].
 event := [ STONJSON fromString: json ] on: Error do: [ :error |
  self error: 'The model event contains invalid JSON.' ].
 (event isKindOf: Dictionary) ifFalse: [ self error: 'The model event must be an object.' ].
 self acceptEvent: event
]

{ #category : 'private - events' }
SmallGPTalkOpenAIStream >> acceptEvent: event [
 | type index fragment |
 type := event at: 'type' ifAbsent: [ '' ].
 (#('response.output_text.delta' 'response.refusal.delta') includes: type) ifTrue: [
  fragment := event at: 'delta'.
  fragment isString ifFalse: [ self error: 'The text fragment must be text.' ].
  textObserver ifNotNil: [ textObserver value: fragment ] ].
 (#('error' 'response.failed' 'response.cancelled' 'response.incomplete') includes: type)
  ifTrue: [ self error: 'The model stream did not complete.' ].
 (#('response.output_item.added' 'response.output_item.done') includes: type) ifTrue: [
  index := event at: 'output_index'.
  (index isInteger and: [ index >= 0 ]) ifFalse: [ self error: 'The output index is invalid.' ].
  type = 'response.output_item.added'
   ifTrue: [ added at: index put: (event at: 'item') ]
   ifFalse: [ items at: index put: (event at: 'item') ] ].
 type = 'response.function_call_arguments.delta' ifTrue: [
  index := event at: 'output_index'.
  (index isInteger and: [ index >= 0 ]) ifFalse: [ self error: 'The output index is invalid.' ].
  fragment := event at: 'delta'.
  fragment isString ifFalse: [ self error: 'The argument fragment must be text.' ].
  (arguments at: index ifAbsentPut: [ String new writeStream ]) nextPutAll: fragment ].
 (#('response.completed' 'response.done') includes: type) ifTrue: [
  self complete: (event at: 'response') ]
]

{ #category : 'private - events' }
SmallGPTalkOpenAIStream >> complete: response [
 | candidate output complete |
 complete := self completedResponse: response.
 candidate := SmallGPTalkOpenAIResponse new decode: complete.
 output := complete at: 'output'.
 arguments keysAndValuesDo: [ :index :fragments |
  | item |
  index >= output size ifTrue: [ self error: 'A tool fragment has no completed output.' ].
  item := output at: index + 1.
  ((item at: 'type') = 'function_call' and: [ (item at: 'arguments') = fragments contents ])
   ifFalse: [ self error: 'The completed arguments do not match their fragments.' ] ].
 reply := candidate
]

{ #category : 'reading' }
SmallGPTalkOpenAIStream >> finish [
 failure ifNotNil: [ self error: failure ].
 ^ reply ifNil: [ self error: 'The stream ended before a complete response.' ]
]

{ #category : 'reading' }
SmallGPTalkOpenAIStream >> readFrom: stream [
 [ stream atEnd or: [ reply notNil ] ] whileFalse: [ self consume: stream next asString ].
 ^ self finish
]

{ #category : 'private - events' }
SmallGPTalkOpenAIStream >> completedResponse: response [
 | output result |
 output := response at: 'output' ifAbsent: [ #() ].
 output isArray ifFalse: [ self error: 'The response output must be an array.' ].
 output ifEmpty: [
  output := (0 to: items size - 1) collect: [ :index |
   items at: index ifAbsent: [ self error: 'The completed output has a missing item.' ] ] ].
 added keysAndValuesDo: [ :index :item |
  | final |
  index >= output size ifTrue: [ self error: 'An added item has no completed output.' ].
  final := output at: index + 1.
  (item at: 'id' ifAbsent: [ nil ]) = (final at: 'id' ifAbsent: [ nil ])
   ifFalse: [ self error: 'The output item identifier changed.' ] ].
 items keysAndValuesDo: [ :index :item |
  (index >= output size or: [ (output at: index + 1) ~= item ])
   ifTrue: [ self error: 'The completed output items do not match.' ] ].
 result := response copy.
 result at: 'output' put: output asArray.
 ^ result
]

{ #category : 'testing' }
SmallGPTalkOpenAIStream >> isComplete [ ^ reply notNil and: [ failure isNil ] ]

{ #category : 'streaming' }
SmallGPTalkOpenAIStream >> whenText: observer [ textObserver := observer ]
