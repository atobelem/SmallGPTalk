Class {
	#name : #SmallGPTalkProviderStreamTest,
	#superclass : #TestCase,
	#instVars : [ 'cancellationChecks', 'cancelAfter' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : #'helpers' }
SmallGPTalkProviderStreamTest >> checkCancellation [
	cancellationChecks := (cancellationChecks ifNil: [ 0 ]) + 1.
	(cancelAfter notNil and: [ cancellationChecks >= cancelAfter ]) ifTrue: [
		SmallGPTalkCancelled signal: 'The run was cancelled.' ]
]

{ #category : #'helpers' }
SmallGPTalkProviderStreamTest >> completedText [
	^ '{"type":"response.completed","response":{"status":"completed","output":[{"type":"message","id":"msg_1","role":"assistant","status":"completed","content":[{"type":"output_text","text":"Hello","annotations":[]}]}]}}'
]

{ #category : #'helpers' }
SmallGPTalkProviderStreamTest >> event: aString [
	^ 'data: ', aString, String lf, String lf
]

{ #category : #'helpers' }
SmallGPTalkProviderStreamTest >> completedToolArguments: aString [
	^ STONJSON toString: (Dictionary new
		at: 'type' put: 'response.completed';
		at: 'response' put: (Dictionary new
			at: 'status' put: 'completed';
			at: 'output' put: { Dictionary new
				at: 'type' put: 'function_call';
				at: 'id' put: 'fc_1';
				at: 'call_id' put: 'call_1';
				at: 'name' put: 'read';
				at: 'arguments' put: aString;
				yourself };
			yourself);
		yourself)
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testTextDeltasAndCompletedMessage [
	| parser deltas message |
	deltas := OrderedCollection new.
	parser := SmallGPTalkOpenAIStream new onText: [ :text | deltas add: text ]; yourself.
	parser consume: (self event: '{"type":"response.output_text.delta","delta":"Hel"}').
	parser consume: (self event: '{"type":"response.output_text.delta","delta":"lo"}').
	self should: [ parser finish ] raise: Error.
	parser consume: (self event: self completedText).
	message := parser finish.
	self assert: deltas asArray equals: #('Hel' 'lo').
	self assert: message role equals: #assistant.
	self assert: message text equals: 'Hello'.
	self assert: message toolCalls isEmpty
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testEveryCharacterCanBeAChunk [
	| parser text |
	parser := SmallGPTalkOpenAIStream new.
	text := self event: self completedText.
	text do: [ :character | parser consume: character asString ].
	self assert: parser finish text equals: 'Hello'
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testLineEndingsAcrossChunks [
	{ String lf. String cr. String crlf } do: [ :ending |
		| parser data |
		parser := SmallGPTalkOpenAIStream new.
		data := 'data: ', self completedText, ending, ending.
		data do: [ :character | parser consume: character asString ].
		self assert: parser finish text equals: 'Hello' ]
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testMultipleDataLinesAndComments [
	| parser text |
	parser := SmallGPTalkOpenAIStream new.
	text := ': keep alive', String lf,
		'event: response.completed', String lf,
		'data: {"type":"response.completed",', String lf,
		'data: "response":{"status":"completed","output":[]}}', String lf, String lf.
	parser consume: text.
	self assert: parser finish text equals: ''
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testFragmentedToolArguments [
	| parser message |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self event: '{"type":"response.output_item.added","output_index":0,"item":{"type":"function_call","id":"fc_1","call_id":"call_1","name":"read","arguments":""}}').
	parser consume: (self event: '{"type":"response.function_call_arguments.delta","item_id":"fc_1","delta":"{\"class\":"}').
	parser consume: (self event: '{"type":"response.function_call_arguments.delta","output_index":0,"delta":"\"Object\"}"}').
	self should: [ parser finish ] raise: Error.
	parser consume: (self event: (self completedToolArguments: '{"class":"Object"}')).
	message := parser finish.
	self assert: message toolCalls size equals: 1.
	self assert: message toolCalls first id equals: 'call_1'.
	self assert: message toolCalls first name equals: 'read'.
	self assert: (message toolCalls first arguments at: 'class') equals: 'Object'
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testInvalidToolJsonIsRecoverable [
	| parser call |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self event: (self completedToolArguments: '{"class":')).
	call := parser finish toolCalls first.
	self assert: call argumentError equals: 'The tool arguments have invalid JSON.'.
	self assert: call arguments isEmpty
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testToolArgumentsMustBeAnObject [
	| parser |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self event: (self completedToolArguments: '[1,2]')).
	self assert: parser finish toolCalls first argumentError
		equals: 'The tool arguments must be a JSON object.'
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testReasoningAndMessageMetadataArePreserved [
	| parser output |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self event: '{"type":"response.completed","response":{"status":"completed","output":[{"type":"reasoning","id":"rs_1","encrypted_content":"opaque-test-data","summary":[]},{"type":"message","id":"msg_1","phase":"final_answer","content":[{"type":"output_text","text":"Done"}]}]}}').
	output := parser finish providerItems.
	self assert: output size equals: 2.
	self assert: (output first at: 'encrypted_content') equals: 'opaque-test-data'.
	self assert: (output second at: 'phase') equals: 'final_answer'.
	self assert: parser finish text equals: 'Done'
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testDoneEventRequiresCompletedStatus [
	| parser |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self event: '{"type":"response.done","response":{"status":"completed","output":[]}}').
	self assert: parser finish text equals: ''.
	#('in_progress' 'failed' 'incomplete' 'cancelled') do: [ :status |
		self should: [ SmallGPTalkOpenAIStream new consume:
			(self event: '{"type":"response.done","response":{"status":"', status, '","output":[]}}') ]
			raise: Error ]
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testFailureAndIncompleteEventsAreRejected [
	#('response.failed' 'response.incomplete' 'response.cancelled' 'error') do: [ :type |
		self should: [ SmallGPTalkOpenAIStream new consume:
			(self event: '{"type":"', type, '"}') ] raise: Error ]
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testDoneMarkerDoesNotCompleteAResponse [
	| parser |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self event: '[DONE]').
	self should: [ parser finish ] raise: Error
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testTruncatedEventDoesNotCompleteAResponse [
	| parser |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: 'data: ', self completedText, String lf.
	self should: [ parser finish ] raise: Error
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testMalformedEventIsRejected [
	self should: [ SmallGPTalkOpenAIStream new consume: (self event: '{broken') ] raise: Error.
	self should: [ SmallGPTalkOpenAIStream new consume: (self event: '[]') ] raise: Error
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testMismatchedFinalArgumentsAreRejected [
	| parser |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self event: '{"type":"response.function_call_arguments.delta","output_index":0,"delta":"{}"}').
	self should: [ parser consume: (self event: (self completedToolArguments: '{"class":"Object"}')) ]
		raise: Error
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testReadStopsAtTheCompletedEvent [
	| parser stream message |
	parser := SmallGPTalkOpenAIStream new.
	stream := ((self event: self completedText), 'data: invalid trailing data') readStream.
	message := parser readFrom: stream run: self.
	self assert: message text equals: 'Hello'.
	self deny: stream atEnd.
	self assert: cancellationChecks > 1
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testReadChecksCancellation [
	| parser stream |
	parser := SmallGPTalkOpenAIStream new.
	stream := (self event: self completedText) readStream.
	cancelAfter := 3.
	self should: [ parser readFrom: stream run: self ] raise: SmallGPTalkCancelled.
	self should: [ parser finish ] raise: Error.
	self assert: stream position equals: 2
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testUnicodeText [
	| parser |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self event: (self completedText copyReplaceAll: 'Hello' with: 'café 日本語')).
	self assert: parser finish text equals: 'café 日本語'
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testFinalArgumentsCanArriveWithoutDeltas [
	| parser |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self event: '{"type":"response.output_item.added","output_index":0,"item":{"type":"function_call","id":"fc_1","arguments":""}}').
	parser consume: (self event: (self completedToolArguments: '{"class":"Object"}')).
	self assert: (parser finish toolCalls first arguments at: 'class') equals: 'Object'
]

{ #category : #'helpers' }
SmallGPTalkProviderStreamTest >> doneItem: aDictionary index: anInteger [
	^ self event: (STONJSON toString: (Dictionary new
		at: 'type' put: 'response.output_item.done';
		at: 'output_index' put: anInteger;
		at: 'item' put: aDictionary;
		yourself))
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testCompletedItemsSupplyAnEmptyTerminalOutput [
	| parser item |
	parser := SmallGPTalkOpenAIStream new.
	item := (((STONJSON fromString: self completedText) at: 'response') at: 'output') first.
	item at: 'phase' put: 'final_answer'.
	parser consume: (self event: '{"type":"response.output_item.added","output_index":0,"item":{"type":"message","id":"msg_1","status":"in_progress","content":[]}}').
	parser consume: (self doneItem: item index: 0).
	parser consume: (self event: '{"type":"response.completed","response":{"status":"completed","output":[]}}').
	self assert: parser finish text equals: 'Hello'.
	self assert: parser finish providerItems first equals: item
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testCompletedToolItemsSupplyAMissingTerminalOutput [
	| parser item |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self doneItem: (STONJSON fromString: '{"type":"reasoning","id":"rs_1","encrypted_content":"test-cipher","summary":[]}') index: 0).
	parser consume: (self event: '{"type":"response.output_item.added","output_index":1,"item":{"type":"function_call","id":"fc_1","arguments":""}}').
	parser consume: (self event: '{"type":"response.function_call_arguments.delta","item_id":"fc_1","delta":"{\"class\":"}').
	parser consume: (self event: '{"type":"response.function_call_arguments.delta","output_index":1,"delta":"\"Object\"}"}').
	item := (((STONJSON fromString: (self completedToolArguments: '{"class":"Object"}')) at: 'response') at: 'output') first.
	parser consume: (self doneItem: item index: 1).
	parser consume: (self event: '{"type":"response.done","response":{"status":"completed"}}').
	self assert: (parser finish providerItems first at: 'encrypted_content') equals: 'test-cipher'.
	self assert: parser finish providerItems second equals: item.
	self assert: (parser finish toolCalls first arguments at: 'class') equals: 'Object'
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testCompletedItemsStillRequireATerminalEvent [
	| parser item |
	parser := SmallGPTalkOpenAIStream new.
	item := (((STONJSON fromString: (self completedToolArguments: '{}')) at: 'response') at: 'output') first.
	parser consume: (self doneItem: item index: 0).
	self should: [ parser finish ] raise: Error
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testEmptyTerminalRejectsAnUnfinishedAddedItem [
	| parser |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self event: '{"type":"response.output_item.added","output_index":0,"item":{"type":"message","id":"msg_1","content":[]}}').
	self should: [ parser consume: (self event: '{"type":"response.completed","response":{"status":"completed","output":[]}}') ]
		raise: Error
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testTerminalCannotLoseTextOrToolDeltas [
	#('{"type":"response.output_text.delta","delta":"Part"}'
		'{"type":"response.function_call_arguments.delta","output_index":0,"delta":"{}"}') do: [ :event |
		| parser |
		parser := SmallGPTalkOpenAIStream new.
		parser consume: (self event: event).
		self should: [ parser consume: (self event: '{"type":"response.completed","response":{"status":"completed","output":[]}}') ]
			raise: Error ]
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testMissingOutputWithoutCompletedItemsIsRejected [
	self should: [ SmallGPTalkOpenAIStream new consume: (self event: '{"type":"response.completed","response":{"status":"completed"}}') ]
		raise: Error
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testTerminalCannotChangeACompletedItem [
	| parser item |
	parser := SmallGPTalkOpenAIStream new.
	item := (((STONJSON fromString: (self completedToolArguments: '{}')) at: 'response') at: 'output') first.
	parser consume: (self doneItem: item index: 0).
	self should: [ parser consume: (self event: (self completedToolArguments: '{"class":"Object"}')) ]
		raise: Error
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testTerminalCanAddEncryptedReasoningData [
	| parser |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self doneItem: (STONJSON fromString: '{"type":"reasoning","id":"rs_1","summary":[]}') index: 0).
	parser consume: (self event: '{"type":"response.completed","response":{"status":"completed","output":[{"type":"reasoning","id":"rs_1","summary":[],"encrypted_content":"test-cipher"}]}}').
	self assert: (parser finish providerItems first at: 'encrypted_content') equals: 'test-cipher'
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testOutputItemDoneCannotHaveAnIncompleteStatus [
	self should: [ SmallGPTalkOpenAIStream new consume: (self doneItem:
		(STONJSON fromString: '{"type":"message","id":"msg_1","status":"in_progress","content":[]}') index: 0) ]
		raise: Error
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testTerminalCannotContainAnIncompleteOutputItem [
	| event |
	event := STONJSON fromString: self completedText.
	((event at: 'response') at: 'output') first at: 'status' put: 'in_progress'.
	self should: [ SmallGPTalkOpenAIStream new consume: (self event: (STONJSON toString: event)) ]
		raise: Error
]

{ #category : #'tests' }
SmallGPTalkProviderStreamTest >> testReasoningItemsCannotHideOrphanText [
	| parser |
	parser := SmallGPTalkOpenAIStream new.
	parser consume: (self event: '{"type":"response.output_text.delta","delta":"Part"}').
	parser consume: (self doneItem: (STONJSON fromString: '{"type":"reasoning","id":"rs_1","summary":[]}') index: 0).
	self should: [ parser consume: (self event: '{"type":"response.completed","response":{"status":"completed","output":[]}}') ]
		raise: Error
]
