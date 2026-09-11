Class {
 #name : 'BaselineOfSmallGPTalk',
 #superclass : 'BaselineOf',
 #category : 'BaselineOfSmallGPTalk'
}

{ #category : 'baselines' }
BaselineOfSmallGPTalk >> baseline: spec [
 <baseline>
 spec for: #common do: [
  spec package: 'SmallGPTalk-Core'.
  spec package: 'SmallGPTalk-Pharo' with: [ spec requires: #('SmallGPTalk-Core') ].
  spec package: 'SmallGPTalk-OpenAI' with: [ spec requires: #('SmallGPTalk-Core') ].
  spec package: 'SmallGPTalk-UI' with: [ spec requires: #('SmallGPTalk-Core' 'SmallGPTalk-Pharo') ].
  spec package: 'SmallGPTalk-Tests' with: [ spec requires: #('SmallGPTalk-Core' 'SmallGPTalk-Pharo' 'SmallGPTalk-UI' 'SmallGPTalk-OpenAI') ] ]
]
