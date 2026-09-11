"A named agent can participate in independent sessions."
Class {
 #name : 'SmallGPTalkAgent',
 #superclass : 'Object',
 #instVars : [ 'name', 'instructions' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'instance creation' }
SmallGPTalkAgent class >> named: aString [
 ^ self new name: aString; yourself
]

{ #category : 'accessing' }
SmallGPTalkAgent >> name: aString [
 name := aString copy
]

{ #category : 'accessing' }
SmallGPTalkAgent >> name [ ^ name copy ]

{ #category : 'sessions' }
SmallGPTalkAgent >> newSessionWith: aModel [
 ^ (SmallGPTalkSession withModel: aModel) useAgent: self; yourself
]

{ #category : 'initialization' }
SmallGPTalkAgent >> initialize [
 super initialize.
 name := 'SmallGPTalk'.
 instructions := ''
]

{ #category : 'accessing' }
SmallGPTalkAgent >> instructions [ ^ instructions copy ]

{ #category : 'accessing' }
SmallGPTalkAgent >> instructions: aString [
 instructions := aString copy
]
