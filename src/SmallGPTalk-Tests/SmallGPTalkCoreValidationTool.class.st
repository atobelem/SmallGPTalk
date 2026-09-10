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
