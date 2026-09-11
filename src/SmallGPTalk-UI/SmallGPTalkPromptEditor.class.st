"Edit a draft and apply it to the session's agent on Save."
Class {
 #name : 'SmallGPTalkPromptEditor',
 #superclass : 'SpPresenter',
 #instVars : [ 'session', 'input', 'save', 'status', 'saved' ],
 #category : 'SmallGPTalk-UI'
}

{ #category : 'instance creation' }
SmallGPTalkPromptEditor class >> forSession: aSession [
 ^ self new useSession: aSession; yourself
]

{ #category : 'initialization' }
SmallGPTalkPromptEditor >> initializePresenters [
 input := self newText.
 status := self newLabel.
 save := self newButton label: 'Save'; action: [ self save ]; yourself.
 saved := [ ].
 input whenTextChangedDo: [ status label: 'Unsaved changes.' ]
]

{ #category : 'configuration' }
SmallGPTalkPromptEditor >> useSession: aSession [
 session := aSession.
 input text: (session agent ifNil: [ '' ] ifNotNil: [ :agent | agent instructions ]).
 status label: 'Changes apply to future requests.'
]

{ #category : 'configuration' }
SmallGPTalkPromptEditor >> whenSaved: aBlock [ saved := aBlock ]

{ #category : 'layout' }
SmallGPTalkPromptEditor >> defaultLayout [
 ^ SpBoxLayout newVertical spacing: 8; borderWidth: 8;
  add: input;
  add: (SpBoxLayout newHorizontal spacing: 8;
   add: status; add: save width: 90; yourself) height: 30;
  yourself
]

{ #category : 'initialization' }
SmallGPTalkPromptEditor >> initializeWindow: window [
 super initializeWindow: window.
 window title: 'System prompt'; initialExtent: 720 @ 400
]

{ #category : 'accessing' }
SmallGPTalkPromptEditor >> text [ ^ input text asString ]

{ #category : 'configuration' }
SmallGPTalkPromptEditor >> text: text [ input text: text ]

{ #category : 'actions' }
SmallGPTalkPromptEditor >> save [
 session agent ifNil: [ session useAgent: SmallGPTalkAgent new ].
 session agent instructions: self text.
 status label: 'Saved. Applies to future requests.'.
 saved value
]
