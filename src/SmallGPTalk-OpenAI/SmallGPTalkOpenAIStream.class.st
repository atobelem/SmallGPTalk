Class {
	#name : #SmallGPTalkOpenAIStream,
	#superclass : #Object,
	#instVars : [ 'line', 'dataLines', 'previousCR', 'textBlock', 'response', 'fragments', 'indices', 'message', 'pendingItems', 'completedItems', 'hasText' ],
	#category : #'SmallGPTalk-OpenAI'
}

{ #category : #'initialization' }
SmallGPTalkOpenAIStream >> initialize [
	super initialize.
	line := String new writeStream.
	dataLines := OrderedCollection new.
	previousCR := false.
	textBlock := [ :text | ].
	fragments := Dictionary new.
	indices := Dictionary new.
	pendingItems := Set new.
	completedItems := Dictionary new.
	hasText := false
]

{ #category : #'accessing' }
SmallGPTalkOpenAIStream >> onText: aBlock [
	textBlock := aBlock
]

{ #category : #'reading' }
SmallGPTalkOpenAIStream >> consume: aString [
	aString do: [ :character | self consumeCharacter: character ]
]

{ #category : #'private - reading' }
SmallGPTalkOpenAIStream >> consumeCharacter: aCharacter [
	previousCR ifTrue: [
		previousCR := false.
		aCharacter = Character lf ifTrue: [ ^ self ] ].
	aCharacter = Character cr ifTrue: [
		previousCR := true.
		^ self processLine ].
	aCharacter = Character lf ifTrue: [ ^ self processLine ].
	line nextPut: aCharacter
]

{ #category : #'private - reading' }
SmallGPTalkOpenAIStream >> processLine [
	| value separator field |
	value := line contents.
	line := String new writeStream.
	value isEmpty ifTrue: [ ^ self dispatchEvent ].
	value first = $: ifTrue: [ ^ self ].
	separator := value indexOf: $:.
	separator = 0
		ifTrue: [ field := value. value := '' ]
		ifFalse: [
			field := value copyFrom: 1 to: separator - 1.
			value := value copyFrom: separator + 1 to: value size.
			(value notEmpty and: [ value first = Character space ])
				ifTrue: [ value := value allButFirst ] ].
	field = 'data' ifTrue: [ dataLines add: value ]
]

{ #category : #'private - reading' }
SmallGPTalkOpenAIStream >> dispatchEvent [
	| data event |
	dataLines isEmpty ifTrue: [ ^ self ].
	data := String streamContents: [ :stream |
		dataLines do: [ :each | stream nextPutAll: each ]
			separatedBy: [ stream lf ] ].
	dataLines removeAll.
	data = '[DONE]' ifTrue: [ ^ self ].
	response ifNotNil: [ ^ self ].
	event := [ STONJSON fromString: data ]
		on: Error do: [ :error | self error: 'The model event has invalid JSON.' ].
	(event isKindOf: Dictionary) ifFalse: [
		self error: 'The model event must be a JSON object.' ].
	self processEvent: event
]

{ #category : #'private - events' }
SmallGPTalkOpenAIStream >> processEvent: anEvent [
	| type |
	type := anEvent at: 'type' ifAbsent: [ '' ].
	(#('response.failed' 'response.incomplete' 'response.cancelled' 'error') includes: type)
		ifTrue: [ self error: 'The model response did not complete: ', type, '.' ].
	(#('response.completed' 'response.done') includes: type)
		ifTrue: [ ^ self completeResponse: (anEvent at: 'response' ifAbsent: [ nil ]) ].
	(#('response.output_text.delta' 'response.refusal.delta') includes: type)
		ifTrue: [
			| text |
			text := self string: 'delta' in: anEvent.
			hasText := hasText or: [ text notEmpty ].
			^ textBlock value: text ].
	type = 'response.output_item.added'
		ifTrue: [ ^ self addItem: anEvent ].
	type = 'response.output_item.done'
		ifTrue: [ ^ self completeItem: anEvent ].
	type = 'response.function_call_arguments.delta'
		ifTrue: [ ^ self addArguments: anEvent ]
]

{ #category : #'private - events' }
SmallGPTalkOpenAIStream >> addItem: anEvent [
	| item index itemId arguments |
	item := anEvent at: 'item'.
	index := self outputIndexIn: anEvent.
	(completedItems includesKey: index) ifTrue: [
		self error: 'The model added an output item after it completed.' ].
	pendingItems add: index.
	itemId := self string: 'id' in: item.
	indices at: itemId put: index.
	(item at: 'type') = 'function_call' ifFalse: [ ^ self ].
	arguments := item at: 'arguments' ifAbsent: [ '' ].
	arguments isString ifFalse: [ self error: 'The tool arguments must be a JSON string.' ].
	arguments isEmpty ifTrue: [ ^ self ].
	fragments at: index ifAbsentPut: [
		String new writeStream nextPutAll: arguments; yourself ]
]

{ #category : #'private - events' }
SmallGPTalkOpenAIStream >> completeItem: anEvent [
	| item index |
	item := anEvent at: 'item'.
	(item isKindOf: Dictionary) ifFalse: [
		self error: 'The completed output item must be a JSON object.' ].
	(item at: 'status' ifAbsent: [ 'completed' ]) = 'completed' ifFalse: [
		self error: 'The output item did not complete.' ].
	index := self outputIndexIn: anEvent.
	completedItems at: index ifPresent: [ :previous |
		previous = item ifFalse: [
			self error: 'The completed output items do not match.' ] ].
	completedItems at: index put: item.
	pendingItems remove: index ifAbsent: [ ]
]

{ #category : #'private - validation' }
SmallGPTalkOpenAIStream >> outputIndexIn: anEvent [
	| index |
	index := anEvent at: 'output_index'.
	(index isInteger and: [ index >= 0 ]) ifFalse: [
		self error: 'The output index must be a non-negative integer.' ].
	^ index
]

{ #category : #'private - events' }
SmallGPTalkOpenAIStream >> addArguments: anEvent [
	| index itemId stream |
	itemId := anEvent at: 'item_id' ifAbsent: [ nil ].
	index := anEvent at: 'output_index' ifAbsent: [
		indices at: itemId ifAbsent: [
			self error: 'The tool argument event has no output index.' ] ].
	itemId ifNotNil: [ indices at: itemId put: index ].
	stream := fragments at: index ifAbsentPut: [ String new writeStream ].
	stream nextPutAll: (self string: 'delta' in: anEvent)
]

{ #category : #'private - events' }
SmallGPTalkOpenAIStream >> completeResponse: anObject [
	(anObject isKindOf: Dictionary) ifFalse: [
		self error: 'The terminal model event has no response.' ].
	(anObject at: 'status' ifAbsent: [ '' ]) = 'completed' ifFalse: [
		self error: 'The model response did not complete.' ].
	response := anObject.
	message := self buildMessage
]

{ #category : #'private - conversion' }
SmallGPTalkOpenAIStream >> buildMessage [
	| output text calls ids |
	output := self completedOutput.
	text := String new writeStream.
	calls := OrderedCollection new.
	ids := Set new.
	output withIndexDo: [ :item :index |
		| type call |
		(item isKindOf: Dictionary) ifFalse: [
			self error: 'The model output item must be a JSON object.' ].
		(item at: 'status' ifAbsent: [ 'completed' ]) = 'completed' ifFalse: [
			self error: 'The output item did not complete.' ].
		type := item at: 'type' ifAbsent: [ '' ].
		type = 'message' ifTrue: [ self textFrom: item into: text ].
		type = 'function_call' ifTrue: [
			call := self toolCallFrom: item index: index - 1.
			(ids includes: call id) ifTrue: [
				self error: 'The model response has a repeated tool call ID.' ].
			ids add: call id.
			calls add: call ] ].
	(hasText and: [ text contents isEmpty ]) ifTrue: [
		self error: 'The model text has no completed output item.' ].
	^ (SmallGPTalkMessage assistant: text contents)
		toolCalls: calls asArray;
		providerItems: output;
		yourself
]

{ #category : #'private - conversion' }
SmallGPTalkOpenAIStream >> completedOutput [
	| output |
	output := response at: 'output' ifAbsent: [ nil ].
	output ifNotNil: [
		output isArray ifFalse: [ self error: 'The model output must be a JSON array.' ].
		output ifNotEmpty: [ ^ self reconcileOutput: output ] ].
	pendingItems ifNotEmpty: [ self error: 'The model stream has an incomplete output item.' ].
	fragments keysDo: [ :index |
		(completedItems includesKey: index) ifFalse: [
			self error: 'The tool arguments have no completed output item.' ] ].
	completedItems ifEmpty: [
		(output isNil or: [ hasText ]) ifTrue: [
			self error: 'The completed model response has no output.' ].
		^ #() ].
	0 to: completedItems size - 1 do: [ :index |
		(completedItems includesKey: index) ifFalse: [
			self error: 'The model stream has a missing output item.' ] ].
	^ (completedItems keys sorted collect: [ :index | completedItems at: index ]) asArray
]

{ #category : #'private - conversion' }
SmallGPTalkOpenAIStream >> reconcileOutput: output [
	| result |
	completedItems keysDo: [ :index |
		index >= output size ifTrue: [
			self error: 'The terminal response has a missing output item.' ] ].
	result := output copy.
	completedItems keysAndValuesDo: [ :index :item |
		| final |
		final := (output at: index + 1) copy.
		(final isKindOf: Dictionary) ifFalse: [
			self error: 'The model output item must be a JSON object.' ].
		item keysAndValuesDo: [ :key :value |
			(final at: key ifAbsent: [ nil ])
				ifNil: [ final at: key put: value ]
				ifNotNil: [ :finalValue |
					(value notNil and: [ finalValue ~= value ]) ifTrue: [
						self error: 'The output item does not match the terminal response.' ] ] ].
		result at: index + 1 put: final ].
	^ result
]

{ #category : #'private - conversion' }
SmallGPTalkOpenAIStream >> textFrom: anItem into: aStream [
	(anItem at: 'content' ifAbsent: [ #() ]) do: [ :part |
		| type |
		type := part at: 'type' ifAbsent: [ '' ].
		type = 'output_text' ifTrue: [ aStream nextPutAll: (self string: 'text' in: part) ].
		type = 'refusal' ifTrue: [ aStream nextPutAll: (self string: 'refusal' in: part) ] ]
]

{ #category : #'private - conversion' }
SmallGPTalkOpenAIStream >> toolCallFrom: anItem index: anInteger [
	| call arguments parsed fragment |
	(anItem at: 'status' ifAbsent: [ 'completed' ]) = 'completed' ifFalse: [
		self error: 'The tool call did not complete.' ].
	call := SmallGPTalkToolCall
		id: (self string: 'call_id' in: anItem)
		name: (self string: 'name' in: anItem)
		arguments: Dictionary new.
	(call id isEmpty or: [ call name isEmpty ]) ifTrue: [
		self error: 'The tool call must have an ID and a name.' ].
	arguments := self string: 'arguments' in: anItem.
	fragment := fragments at: anInteger ifAbsent: [ nil ].
	(fragment notNil and: [ fragment contents ~= arguments ]) ifTrue: [
		self error: 'The tool arguments do not match the completed response.' ].
	parsed := [ STONJSON fromString: arguments ]
		on: Error do: [ :error |
			call argumentError: 'The tool arguments have invalid JSON.'.
			^ call ].
	(parsed isKindOf: Dictionary) ifFalse: [
		call argumentError: 'The tool arguments must be a JSON object.'.
		^ call ].
	call arguments: parsed.
	^ call
]

{ #category : #'private - validation' }
SmallGPTalkOpenAIStream >> string: aKey in: aDictionary [
	| value |
	value := aDictionary at: aKey ifAbsent: [
		self error: 'The model event has no ', aKey, ' field.' ].
	value isString ifFalse: [
		self error: 'The model event ', aKey, ' field must be a string.' ].
	^ value
]

{ #category : #'reading' }
SmallGPTalkOpenAIStream >> readFrom: aStream run: aRun [
	[ aRun checkCancellation.
		response isNil and: [ aStream atEnd not ] ] whileTrue: [
		self consumeCharacter: aStream next ].
	aRun checkCancellation.
	^ self finish
]

{ #category : #'reading' }
SmallGPTalkOpenAIStream >> finish [
	message ifNil: [ self error: 'The model stream ended before a complete response.' ].
	^ message
]
