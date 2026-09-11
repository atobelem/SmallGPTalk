"The ordered messages committed by a session. Display fragments are not messages."
Class {
	#name : 'SmallGPTalkConversation',
	#superclass : 'Object',
	#instVars : [ 'messages', 'lock' ],
	#category : 'SmallGPTalk-Core',
	#package : 'SmallGPTalk-Core'
}

{ #category : 'initialization' }
SmallGPTalkConversation >> initialize [
	super initialize.
	messages := OrderedCollection new.
	lock := Semaphore forMutualExclusion
]

{ #category : 'accessing' }
SmallGPTalkConversation >> addMessage: aMessage [
	lock critical: [ self validateCallIdsIn: aMessage. messages add: aMessage ]
]

{ #category : 'accessing' }
SmallGPTalkConversation >> messages [
	^ lock critical: [ messages copy ]
]

{ #category : 'accessing' }
SmallGPTalkConversation >> isEmpty [
	^ lock critical: [ messages isEmpty ]
]

{ #category : 'accessing' }
SmallGPTalkConversation >> messageWithCallId: anId [
	^ self messages detect: [ :message |
		message toolCalls anySatisfy: [ :call | call id = anId ] ] ifNone: [ nil ]
]

{ #category : 'accessing' }
SmallGPTalkConversation >> resultWithCallId: anId [
	^ self messages detect: [ :message |
		message role = #tool and: [ message callId = anId ] ] ifNone: [ nil ]
]

{ #category : 'private' }
SmallGPTalkConversation >> validateCallIdsIn: aMessage [
	| identifiers |
	aMessage toolCalls ifEmpty: [ ^ self ].
	identifiers := Set new.
	messages do: [ :message | message toolCalls do: [ :call | identifiers add: call id ] ].
	aMessage toolCalls do: [ :call |
		(identifiers includes: call id) ifTrue: [
			self error: 'Tool call identifiers must be unique in the conversation.' ].
		identifiers add: call id ]
]
