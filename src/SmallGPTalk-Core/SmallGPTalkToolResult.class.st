"Keep bounded result text, error state, and truncation state for a tool operation."
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

{ #category : 'error handling' }
SmallGPTalkToolResult class >> error: aString [
	^ self new text: aString; isError: true; yourself
]

{ #category : 'converting' }
SmallGPTalkToolResult >> limitTextTo: limit [
	| marker keep |
	text size <= limit ifTrue: [ ^ self ].
	marker := String lf , '[Output truncated]'.
	keep := (limit - marker size) max: 0.
	text := (text first: keep) , (marker first: (marker size min: limit)).
	truncated := true
]
