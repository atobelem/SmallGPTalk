Class {
	#name : #SmallGPTalkMessage,
	#superclass : #Object,
	#instVars : [ 'role', 'text', 'toolCalls', 'callId', 'providerItems', 'isError' ],
	#category : #'SmallGPTalk-Core'
}

{ #category : #'initialization' }
SmallGPTalkMessage >> initialize [
	super initialize.
	text := ''.
	toolCalls := #().
	providerItems := #().
	isError := false
]

{ #category : #'accessing' }
SmallGPTalkMessage >> role [
	^ role
]

{ #category : #'accessing' }
SmallGPTalkMessage >> role: anObject [
	role := anObject
]

{ #category : #'accessing' }
SmallGPTalkMessage >> text [
	^ text
]

{ #category : #'accessing' }
SmallGPTalkMessage >> text: anObject [
	text := anObject
]

{ #category : #'accessing' }
SmallGPTalkMessage >> toolCalls [
	^ toolCalls
]

{ #category : #'accessing' }
SmallGPTalkMessage >> toolCalls: anObject [
	toolCalls := anObject
]

{ #category : #'accessing' }
SmallGPTalkMessage >> callId [
	^ callId
]

{ #category : #'accessing' }
SmallGPTalkMessage >> callId: anObject [
	callId := anObject
]

{ #category : #'accessing' }
SmallGPTalkMessage >> providerItems [
	^ providerItems
]

{ #category : #'accessing' }
SmallGPTalkMessage >> providerItems: anObject [
	providerItems := anObject
]

{ #category : #'accessing' }
SmallGPTalkMessage >> isError [
	^ isError
]

{ #category : #'accessing' }
SmallGPTalkMessage >> isError: anObject [
	isError := anObject
]

{ #category : #'instance creation' }
SmallGPTalkMessage class >> user: aString [
	^ self new role: #user; text: aString; yourself
]

{ #category : #'instance creation' }
SmallGPTalkMessage class >> assistant: aString [
	^ self new role: #assistant; text: aString; yourself
]

{ #category : #'instance creation' }
SmallGPTalkMessage class >> toolResult: aResult for: aCall [
	^ self new
		role: #tool;
		text: aResult text;
		callId: aCall id;
		isError: aResult isError;
		yourself
]
