"Keep a local value and expression with the bounded model-facing result text."
Class {
	#name : 'SmallGPTalkEvaluationResult',
	#superclass : 'SmallGPTalkToolResult',
	#instVars : [ 'value', 'expression', 'context' ],
	#category : 'SmallGPTalk-Pharo',
	#package : 'SmallGPTalk-Pharo'
}

{ #category : 'evaluating' }
SmallGPTalkEvaluationResult >> value [
	^ value
]

{ #category : 'accessing' }
SmallGPTalkEvaluationResult >> value: anObject [
	value := anObject
]

{ #category : 'accessing' }
SmallGPTalkEvaluationResult >> expression [
	^ expression
]

{ #category : 'accessing' }
SmallGPTalkEvaluationResult >> expression: aString [
	expression := aString
]

{ #category : 'initialization' }
SmallGPTalkEvaluationResult >> initialize [
	super initialize.
	context := Dictionary new
]

{ #category : 'accessing' }
SmallGPTalkEvaluationResult >> context [ ^ context copy ]

{ #category : 'accessing' }
SmallGPTalkEvaluationResult >> context: aDictionary [ context := aDictionary copy ]
