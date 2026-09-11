"Keep the identifier, name, and arguments of a requested tool operation."
Class {
	#name : #SmallGPTalkToolCall,
	#superclass : #Object,
	#instVars : [ 'id', 'name', 'arguments', 'argumentError' ],
	#category : #'SmallGPTalk-Core'
}

{ #category : #'initialization' }
SmallGPTalkToolCall >> initialize [
	super initialize.
	arguments := Dictionary new
]

{ #category : #'accessing' }
SmallGPTalkToolCall >> id [
	^ id
]

{ #category : #'accessing' }
SmallGPTalkToolCall >> id: anObject [
	id := anObject
]

{ #category : #'accessing' }
SmallGPTalkToolCall >> name [
	^ name
]

{ #category : #'accessing' }
SmallGPTalkToolCall >> name: anObject [
	name := anObject
]

{ #category : #'accessing' }
SmallGPTalkToolCall >> arguments [
	^ arguments
]

{ #category : #'accessing' }
SmallGPTalkToolCall >> arguments: anObject [
	arguments := anObject
]

{ #category : #'instance creation' }
SmallGPTalkToolCall class >> id: anId name: aName arguments: aDictionary [
	^ self new id: anId; name: aName; arguments: aDictionary; yourself
]

{ #category : #'accessing' }
SmallGPTalkToolCall >> argumentError [
	^ argumentError
]

{ #category : #'accessing' }
SmallGPTalkToolCall >> argumentError: aString [
	argumentError := aString
]
