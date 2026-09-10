Class {
	#name : #SmallGPTalkCoreTestTool,
	#superclass : #SmallGPTalkTool,
	#instVars : [ 'action', 'executionCount', 'imageTool' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : #'initialization' }
SmallGPTalkCoreTestTool >> initialize [
	super initialize.
	executionCount := 0.
	imageTool := false.
	action := [ :arguments :run | SmallGPTalkToolResult text: 'Tool complete.' ]
]

{ #category : #'accessing' }
SmallGPTalkCoreTestTool >> name [
	^ 'fixture'
]

{ #category : #'accessing' }
SmallGPTalkCoreTestTool >> description [
	^ 'Run a test operation.'
]

{ #category : #'accessing' }
SmallGPTalkCoreTestTool >> inputSchema [
	^ Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new at: 'text' put: (Dictionary new at: 'type' put: 'string'; yourself); yourself);
		at: 'required' put: #('text');
		at: 'additionalProperties' put: false;
		yourself
]

{ #category : #'accessing' }
SmallGPTalkCoreTestTool >> action: aBlock [
	action := aBlock
]

{ #category : #'accessing' }
SmallGPTalkCoreTestTool >> executionCount [
	^ executionCount
]

{ #category : #'accessing' }
SmallGPTalkCoreTestTool >> imageTool: aBoolean [
	imageTool := aBoolean
]

{ #category : #'accessing' }
SmallGPTalkCoreTestTool >> requiresImage [
	^ imageTool
]

{ #category : #'running' }
SmallGPTalkCoreTestTool >> execute: arguments context: aRun [
	executionCount := executionCount + 1.
	^ action value: arguments value: aRun
]
