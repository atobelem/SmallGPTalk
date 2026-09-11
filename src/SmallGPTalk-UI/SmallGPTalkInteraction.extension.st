Extension { #name : 'SmallGPTalkInteraction' }

{ #category : '*SmallGPTalk-UI' }
SmallGPTalkInteraction >> open [
 self kind = #browse ifTrue: [ ^ self target browse ].
 self kind = #inspect ifTrue: [ ^ (Smalltalk tools toolNamed: #inspector) inspect: self target ].
 self error: 'Unknown interaction.'
]
