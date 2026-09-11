"Select model history while keeping the complete conversation elsewhere."
Class {
 #name : 'SmallGPTalkContext',
 #superclass : 'Object',
 #instVars : [ 'summary', 'covered', 'autoCompactLimit' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'initialization' }
SmallGPTalkContext >> initialize [
 super initialize.
 covered := 0.
 autoCompactLimit := 60000
]

{ #category : 'requests' }
SmallGPTalkContext >> requestFor: text history: history agent: agent [
 ^ (SmallGPTalkRequest text: text
  history: (history allButFirst: covered) agent: agent) withSummary: summary
]

{ #category : 'requests' }
SmallGPTalkContext >> summaryRequestFrom: history [
 ^ (self requestFor: 'Return only a continuation summary.' history: history agent: nil) forCompaction
]

{ #category : 'compaction' }
SmallGPTalkContext >> absorb: reply through: count [
 | text |
 (reply isKindOf: SmallGPTalkReply)
  ifTrue: [
   reply calls ifNotEmpty: [ self error: 'A summary must not request tools.' ].
   text := reply text ]
  ifFalse: [ text := reply ].
 (text isString and: [ text trimBoth isNotEmpty ]) ifFalse: [ self error: 'A summary must contain text.' ].
 summary := text copy.
 covered := count
]

{ #category : 'accessing' }
SmallGPTalkContext >> summary [ ^ summary copy ]

{ #category : 'configuration' }
SmallGPTalkContext >> autoCompactLimit: count [
 (count isNil or: [ count isInteger and: [ count > 0 ] ])
  ifFalse: [ self error: 'The context limit must be a positive integer or nil.' ].
 autoCompactLimit := count
]

{ #category : 'accessing' }
SmallGPTalkContext >> autoCompactLimit [ ^ autoCompactLimit ]

{ #category : 'measurement' }
SmallGPTalkContext >> usageFor: request [
 ^ autoCompactLimit ifNotNil: [ (request characterCount * 100 / autoCompactLimit) rounded ]
]

{ #category : 'testing' }
SmallGPTalkContext >> needsCompactionFor: request [
 ^ autoCompactLimit notNil and: [ (request history notEmpty or: [ request replies notEmpty ])
  and: [ request characterCount >= autoCompactLimit ] ]
]

{ #category : 'compaction' }
SmallGPTalkContext >> request: request summarizedBy: reply [
 | compacted |
 compacted := self forFork.
 compacted absorb: reply through: 0.
 ^ ((request withHistory: #()) following: #()) withContinuationSummary: compacted summary
]

{ #category : 'copying' }
SmallGPTalkContext >> forFork [
 ^ self class new autoCompactLimit: autoCompactLimit; yourself
]
