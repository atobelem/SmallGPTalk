"Keep the model run and the independent verification for one cycle."
Class {
 #name : 'SmallGPTalkImprovementCycle',
 #superclass : 'Object',
 #instVars : [ 'run', 'verification', 'error' ],
 #category : 'SmallGPTalk-Pharo'
}

{ #category : 'accessing' }
SmallGPTalkImprovementCycle >> run [ ^ run ]

{ #category : 'initialization' }
SmallGPTalkImprovementCycle >> run: aRun [ run := aRun ]

{ #category : 'accessing' }
SmallGPTalkImprovementCycle >> verification [ ^ verification ]

{ #category : 'initialization' }
SmallGPTalkImprovementCycle >> verification: evaluation [ verification := evaluation ]

{ #category : 'accessing' }
SmallGPTalkImprovementCycle >> error [ ^ error copy ]

{ #category : 'initialization' }
SmallGPTalkImprovementCycle >> error: text [ error := text copy ]

{ #category : 'reporting' }
SmallGPTalkImprovementCycle >> report [
 ^ String streamContents: [ :stream |
  run ifNotNil: [
   stream nextPutAll: 'Previous model run: '; nextPutAll: run state asString; cr.
   run error ifNotNil: [ :text | stream nextPutAll: text; cr ] ].
  error ifNotNil: [ stream nextPutAll: error; cr ].
  verification ifNotNil: [
   stream nextPutAll: 'Independent verification: '; nextPutAll: verification state asString; cr;
    nextPutAll: verification output ] ]
]
