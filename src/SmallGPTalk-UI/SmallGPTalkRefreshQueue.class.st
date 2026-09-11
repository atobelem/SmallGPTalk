"Keep at most one pending UI task. Render the latest state when it runs."
Class {
 #name : 'SmallGPTalkRefreshQueue',
 #superclass : 'Object',
 #instVars : [ 'schedule', 'deliver', 'lock', 'pending', 'scheduled', 'active' ],
 #category : 'SmallGPTalk-UI'
}

{ #category : 'instance creation' }
SmallGPTalkRefreshQueue class >> schedule: scheduler deliver: receiver [
 ^ self new configureSchedule: scheduler deliver: receiver; yourself
]

{ #category : 'initialization' }
SmallGPTalkRefreshQueue >> configureSchedule: scheduler deliver: receiver [
 schedule := scheduler.
 deliver := receiver.
 lock := Semaphore forMutualExclusion.
 scheduled := false.
 active := true
]

{ #category : 'updating' }
SmallGPTalkRefreshQueue >> request: value [
 | enqueue |
 enqueue := lock critical: [
  active ifFalse: [ ^ self ].
  pending := value.
  scheduled ifTrue: [ false ] ifFalse: [ scheduled := true. true ] ].
 enqueue ifTrue: [ schedule value: [ self flush ] ]
]

{ #category : 'private' }
SmallGPTalkRefreshQueue >> flush [
 | value |
 value := lock critical: [
  | selected |
  selected := pending.
  pending := nil.
  scheduled := false.
  active ifTrue: [ selected ] ifFalse: [ nil ] ].
 value ifNotNil: [ deliver value: value ]
]

{ #category : 'connection' }
SmallGPTalkRefreshQueue >> stop [
 lock critical: [ active := false. pending := nil ]
]
