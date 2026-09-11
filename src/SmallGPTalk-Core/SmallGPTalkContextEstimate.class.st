"A local input estimate, kept separate from provider measurements."
Class {
 #name : 'SmallGPTalkContextEstimate',
 #superclass : 'Object',
 #instVars : [ 'inputTokens', 'capacity' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'instance creation' }
SmallGPTalkContextEstimate class >> inputTokens: count capacity: limit [
 ^ self new inputTokens: count capacity: limit; yourself
]

{ #category : 'initialization' }
SmallGPTalkContextEstimate >> inputTokens: count capacity: limit [
 (count isInteger and: [ count >= 0 and: [ limit isInteger and: [ limit > 0 ] ] ])
  ifFalse: [ self error: 'Supply a nonnegative estimate and a positive capacity.' ].
 inputTokens := count.
 capacity := limit
]

{ #category : 'accessing' }
SmallGPTalkContextEstimate >> inputTokens [ ^ inputTokens ]

{ #category : 'accessing' }
SmallGPTalkContextEstimate >> capacity [ ^ capacity ]

{ #category : 'measurement' }
SmallGPTalkContextEstimate >> percentage [ ^ (inputTokens * 100 / capacity) rounded ]
