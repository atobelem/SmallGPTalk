Class {
 #name : 'SmallGPTalkOpenAIStreamTest',
 #superclass : 'TestCase',
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'fixtures' }
SmallGPTalkOpenAIStreamTest >> completedEvent [
 ^ '{"type":"response.completed","response":{"status":"completed","output":[{"type":"function_call","call_id":"c1","name":"evaluate","arguments":"{\"source\":\"6 factorial\"}"}]}}'
]

{ #category : 'fixtures' }
SmallGPTalkOpenAIStreamTest >> frame: json [
 ^ 'data: ', json, String lf, String lf
]

{ #category : 'tests' }
SmallGPTalkOpenAIStreamTest >> testFragmentedArgumentsWaitForACompleteResponse [
 | stream wire reply |
 stream := SmallGPTalkOpenAIStream new.
 wire := (self frame: '{"type":"response.function_call_arguments.delta","output_index":0,"delta":"{\"source\":"}'),
  (self frame: '{"type":"response.function_call_arguments.delta","output_index":0,"delta":"\"6 factorial\"}"}').
 wire do: [ :character | stream consume: character asString ].
 self should: [ stream finish ] raise: Error.
 (self frame: self completedEvent) do: [ :character | stream consume: character asString ].
 reply := stream finish.
 self assert: reply calls first state equals: #pending.
 self assert: (reply calls first arguments at: 'source') equals: '6 factorial'
]

{ #category : 'tests - text' }
SmallGPTalkOpenAIStreamTest >> testTextFragmentsAreAvailableWithoutCompletingTheResponse [
 | stream seen wire |
 stream := SmallGPTalkOpenAIStream new.
 seen := OrderedCollection new.
 stream whenText: [ :text | seen add: text ].
 wire := self frame: '{"type":"response.output_text.delta","delta":"Hello"}'.
 wire do: [ :character | stream consume: character asString ].
 self assert: seen asArray equals: #('Hello').
 self deny: stream isComplete.
 self should: [ stream finish ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkOpenAIStreamTest >> testConflictingArgumentsCannotProduceAReply [
 | stream |
 stream := SmallGPTalkOpenAIStream new.
 stream consume: (self frame: '{"type":"response.function_call_arguments.delta","output_index":0,"delta":"{}"}').
 self should: [ stream consume: (self frame: self completedEvent) ] raise: Error.
 self should: [ stream finish ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkOpenAIStreamTest >> testCRLFCommentsAndMultipleDataLines [
 | stream wire |
 stream := SmallGPTalkOpenAIStream new.
 wire := ': heartbeat', String crlf, 'event: response.done', String crlf,
  'data: {"type":"response.done",', String crlf,
  'data: "response":{"status":"completed","output":[]}}', String crlf, String crlf.
 wire do: [ :character | stream consume: character asString ].
 self assert: stream finish calls isEmpty.
 self assert: stream finish text isEmpty
]

{ #category : 'tests' }
SmallGPTalkOpenAIStreamTest >> testIncompleteAndBrokenStreamsFail [
 | stream |
 stream := SmallGPTalkOpenAIStream new.
 stream consume: (self frame: '{"type":"response.output_text.delta","delta":"Partial"}').
 self should: [ stream finish ] raise: Error.
 self should: [ stream consume: (self frame: '{"type":"response.incomplete"}') ] raise: Error.
 self should: [ stream finish ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkOpenAIStreamTest >> testCompletedItemsCanSupplyTheTerminalOutput [
 | stream |
 stream := SmallGPTalkOpenAIStream new.
 stream consume: (self frame: '{"type":"response.output_item.done","output_index":0,"item":{"type":"message","status":"completed","content":[{"type":"output_text","text":"Hello"}]}}').
 self should: [ stream finish ] raise: Error.
 stream consume: (self frame: '{"type":"response.done","response":{"status":"completed","output":[]}}').
 self assert: stream finish text equals: 'Hello'.
 self assert: (stream finish providerData at: 'output') size equals: 1
]

{ #category : 'tests' }
SmallGPTalkOpenAIStreamTest >> testAnAddedItemCannotDisappearAtCompletion [
 | stream |
 stream := SmallGPTalkOpenAIStream new.
 stream consume: (self frame: '{"type":"response.output_item.added","output_index":0,"item":{"type":"function_call","id":"f1"}}').
 self should: [ stream consume: (self frame: '{"type":"response.done","response":{"status":"completed","output":[]}}') ] raise: Error
]
