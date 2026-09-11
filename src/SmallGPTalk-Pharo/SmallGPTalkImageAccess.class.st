"Reserve image access for one tool-enabled run, without waiting for another run."
Class {
 #name : 'SmallGPTalkImageAccess',
 #superclass : 'Object',
 #instVars : [ 'lock', 'busy' ],
 #classVars : [ 'Current' ],
 #category : 'SmallGPTalk-Pharo'
}

{ #category : 'initialization' }
SmallGPTalkImageAccess class >> initialize [
 Current := self new
]

{ #category : 'accessing' }
SmallGPTalkImageAccess class >> current [ ^ Current ]

{ #category : 'initialization' }
SmallGPTalkImageAccess >> initialize [
 super initialize.
 lock := Semaphore forMutualExclusion.
 busy := false
]

{ #category : 'execution' }
SmallGPTalkImageAccess >> during: work [
 | acquired |
 acquired := false.
 [
  lock critical: [
   busy ifTrue: [ self error: 'Another run is using the image.' ].
   acquired := true.
   busy := true ].
  ^ work value
 ] ensure: [ acquired ifTrue: [ lock critical: [ busy := false ] ] ]
]
