"A recorded request to browse or inspect a live object."
Class {
 #name : 'SmallGPTalkInteraction',
 #superclass : 'Object',
 #instVars : [ 'kind', 'target', 'evaluation' ],
 #category : 'SmallGPTalk-Pharo'
}

{ #category : 'instance creation' }
SmallGPTalkInteraction class >> kind: aSymbol target: anObject evaluation: anEvaluation [
 ^ self new kind: aSymbol target: anObject evaluation: anEvaluation; yourself
]

{ #category : 'initialization' }
SmallGPTalkInteraction >> kind: aSymbol target: anObject evaluation: anEvaluation [
 kind := aSymbol. target := anObject. evaluation := anEvaluation
]

{ #category : 'accessing' }
SmallGPTalkInteraction >> kind [
 ^ kind
]

{ #category : 'accessing' }
SmallGPTalkInteraction >> target [
 ^ target
]

{ #category : 'accessing' }
SmallGPTalkInteraction >> evaluation [
 ^ evaluation
]

{ #category : 'copying' }
SmallGPTalkInteraction >> copyFor: anEvaluation [
 ^ self class kind: kind target: target evaluation: anEvaluation
]

{ #category : 'displaying' }
SmallGPTalkInteraction >> label [
 target isCompiledMethod ifTrue: [
  ^ kind asString, ' — ', target methodClass name, ' >> #', target selector ].
 target isBehavior ifTrue: [ ^ kind asString, ' — ', target name ].
 ^ kind asString, ' — ', target class name
]
