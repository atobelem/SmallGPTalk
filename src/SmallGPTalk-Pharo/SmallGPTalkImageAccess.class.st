"Reserve exclusive image tool access for one run at a time."
Class {
	#name : 'SmallGPTalkImageAccess',
	#superclass : 'Object',
	#classVars : [ 'Lock', 'ActiveRun' ],
	#category : 'SmallGPTalk-Pharo',
	#package : 'SmallGPTalk-Pharo'
}

{ #category : 'class initialization' }
SmallGPTalkImageAccess class >> initialize [
	Lock := Semaphore forMutualExclusion
]

{ #category : 'execution resources' }
SmallGPTalkImageAccess class >> reserveFor: run [
	Lock critical: [
		ActiveRun ifNotNil: [ self error: 'This image has an active run with image tools.' ].
		ActiveRun := run ]
]

{ #category : 'execution resources' }
SmallGPTalkImageAccess class >> releaseFor: run [
	Lock critical: [ ActiveRun == run ifTrue: [ ActiveRun := nil ] ]
]
