"Provide output limits, supervision, and image access for image tools."
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
	| result |
	result := SmallGPTalkToolResult text: (STONJSON toString: aDictionary).
	(aDictionary at: 'truncated' ifAbsent: [ false ]) ifTrue: [ result truncated: true ].
	^ result limitTextTo: (outputLimit min: aRun toolOutputLimit)
]

{ #category : 'private - schema' }
SmallGPTalkImageTool >> stringSchema [
	^ Dictionary new at: 'type' put: 'string'; yourself
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

{ #category : 'sessions' }
SmallGPTalkImageTool >> newForSession [
	^ self class new outputLimit: outputLimit; timeoutSeconds: timeoutSeconds; yourself
]

{ #category : 'execution resources' }
SmallGPTalkImageTool >> executionResources [
	^ { SmallGPTalkImageAccess }
]
