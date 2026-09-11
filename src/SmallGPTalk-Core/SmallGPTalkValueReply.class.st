"Adapt a simple model value while retaining its identity as the public result."
Class {
 #name : 'SmallGPTalkValueReply',
 #superclass : 'SmallGPTalkReply',
 #instVars : [ 'value' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'instance creation' }
SmallGPTalkValueReply class >> on: anObject [
 ^ self new useValue: anObject; yourself
]

{ #category : 'initialization' }
SmallGPTalkValueReply >> useValue: anObject [
 value := anObject.
 self prepareText: (value isString ifTrue: [ value ] ifFalse: [ '' ]) calls: #()
]

{ #category : 'accessing' }
SmallGPTalkValueReply >> result [ ^ value ]

{ #category : 'accessing' }
SmallGPTalkValueReply >> continuationText [
 value isString ifFalse: [ self error: 'The provider requires a text reply.' ].
 ^ self text
]
