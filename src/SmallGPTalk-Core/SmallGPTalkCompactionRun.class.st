"Reduce a session context through the normal run lifecycle without image tools."
Class {
	#name : 'SmallGPTalkCompactionRun',
	#superclass : 'SmallGPTalkRun',
	#category : 'SmallGPTalk-Core',
	#package : 'SmallGPTalk-Core'
}

{ #category : 'private' }
SmallGPTalkCompactionRun >> performRequest [
	^ session context compactUsing: self
]

{ #category : 'private' }
SmallGPTalkCompactionRun >> reserveResources [
	"A summary request does not execute the session tools."
]
