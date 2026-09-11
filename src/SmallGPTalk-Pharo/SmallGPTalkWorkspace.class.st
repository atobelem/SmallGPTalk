"The pharo binding records navigation without opening a user interface."
Class {
 #name : 'SmallGPTalkWorkspace',
 #superclass : 'Object',
 #instVars : [ 'evaluation', 'interactions', 'observers', 'lock' ],
 #category : 'SmallGPTalk-Pharo'
}

{ #category : 'instance creation' }
SmallGPTalkWorkspace class >> forEvaluation: anEvaluation [
 ^ self new forEvaluation: anEvaluation; yourself
]

{ #category : 'initialization' }
SmallGPTalkWorkspace >> forEvaluation: anEvaluation [
 evaluation := anEvaluation.
 interactions := OrderedCollection new.
 observers := SmallGPTalkObservers new.
 lock := Semaphore forMutualExclusion
]

{ #category : 'configuration' }
SmallGPTalkWorkspace >> reportTo: anObserverCollection [
 observers := anObserverCollection
]

{ #category : 'interactions' }
SmallGPTalkWorkspace >> browse: anObject [
 self record: #browse target: anObject.
 ^ anObject
]

{ #category : 'interactions' }
SmallGPTalkWorkspace >> inspect: anObject [
 self record: #inspect target: anObject.
 ^ anObject
]

{ #category : 'private' }
SmallGPTalkWorkspace >> record: kind target: target [
 | interaction |
 evaluation state = #running ifFalse: [ self error: 'Use pharo only during its evaluation.' ].
 interaction := SmallGPTalkInteraction kind: kind target: target evaluation: evaluation.
 lock critical: [ interactions add: interaction ].
 observers notify: interaction
]

{ #category : 'accessing' }
SmallGPTalkWorkspace >> interactions [
 ^ lock critical: [ interactions copy ]
]

{ #category : 'copying' }
SmallGPTalkWorkspace >> copyFor: anEvaluation [
 | copied |
 copied := self class forEvaluation: anEvaluation.
 self interactions do: [ :interaction | copied retain: (interaction copyFor: anEvaluation) ].
 ^ copied
]

{ #category : 'private' }
SmallGPTalkWorkspace >> retain: interaction [
 lock critical: [ interactions add: interaction ]
]
