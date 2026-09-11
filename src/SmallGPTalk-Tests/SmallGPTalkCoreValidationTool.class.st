"Provide a configurable schema for tool argument validation tests."
Class {
	#name : 'SmallGPTalkCoreValidationTool',
	#superclass : 'SmallGPTalkTool',
	#instVars : [
		'schema'
	],
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'accessing' }
SmallGPTalkCoreValidationTool >> inputSchema [
	^ schema
]

{ #category : 'accessing' }
SmallGPTalkCoreValidationTool >> schema: aDictionary [
	schema := aDictionary
]

{ #category : 'accessing' }
SmallGPTalkCoreValidationTool >> name [ ^ 'validation-fixture' ]

{ #category : 'accessing' }
SmallGPTalkCoreValidationTool >> description [ ^ 'Validate arguments in an offline test.' ]

{ #category : 'executing' }
SmallGPTalkCoreValidationTool >> execute: arguments context: run [
	self validateArguments: arguments.
	^ SmallGPTalkToolResult text: 'Arguments are valid.'
]

{ #category : 'sessions' }
SmallGPTalkCoreValidationTool >> newForSession [
	^ self class new schema: schema deepCopy; yourself
]
