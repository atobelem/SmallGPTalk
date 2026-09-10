Class {
	#name : #SmallGPTalkToolResult,
	#superclass : #Object,
	#instVars : [ 'text', 'isError', 'truncated' ],
	#category : #'SmallGPTalk-Core'
}

{ #category : #'initialization' }
SmallGPTalkToolResult >> initialize [
	super initialize.
	text := ''.
	isError := false.
	truncated := false
]

{ #category : #'accessing' }
SmallGPTalkToolResult >> text [
	^ text
]

{ #category : #'accessing' }
SmallGPTalkToolResult >> text: anObject [
	text := anObject
]

{ #category : #'accessing' }
SmallGPTalkToolResult >> isError [
	^ isError
]

{ #category : #'accessing' }
SmallGPTalkToolResult >> isError: anObject [
	isError := anObject
]

{ #category : #'accessing' }
SmallGPTalkToolResult >> truncated [
	^ truncated
]

{ #category : #'accessing' }
SmallGPTalkToolResult >> truncated: anObject [
	truncated := anObject
]

{ #category : #'instance creation' }
SmallGPTalkToolResult class >> text: aString [
	^ self new text: aString; yourself
]

{ #category : #'instance creation' }
SmallGPTalkToolResult class >> error: aString [
	^ self new text: aString; isError: true; yourself
]
