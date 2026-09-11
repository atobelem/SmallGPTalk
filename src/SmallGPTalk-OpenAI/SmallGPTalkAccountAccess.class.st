"Coordinate accounts that use the same credential record in this image."
Class {
 #name : 'SmallGPTalkAccountAccess',
 #superclass : 'Object',
 #instVars : [ 'lock', 'login' ],
 #classVars : [ 'Records', 'RegistryLock' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'initialization' }
SmallGPTalkAccountAccess class >> initialize [
 Records := WeakValueDictionary new.
 RegistryLock := Semaphore forMutualExclusion
]

{ #category : 'accessing' }
SmallGPTalkAccountAccess class >> for: store [
 | key |
 key := (store respondsTo: #coordinationKey)
  ifTrue: [ store coordinationKey ] ifFalse: [ store ].
 ^ RegistryLock critical: [ Records at: key ifAbsentPut: [ self new ] ]
]

{ #category : 'initialization' }
SmallGPTalkAccountAccess >> initialize [
 super initialize.
 lock := Semaphore forMutualExclusion
]

{ #category : 'execution' }
SmallGPTalkAccountAccess >> critical: work [ ^ lock critical: work ]

{ #category : 'accessing' }
SmallGPTalkAccountAccess >> login [ ^ login ]

{ #category : 'accessing' }
SmallGPTalkAccountAccess >> login: operation [ login := operation ]
