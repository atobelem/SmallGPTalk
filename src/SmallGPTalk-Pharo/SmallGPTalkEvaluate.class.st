"Prepare a local evaluation for a supplied source expression."
Class {
 #name : 'SmallGPTalkEvaluate',
 #superclass : 'Object',
 #instVars : [ 'outputLimit', 'timeoutSeconds' ],
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
 ^ (SmallGPTalkEvaluation source: source) outputLimit: outputLimit; timeoutSeconds: timeoutSeconds; yourself
]

{ #category : 'initialization' }
SmallGPTalkEvaluate >> initialize [
 super initialize.
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
 ^ 'Evaluate Smalltalk in the current Pharo image. Changes remain in the image. Return the result class and bounded output.'
]

{ #category : 'description' }
SmallGPTalkEvaluate >> parameters [
 ^ STONJSON fromString: '{"type":"object","properties":{"source":{"type":"string","description":"Smalltalk source to evaluate."}},"required":["source"],"additionalProperties":false}'
]
