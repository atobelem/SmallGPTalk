Class {
 #name : 'SmallGPTalkCloseFailingClient',
 #superclass : 'ZnClient',
 #instVars : [ 'failClose' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'testing' }
SmallGPTalkCloseFailingClient >> post [
 | result |
 result := super post.
 failClose := true.
 ^ result
]

{ #category : 'testing' }
SmallGPTalkCloseFailingClient >> close [
 super close.
 failClose = true ifTrue: [ self error: 'Test connection close failed.' ]
]
