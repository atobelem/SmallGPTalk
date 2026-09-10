Class {
	#name : #SmallGPTalkFailure,
	#superclass : #Object,
	#instVars : [ 'exceptionClassName', 'messageText', 'status' ],
	#category : #'SmallGPTalk-Core'
}

{ #category : #'instance creation' }
SmallGPTalkFailure class >> fromException: anException [
	| code |
	code := (anException respondsTo: #status) ifTrue: [ anException status ] ifFalse: [ nil ].
	^ self new
		exceptionClassName: anException class name asString;
		messageText: anException messageText asString copy;
		status: (code isNumber ifTrue: [ code ] ifFalse: [ nil ]);
		yourself
]

{ #category : #'accessing' }
SmallGPTalkFailure >> exceptionClassName [
	^ exceptionClassName
]

{ #category : #'accessing' }
SmallGPTalkFailure >> exceptionClassName: aString [
	exceptionClassName := aString
]

{ #category : #'accessing' }
SmallGPTalkFailure >> messageText [
	^ messageText
]

{ #category : #'accessing' }
SmallGPTalkFailure >> messageText: aString [
	messageText := aString
]

{ #category : #'accessing' }
SmallGPTalkFailure >> status [
	^ status
]

{ #category : #'accessing' }
SmallGPTalkFailure >> status: aNumber [
	status := aNumber
]
