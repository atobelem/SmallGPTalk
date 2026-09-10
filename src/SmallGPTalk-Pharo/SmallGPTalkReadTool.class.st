Class {
	#name : 'SmallGPTalkReadTool',
	#superclass : 'SmallGPTalkImageTool',
	#category : 'SmallGPTalk-Pharo',
	#package : 'SmallGPTalk-Pharo'
}

{ #category : 'accessing' }
SmallGPTalkReadTool >> name [
	^ 'read'
]

{ #category : 'accessing' }
SmallGPTalkReadTool >> description [
	^ 'Read a class definition and comment. Supply a selector to read its method source and protocol. The default side is instance.'
]

{ #category : 'accessing' }
SmallGPTalkReadTool >> inputSchema [
	^ self schema: (Dictionary new
		at: 'class' put: self stringSchema;
		at: 'selector' put: self stringSchema;
		at: 'side' put: self sideSchema; yourself) required: #('class')
]

{ #category : 'private' }
SmallGPTalkReadTool >> performTool: arguments context: aRun [
	| behavior result selector method |
	behavior := self behaviorFor: arguments.
	result := Dictionary new
		at: 'class' put: behavior instanceSide name asString;
		at: 'side' put: (behavior isClassSide ifTrue: [ 'class' ] ifFalse: [ 'instance' ]);
		yourself.
	selector := arguments at: 'selector' ifAbsent: [
		^ result at: 'definition' put: behavior definitionString;
			at: 'comment' put: behavior instanceSide comment asString; yourself ].
	method := behavior lookupSelector: selector asSymbol.
	method ifNil: [ self error: 'The method does not exist: ' , selector , '.' ].
	^ result
		at: 'selector' put: selector;
		at: 'source' put: method sourceCode;
		at: 'protocol' put: method protocolName asString;
		at: 'definedIn' put: method methodClass name asString;
		yourself
]
