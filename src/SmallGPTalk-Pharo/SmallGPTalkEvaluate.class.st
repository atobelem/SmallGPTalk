"Prepare a local evaluation for a supplied source expression."
Class {
 #name : 'SmallGPTalkEvaluate',
 #superclass : 'Object',
 #instVars : [ 'outputLimit', 'timeoutSeconds', 'interactions' ],
 #category : 'SmallGPTalk-Pharo'
}

{ #category : 'accessing' }
SmallGPTalkEvaluate >> name [ ^ 'evaluate' ]

{ #category : 'preparing' }
SmallGPTalkEvaluate >> prepare: arguments [
 | source |
 (arguments isDictionary and: [ arguments size = 1 ])
  ifFalse: [ self error: 'Supply only the source argument.' ].
 source := arguments at: 'source' ifAbsent: [ self error: 'Supply a source expression.' ].
 source isString ifFalse: [ self error: 'The source must be text.' ].
 ^ (SmallGPTalkEvaluation source: source) reportInteractionsTo: interactions; outputLimit: outputLimit; timeoutSeconds: timeoutSeconds; yourself
]

{ #category : 'initialization' }
SmallGPTalkEvaluate >> initialize [
 super initialize.
 interactions := SmallGPTalkObservers new.
 outputLimit := 20000.
 timeoutSeconds := 10
]

{ #category : 'configuration' }
SmallGPTalkEvaluate >> outputLimit: count [
 (count isInteger and: [ count > 0 ]) ifFalse: [ self error: 'The output limit must be a positive integer.' ].
 outputLimit := count
]

{ #category : 'configuration' }
SmallGPTalkEvaluate >> timeoutSeconds: seconds [
 timeoutSeconds := (SmallGPTalkTimeLimit seconds: seconds) seconds
]

{ #category : 'execution' }
SmallGPTalkEvaluate >> during: work [
 ^ SmallGPTalkImageAccess current during: work
]

{ #category : 'description' }
SmallGPTalkEvaluate >> description [
 ^ 'Evaluate Smalltalk in the current Pharo image. Changes remain in the image. Return the result class and bounded output. The local object pharo records UI interactions: pharo browse: aClass or aCompiledMethod; pharo inspect: anObject. These return the target. Use pharo browse: (aClass >> #selector) to show a method after reading or compiling it. Follow agent opens these interactions in native tools. Without a connected view they are recorded only.'
]

{ #category : 'description' }
SmallGPTalkEvaluate >> parameters [
 ^ STONJSON fromString: '{"type":"object","properties":{"source":{"type":"string","description":"Smalltalk source to evaluate."}},"required":["source"],"additionalProperties":false}'
]

{ #category : 'interactions' }
SmallGPTalkEvaluate >> whenInteraction: observer [
 ^ interactions add: observer
]

{ #category : 'interactions' }
SmallGPTalkEvaluate >> removeInteractionObserver: observer [
 interactions remove: observer
]

{ #category : 'interactions' }
SmallGPTalkEvaluate >> interactionErrors [
 ^ interactions errors
]

{ #category : 'copying' }
SmallGPTalkEvaluate >> postCopy [
 super postCopy.
 interactions := SmallGPTalkObservers new
]
