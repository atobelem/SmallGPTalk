Class {
	#name : 'SmallGPTalkCompileTool',
	#superclass : 'SmallGPTalkImageTool',
	#category : 'SmallGPTalk-Pharo',
	#package : 'SmallGPTalk-Pharo'
}

{ #category : 'accessing' }
SmallGPTalkCompileTool >> name [
	^ 'compile'
]

{ #category : 'accessing' }
SmallGPTalkCompileTool >> description [
	^ 'Add or replace one method in an existing class. Supply method source and its protocol. The default side is instance. Changes remain in the current image.'
]

{ #category : 'accessing' }
SmallGPTalkCompileTool >> inputSchema [
	^ self schema: (Dictionary new
		at: 'class' put: self stringSchema;
		at: 'source' put: self stringSchema;
		at: 'protocol' put: self stringSchema;
		at: 'side' put: self sideSchema; yourself) required: #('class' 'source' 'protocol')
]

{ #category : 'private' }
SmallGPTalkCompileTool >> performTool: arguments context: aRun [
	| behavior method protocol |
	behavior := self behaviorFor: arguments.
	protocol := arguments at: 'protocol'.
	protocol isEmpty ifTrue: [ self error: 'Supply a method protocol.' ].
	method := behavior compiler
		source: (arguments at: 'source');
		protocol: protocol;
		permitUndeclared: false;
		failBlock: [ :notice | self error: 'Cannot compile the method: ' , notice messageText ];
		install.
	^ Dictionary new
		at: 'class' put: behavior instanceSide name asString;
		at: 'side' put: (behavior isClassSide ifTrue: [ 'class' ] ifFalse: [ 'instance' ]);
		at: 'selector' put: method selector asString;
		at: 'protocol' put: method protocolName asString;
		yourself
]
