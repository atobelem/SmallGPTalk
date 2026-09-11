"Inspect an exchange's calls, source, output, and real result objects."
Class {
 #name : 'SmallGPTalkEvaluations',
 #superclass : 'SpPresenter',
 #instVars : [ 'exchange', 'calls', 'source', 'output', 'inspectValue', 'inspectCall', 'inspectContext', 'refresh', 'interactions', 'openInteraction' ],
 #category : 'SmallGPTalk-UI'
}

{ #category : 'instance creation' }
SmallGPTalkEvaluations class >> forExchange: anExchange [
 ^ self new useExchange: anExchange; yourself
]

{ #category : 'initialization' }
SmallGPTalkEvaluations >> initializePresenters [
 interactions := self newList display: [ :interaction | interaction label ]; yourself.
 openInteraction := self newButton label: 'Open interaction'; enabled: false; action: [ self selectedInteraction ifNotNil: #open ]; yourself.
 interactions whenSelectionChangedDo: [ openInteraction enabled: self selectedInteraction notNil ].
 calls := self newList display: [ :call | call id, ' — ', call state asString ]; yourself.
 calls whenSelectionChangedDo: [ self showSelection ].
 source := self newCode beNotEditable.
 output := self newText beNotEditable.
 inspectValue := self newButton label: 'Inspect value'; action: [ self selectedCall ifNotNil: [ :call | call result inspect ] ]; yourself.
 inspectCall := self newButton label: 'Inspect call'; action: [ self selectedCall ifNotNil: #inspect ]; yourself.
 inspectContext := self newButton label: 'Inspect context'; action: [ self selectedContext ifNotNil: #inspect ]; yourself.
 refresh := self newButton label: 'Refresh'; action: [ self refresh ]; yourself
]

{ #category : 'layout' }
SmallGPTalkEvaluations >> defaultLayout [
 ^ SpBoxLayout newVertical spacing: 6;
  add: calls height: 100;
  add: (self newLabel label: 'Interactions') expand: false;
  add: interactions height: 70;
  add: openInteraction height: 28;
  add: (self newLabel label: 'Source') expand: false;
  add: source;
  add: (self newLabel label: 'Output') expand: false;
  add: output;
  add: (SpBoxLayout newHorizontal add: inspectValue; add: inspectCall; add: inspectContext; add: refresh; yourself) height: 30;
  yourself
]

{ #category : 'initialization' }
SmallGPTalkEvaluations >> initializeWindow: window [
 super initializeWindow: window.
 window title: 'SmallGPTalk evaluations'; initialExtent: 700 @ 620
]

{ #category : 'configuration' }
SmallGPTalkEvaluations >> useExchange: anExchange [ exchange := anExchange. self refresh ]

{ #category : 'updating' }
SmallGPTalkEvaluations >> refresh [
 | selected index |
 selected := self selectedCall.
 calls items: exchange calls.
 calls items ifNotEmpty: [
  index := calls items identityIndexOf: selected.
  calls selectIndex: (index max: 1) ].
 self showSelection
]

{ #category : 'accessing' }
SmallGPTalkEvaluations >> selectedCall [ ^ calls selectedItem ]

{ #category : 'accessing' }
SmallGPTalkEvaluations >> selectedContext [
 ^ self selectedCall ifNotNil: [ :call | exchange contextForCall: call ]
]

{ #category : 'accessing' }
SmallGPTalkEvaluations >> sourceText [ ^ source text ]

{ #category : 'accessing' }
SmallGPTalkEvaluations >> outputText [ ^ output text ]

{ #category : 'updating' }
SmallGPTalkEvaluations >> showSelection [
 | call arguments text |
 call := self selectedCall.
 interactions items: ((call notNil and: [ call operation notNil and: [ call operation respondsTo: #interactions ] ])
  ifTrue: [ call operation interactions ] ifFalse: [ #() ]).
 interactions items ifNotEmpty: [ interactions selectIndex: 1 ].
 inspectValue enabled: (call notNil and: [ call operation notNil ]).
 inspectCall enabled: call notNil.
 inspectContext enabled: call notNil.
 call ifNil: [ source text: ''. output text: ''. ^ self ].
 arguments := call arguments.
 text := arguments isDictionary ifTrue: [ arguments at: 'source' ifAbsent: [ '' ] ] ifFalse: [ '' ].
 source text: (text isString ifTrue: [ text ] ifFalse: [ '' ]).
 output text: (call operation ifNil: [ call error ifNil: [ call state asString ] ] ifNotNil: [ :operation | operation output ])
]

{ #category : 'interactions' }
SmallGPTalkEvaluations >> selectedInteraction [
 ^ interactions selectedItem
]
