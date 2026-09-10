Class {
	#name : #SmallGPTalkAuthTestTransport,
	#superclass : #Object,
	#instVars : [ 'response', 'operation', 'requests' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : #initialization }
SmallGPTalkAuthTestTransport >> initialize [
	super initialize.
	requests := OrderedCollection new
]

{ #category : #accessing }
SmallGPTalkAuthTestTransport >> response: dictionary [
	response := dictionary
]

{ #category : #accessing }
SmallGPTalkAuthTestTransport >> operation: block [
	operation := block
]

{ #category : #accessing }
SmallGPTalkAuthTestTransport >> requests [
	^ requests
]

{ #category : #requests }
SmallGPTalkAuthTestTransport >> postForm: fields [
	requests add: fields copy.
	operation ifNotNil: [ operation value ].
	^ response copy
]
