"Choose a model and effort from supplied descriptions before applying them."
Class {
 #name : 'SmallGPTalkModelSelector',
 #superclass : 'SpPresenter',
 #instVars : [ 'models', 'efforts', 'apply', 'choose' ],
 #category : 'SmallGPTalk-UI'
}

{ #category : 'initialization' }
SmallGPTalkModelSelector >> initializePresenters [
 models := self newDropList display: [ :description | description identifier ]; yourself.
 efforts := self newDropList.
 apply := self newButton label: 'Use model'; action: [ self applySelection ]; yourself.
 models whenSelectedItemChangedDo: [ self updateEfforts ].
 efforts whenSelectedItemChangedDo: [ self updateApply ].
 self updateApply
]

{ #category : 'layout' }
SmallGPTalkModelSelector >> defaultLayout [
 ^ SpBoxLayout newHorizontal spacing: 6;
  add: (self newLabel label: 'Model') width: 45;
  add: models;
  add: (self newLabel label: 'Effort') width: 40;
  add: efforts width: 100;
  add: apply width: 100; yourself
]

{ #category : 'configuration' }
SmallGPTalkModelSelector >> models: descriptions [
 models selectItem: nil.
 models items: descriptions.
 self updateEfforts
]

{ #category : 'configuration' }
SmallGPTalkModelSelector >> onChoose: aBlock [ choose := aBlock ]

{ #category : 'selection' }
SmallGPTalkModelSelector >> selectModel: identifier effort: level [
 models selectItem: (models items detect: [ :each | each identifier = identifier ] ifNone: [ nil ]).
 efforts selectItem: ((self availableEfforts includes: level) ifTrue: [ level ] ifFalse: [ nil ])
]

{ #category : 'updating' }
SmallGPTalkModelSelector >> updateEfforts [
 efforts selectItem: nil.
 efforts items: (models selectedItem ifNil: [ #() ] ifNotNil: [ :model | model efforts ]).
 (self availableEfforts includes: 'low') ifTrue: [ efforts selectItem: 'low' ].
 self updateApply
]

{ #category : 'updating' }
SmallGPTalkModelSelector >> updateApply [
 apply enabled: (models selectedItem notNil and: [ efforts selectedItem notNil ])
]

{ #category : 'accessing' }
SmallGPTalkModelSelector >> availableEfforts [ ^ efforts items asArray ]

{ #category : 'actions' }
SmallGPTalkModelSelector >> applySelection [
 (models selectedItem notNil and: [ efforts selectedItem notNil ]) ifTrue: [
  choose value: models selectedItem identifier value: efforts selectedItem ]
]
