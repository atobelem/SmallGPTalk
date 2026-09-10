Class {
	#name : 'SmallGPTalkTool',
	#superclass : 'Object',
	#category : 'SmallGPTalk-Core',
	#package : 'SmallGPTalk-Core'
}

{ #category : 'accessing' }
SmallGPTalkTool >> description [
	self subclassResponsibility
]

{ #category : 'executing' }
SmallGPTalkTool >> execute: arguments context: aRun [
	self subclassResponsibility
]

{ #category : 'accessing' }
SmallGPTalkTool >> inputSchema [
	self subclassResponsibility
]

{ #category : 'accessing' }
SmallGPTalkTool >> name [
	self subclassResponsibility
]

{ #category : 'testing' }
SmallGPTalkTool >> requiresImage [
	^ false
]

{ #category : 'validation' }
SmallGPTalkTool >> validateArguments: arguments [
	(arguments isKindOf: Dictionary) ifFalse: [
		self error: 'Tool arguments must be an object.' ].
	self validateValue: arguments schema: self inputSchema path: 'arguments'.
	^ arguments
]

{ #category : 'private - validation' }
SmallGPTalkTool >> validateArray: values schema: schema path: path [
	| itemSchema |
	itemSchema := schema at: 'items' ifAbsent: [ ^ self ].
	values withIndexDo: [ :value :index |
		self
			validateValue: value
			schema: itemSchema
			path: path , '[' , index asString , ']' ]
]

{ #category : 'private - validation' }
SmallGPTalkTool >> validateObject: values schema: schema path: path [
	| properties additionalProperties |
	properties := schema at: 'properties' ifAbsent: [ Dictionary new ].
	additionalProperties := schema at: 'additionalProperties' ifAbsent: [ true ].
	(schema at: 'required' ifAbsent: [ #() ]) do: [ :key |
		(values includesKey: key) ifFalse: [
			self error: 'Required argument is missing: ' , path , '.' , key , '.' ] ].
	values keysAndValuesDo: [ :key :value |
		key isString ifFalse: [ self error: 'Object keys must be strings.' ].
		properties
			at: key
			ifPresent: [ :propertySchema |
				self validateValue: value schema: propertySchema path: path , '.' , key ]
			ifAbsent: [
				additionalProperties = false ifTrue: [
					self error: 'Unknown argument: ' , path , '.' , key , '.' ].
				(additionalProperties isKindOf: Dictionary) ifTrue: [
					self validateValue: value schema: additionalProperties path: path , '.' , key ] ] ]
]

{ #category : 'private - validation' }
SmallGPTalkTool >> validateValue: value schema: schema path: path [
	| type |
	type := schema at: 'type' ifAbsent: [ nil ].
	type ifNotNil: [
		(self value: value hasType: type) ifFalse: [
			self error: 'Invalid argument type: ' , path , '.' ] ].
	schema at: 'enum' ifPresent: [ :choices |
		(choices includes: value) ifFalse: [
			self error: 'Invalid argument value: ' , path , '.' ] ].
	(value isKindOf: Dictionary) ifTrue: [
		self validateObject: value schema: schema path: path ].
	(self value: value hasType: 'array') ifTrue: [
		self validateArray: value schema: schema path: path ]
]

{ #category : 'private - validation' }
SmallGPTalkTool >> value: value hasType: type [
	type isString ifFalse: [
		^ type anySatisfy: [ :each | self value: value hasType: each ] ].
	type = 'object' ifTrue: [ ^ value isKindOf: Dictionary ].
	type = 'array' ifTrue: [
		^ (value isKindOf: SequenceableCollection) and: [ value isString not ] ].
	type = 'string' ifTrue: [ ^ value isString ].
	type = 'integer' ifTrue: [ ^ value isInteger ].
	type = 'number' ifTrue: [ ^ value isNumber ].
	type = 'boolean' ifTrue: [ ^ value == true or: [ value == false ] ].
	type = 'null' ifTrue: [ ^ value isNil ].
	self error: 'Unknown schema type: ' , type , '.'
]
