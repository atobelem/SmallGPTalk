Class {
	#name : 'SmallGPTalkEvaluateTool',
	#superclass : 'SmallGPTalkImageTool',
	#category : 'SmallGPTalk-Pharo',
	#package : 'SmallGPTalk-Pharo'
}

{ #category : 'accessing' }
SmallGPTalkEvaluateTool >> name [
	^ 'evaluate'
]

{ #category : 'accessing' }
SmallGPTalkEvaluateTool >> description [
	^ 'Execute Smalltalk source in the current image. Return the result class and a bounded text value. The code has full image access. Changes remain after execution.'
]

{ #category : 'accessing' }
SmallGPTalkEvaluateTool >> inputSchema [
	^ self schema: (Dictionary new at: 'source' put: self stringSchema; yourself) required: #('source')
]

{ #category : 'private' }
SmallGPTalkEvaluateTool >> performTool: arguments context: aRun [
	| value representation limit truncated |
	value := OpalCompiler new
		source: (arguments at: 'source');
		permitUndeclared: false;
		failBlock: [ :notice | self error: 'Cannot compile the expression: ' , notice messageText ];
		evaluate.
	limit := (outputLimit min: aRun toolOutputLimit) max: 5.
	representation := String streamContents: [ :stream | value printOn: stream ] limitedTo: limit + 1.
	truncated := representation size > limit.
	truncated ifTrue: [ representation := (representation first: limit - 4) , '[..]' ].
	^ Dictionary new
		at: 'class' put: value class name asString;
		at: 'value' put: representation;
		at: 'truncated' put: truncated;
		yourself
]
