"Count release attempts and simulate resource cleanup failure in tests."
Class {
	#name : 'SmallGPTalkTestResource',
	#superclass : 'Object',
	#instVars : [ 'releaseCount', 'failRelease' ],
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'initialization' }
SmallGPTalkTestResource >> initialize [
	super initialize. releaseCount := 0. failRelease := false
]

{ #category : 'accessing' }
SmallGPTalkTestResource >> failRelease: aBoolean [ failRelease := aBoolean ]

{ #category : 'accessing' }
SmallGPTalkTestResource >> releaseCount [ ^ releaseCount ]

{ #category : 'resources' }
SmallGPTalkTestResource >> reserveFor: run [ ]

{ #category : 'resources' }
SmallGPTalkTestResource >> releaseFor: run [
	releaseCount := releaseCount + 1.
	failRelease ifTrue: [ self error: 'Resource release failed.' ]
]
