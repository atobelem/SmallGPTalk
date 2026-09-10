Class {
	#name : 'SmallGPTalkImageTool',
	#superclass : 'SmallGPTalkTool',
	#instVars : [ 'outputLimit', 'timeoutSeconds' ],
	#category : 'SmallGPTalk-Pharo',
	#package : 'SmallGPTalk-Pharo'
}

{ #category : 'initialization' }
SmallGPTalkImageTool >> initialize [
	super initialize.
	outputLimit := 20000.
	timeoutSeconds := 10
]

{ #category : 'accessing' }
SmallGPTalkImageTool >> outputLimit [
	^ outputLimit
]

{ #category : 'accessing' }
SmallGPTalkImageTool >> outputLimit: anInteger [
	(anInteger isInteger and: [ anInteger >= 100 ]) ifFalse: [
		self error: 'The output limit must be an integer of at least 100.' ].
	outputLimit := anInteger
]

{ #category : 'accessing' }
SmallGPTalkImageTool >> timeoutSeconds [
	^ timeoutSeconds
]

{ #category : 'accessing' }
SmallGPTalkImageTool >> timeoutSeconds: aNumber [
	(aNumber isNumber and: [ aNumber > 0 ]) ifFalse: [
		self error: 'The time limit must be positive.' ].
	timeoutSeconds := aNumber
]

{ #category : 'testing' }
SmallGPTalkImageTool >> requiresImage [
	^ true
]

{ #category : 'executing' }
SmallGPTalkImageTool >> execute: arguments context: aRun [
	self validateArguments: arguments.
	aRun checkCancellation.
	^ aRun
		supervise: [ self resultFor: (self performTool: arguments context: aRun) context: aRun ]
		timeoutSeconds: timeoutSeconds
]

{ #category : 'private' }
SmallGPTalkImageTool >> performTool: arguments context: aRun [
	self subclassResponsibility
]

{ #category : 'private' }
SmallGPTalkImageTool >> resultFor: aDictionary context: aRun [
	| result text limit suffix |
	text := STONJSON toString: aDictionary.
	limit := outputLimit min: aRun toolOutputLimit.
	result := SmallGPTalkToolResult text: text.
	(aDictionary at: 'truncated' ifAbsent: [ false ]) ifTrue: [ result truncated: true ].
	text size > limit ifTrue: [
		suffix := String lf , '[Output truncated]'.
		result
			text: (text first: (limit - suffix size max: 0)) , (suffix first: (limit min: suffix size));
			truncated: true ].
	^ result
]

{ #category : 'private' }
SmallGPTalkImageTool >> classNamed: aString [
	| candidate |
	candidate := Smalltalk globals at: aString asSymbol ifAbsent: [
		self error: 'The class does not exist: ' , aString , '.' ].
	candidate isClass ifFalse: [ self error: 'The name does not identify a class.' ].
	^ candidate
]

{ #category : 'private' }
SmallGPTalkImageTool >> behaviorFor: arguments [
	| class |
	class := self classNamed: (arguments at: 'class').
	^ (arguments at: 'side' ifAbsent: [ 'instance' ]) = 'class'
		ifTrue: [ class class ]
		ifFalse: [ class ]
]

{ #category : 'private - schema' }
SmallGPTalkImageTool >> stringSchema [
	^ Dictionary new at: 'type' put: 'string'; yourself
]

{ #category : 'private - schema' }
SmallGPTalkImageTool >> sideSchema [
	^ self stringSchema at: 'enum' put: #('instance' 'class'); yourself
]

{ #category : 'private - schema' }
SmallGPTalkImageTool >> schema: properties required: required [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: properties;
		at: 'required' put: required;
		at: 'additionalProperties' put: false;
		yourself
]
