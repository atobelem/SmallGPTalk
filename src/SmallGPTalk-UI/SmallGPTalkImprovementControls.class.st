"Observe continuous improvement without owning its execution."
Class {
 #name : 'SmallGPTalkImprovementControls',
 #superclass : 'SpPresenter',
 #instVars : [ 'improvement', 'observer', 'start', 'stop', 'inspect', 'status' ],
 #category : 'SmallGPTalk-UI'
}

{ #category : 'initialization' }
SmallGPTalkImprovementControls >> initializePresenters [
 start := self newButton label: 'Start improvement'; action: [ self startImprovement ]; yourself.
 stop := self newButton label: 'Stop improvement'; action: [ self stopImprovement ]; yourself.
 inspect := self newButton label: 'Inspect improvement'; action: [ improvement ifNotNil: #inspect ]; yourself.
 status := self newLabel
]

{ #category : 'layout' }
SmallGPTalkImprovementControls >> defaultLayout [
 ^ SpBoxLayout newVertical
  add: (SpBoxLayout newHorizontal add: start; add: stop; add: inspect; yourself) height: 30;
  add: status;
  yourself
]

{ #category : 'connection' }
SmallGPTalkImprovementControls >> connectTo: controller [
 | subscription |
 self disconnect.
 improvement := controller.
 subscription := improvement whenChanged: [ :job |
  self application defer: [
   observer == subscription ifTrue: [ self refresh ] ] ].
 observer := subscription.
 self refresh
]

{ #category : 'connection' }
SmallGPTalkImprovementControls >> disconnect [
 observer ifNotNil: [ improvement removeObserver: observer. observer := nil ]
]

{ #category : 'actions' }
SmallGPTalkImprovementControls >> startImprovement [
 self performAction: [ improvement start ]
]

{ #category : 'actions' }
SmallGPTalkImprovementControls >> stopImprovement [
 self performAction: [ improvement stop ]
]

{ #category : 'private' }
SmallGPTalkImprovementControls >> performAction: block [
 [ block value. self refresh ]
  on: Error , Halt do: [ :error | status label: error messageText ]
]

{ #category : 'updating' }
SmallGPTalkImprovementControls >> refresh [
 improvement ifNil: [ ^ self ].
 status label: 'Improvement: ', improvement state asString,
  '. Cycles started: ', improvement cycles size asString, '.'
]

{ #category : 'accessing' }
SmallGPTalkImprovementControls >> statusText [ ^ status label ]
