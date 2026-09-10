Class {
	#name : #SmallGPTalkAuthMemoryStore,
	#superclass : #Object,
	#instVars : [ 'record', 'writes' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : #initialization }
SmallGPTalkAuthMemoryStore >> initialize [
	super initialize.
	writes := 0
]

{ #category : #storage }
SmallGPTalkAuthMemoryStore >> read [
	^ record ifNotNil: [ record copy ]
]

{ #category : #storage }
SmallGPTalkAuthMemoryStore >> write: dictionary [
	record := dictionary copy.
	writes := writes + 1
]

{ #category : #storage }
SmallGPTalkAuthMemoryStore >> delete [
	record := nil
]

{ #category : #accessing }
SmallGPTalkAuthMemoryStore >> writes [
	^ writes
]
