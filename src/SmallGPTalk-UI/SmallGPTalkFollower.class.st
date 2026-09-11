"A view follows future interactions and discards pending work on disconnect."
Class {
 #name : 'SmallGPTalkFollower',
 #superclass : 'Object',
 #instVars : [ 'schedule', 'open', 'subscriptions', 'generation', 'errors' ],
 #category : 'SmallGPTalk-UI'
}

{ #category : 'instance creation' }
SmallGPTalkFollower class >> schedule: scheduler open: opener [
 ^ self new schedule: scheduler open: opener; yourself
]

{ #category : 'initialization' }
SmallGPTalkFollower >> schedule: scheduler open: opener [
 schedule := scheduler. open := opener.
 subscriptions := OrderedCollection new. errors := OrderedCollection new
]

{ #category : 'connection' }
SmallGPTalkFollower >> follow: tools [
 | token |
 self stop.
 generation := Object new.
 token := generation.
 tools do: [ :tool |
  (tool respondsTo: #whenInteraction:) ifTrue: [
   subscriptions add: tool -> (tool whenInteraction: [ :interaction |
    generation == token ifTrue: [
     schedule value: [ generation == token ifTrue: [ self show: interaction ] ] ] ]) ] ]
]

{ #category : 'connection' }
SmallGPTalkFollower >> stop [
 generation := nil.
 subscriptions do: [ :subscription | subscription key removeInteractionObserver: subscription value ].
 subscriptions removeAll
]

{ #category : 'private' }
SmallGPTalkFollower >> show: interaction [
 [ open value: interaction ] on: Error , Halt do: [ :failure | errors add: failure messageText copy ]
]

{ #category : 'accessing' }
SmallGPTalkFollower >> errors [
 ^ errors copy
]
