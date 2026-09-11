"Deliver notifications without making observers part of the work outcome."
Class {
 #name : 'SmallGPTalkObservers',
 #superclass : 'Object',
 #instVars : [ 'observers', 'errors', 'lock' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'initialization' }
SmallGPTalkObservers >> initialize [
 super initialize.
 observers := OrderedCollection new.
 errors := OrderedCollection new.
 lock := Semaphore forMutualExclusion
]

{ #category : 'subscriptions' }
SmallGPTalkObservers >> add: observer [
 lock critical: [ observers add: observer ].
 ^ observer
]

{ #category : 'subscriptions' }
SmallGPTalkObservers >> remove: observer [
 lock critical: [ observers remove: observer ifAbsent: [ ] ]
]

{ #category : 'notification' }
SmallGPTalkObservers >> notify: object [
 | selected |
 selected := lock critical: [ observers copy ].
 selected do: [ :observer |
  [ observer value: object ] on: Error , Halt do: [ :failure |
   lock critical: [ errors add: failure messageText copy ] ] ]
]

{ #category : 'accessing' }
SmallGPTalkObservers >> errors [
 ^ lock critical: [ errors collect: #copy ]
]
