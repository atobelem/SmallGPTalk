"Keep the measured input size and model capacity for one response."
Class {
 #name : 'SmallGPTalkContextUsage',
 #superclass : 'Object',
 #instVars : [ 'inputTokens', 'capacity' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'instance creation' }
SmallGPTalkContextUsage class >> inputTokens: count capacity: limit [
 ^ self new inputTokens: count capacity: limit; yourself
]

{ #category : 'initialization' }
SmallGPTalkContextUsage >> inputTokens: count capacity: limit [
 (count isInteger and: [ count >= 0 and: [ limit isInteger and: [ limit > 0 ] ] ])
  ifFalse: [ self error: 'Supply a nonnegative token count and a positive capacity.' ].
 inputTokens := count.
 capacity := limit
]

{ #category : 'accessing' }
SmallGPTalkContextUsage >> inputTokens [ ^ inputTokens ]

{ #category : 'accessing' }
SmallGPTalkContextUsage >> capacity [ ^ capacity ]

{ #category : 'measurement' }
SmallGPTalkContextUsage >> percentage [ ^ (inputTokens * 100 / capacity) rounded ]
