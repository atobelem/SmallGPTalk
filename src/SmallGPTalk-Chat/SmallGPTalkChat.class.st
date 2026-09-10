"A chat window for the SmallGPTalk API. Network work runs outside the UI process."
Class {
	#name : 'SmallGPTalkChat',
	#superclass : 'SpPresenter',
	#instVars : [ 'account', 'provider', 'session', 'run', 'login', 'busy', 'closed', 'history', 'input', 'models', 'effort', 'modelOptions', 'status', 'connectButton', 'logoutButton', 'sendButton', 'stopButton', 'newButton' ],
	#category : 'SmallGPTalk-Chat',
	#package : 'SmallGPTalk-Chat'
}

{ #category : 'initialization' }
SmallGPTalkChat >> initializePresenters [
	busy := false.
	closed := false.
	account := SmallGPTalkOpenAIAccount new.
	provider := SmallGPTalkOpenAIProvider account: account.
	history := self newText beNotEditable; yourself.
	input := self newText.
	models := self newDropList startWithoutSelection; yourself.
	modelOptions := #().
	effort := self newDropList startWithoutSelection; items: #('medium'); selectFirst; yourself.
	status := self newLabel label: 'Connect to load your models.'; yourself.
	connectButton := self newButton label: 'Connect'; action: [ self connect ]; yourself.
	logoutButton := self newButton label: 'Sign out'; action: [ self logout ]; yourself.
	sendButton := self newButton label: 'Send'; action: [ self send ]; yourself.
	stopButton := self newButton label: 'Stop'; action: [ self stop ]; yourself.
	newButton := self newButton label: 'New chat'; action: [ self newChat ]; yourself.
	self updateControls
]

{ #category : 'layout' }
SmallGPTalkChat >> defaultLayout [
	^ SpBoxLayout newTopToBottom
		spacing: 8;
		add: (SpBoxLayout newLeftToRight spacing: 8;
			add: connectButton; add: logoutButton; add: newButton; yourself) height: 32;
		add: (self newLabel label: 'Model') height: 20;
		add: models height: 32;
		add: (self newLabel label: 'Reasoning effort') height: 20;
		add: effort height: 32;
		add: (self newLabel label: 'Evaluate is enabled. It can change this image. Changes remain after Stop.') height: 24;
		add: history;
		add: input height: 110;
		add: (SpBoxLayout newLeftToRight spacing: 8;
			add: sendButton; add: stopButton; yourself) height: 32;
		add: status height: 26;
		yourself
]

{ #category : 'initialization' }
SmallGPTalkChat >> initializeWindow: aWindow [
	aWindow title: 'SmallGPTalk Chat'; initialExtent: 760 @ 720.
	aWindow whenClosedDo: [ self closeChat ]
]

{ #category : 'private' }
SmallGPTalkChat >> onUI: aBlock [
	UIManager default defer: [ closed ifFalse: aBlock ]
]

{ #category : 'private' }
SmallGPTalkChat >> append: aString [
	history text: history text asString, aString
]

{ #category : 'private' }
SmallGPTalkChat >> updateControls [
	connectButton enabled: busy not.
	logoutButton enabled: busy not.
	newButton enabled: busy not.
	models enabled: (busy not and: [ session isNil ]).
	effort enabled: (busy not and: [ session isNil ]).
	sendButton enabled: (busy not and: [ models selectedItem isNotNil and: [ effort selectedItem isNotNil ] ]).
	stopButton enabled: busy
]

{ #category : 'private' }
SmallGPTalkChat >> setBusy: aBoolean status: aString [
	busy := aBoolean.
	status label: aString.
	self updateControls
]

{ #category : 'initialization' }
SmallGPTalkChat >> connectPresenters [
	models whenSelectedItemChangedDo: [ self selectModel ].
	effort whenSelectedItemChangedDo: [ self updateControls ]
]

{ #category : 'actions' }
SmallGPTalkChat >> connect [
	busy ifTrue: [ ^ self ].
	self setBusy: true status: 'Connect in your browser. Wait for the model list.'.
	[
		[
			account isAuthenticated ifFalse: [
				login := account beginLogin.
				closed ifTrue: [ login cancel ].
				closed ifFalse: [ WebBrowser openOn: login authorizationUrl ].
				login wait.
				login state = #completed ifFalse: [
					self error: (login error ifNil: [ 'Login stopped.' ] ifNotNil: [ :error | error messageText ]) ] ].
			closed ifFalse: [
				| catalog |
				catalog := provider modelOptions.
				self onUI: [
					self installModelOptions: catalog ] ]
		] on: Error do: [ :error |
			| message |
			message := error messageText copy.
			self onUI: [ self setBusy: false status: message ] ].
		login := nil
	] forkAt: Processor userBackgroundPriority
]

{ #category : 'actions' }
SmallGPTalkChat >> logout [
	busy ifTrue: [ ^ self ].
	self setBusy: true status: 'Sign out...'.
	[
		[ account logout.
			self onUI: [
				self clearConversation.
				models items: #().
				self setBusy: false status: 'Signed out.' ]
		] on: Error do: [ :error |
			| message |
			message := error messageText copy.
			self onUI: [ self setBusy: false status: message ] ]
	] forkAt: Processor userBackgroundPriority
]

{ #category : 'actions' }
SmallGPTalkChat >> newChat [
	busy ifTrue: [ ^ self ].
	self clearConversation.
	self updateControls.
	status label: 'Select a model. Enter a message.'
]

{ #category : 'private' }
SmallGPTalkChat >> clearConversation [
	session := nil.
	run := nil.
	history text: ''.
	input text: ''
]

{ #category : 'actions' }
SmallGPTalkChat >> send [
	| text |
	busy ifTrue: [ ^ self ].
	text := input text asString trimBoth.
	text isEmpty ifTrue: [ ^ self ].
	models selectedItem ifNil: [ status label: 'Select a model.' . ^ self ].
	effort selectedItem ifNil: [ status label: 'Select a reasoning effort.'. ^ self ].
	session ifNil: [
		provider reasoningEffort: effort selectedItem.
		session := SmallGPTalkSession new
			provider: provider;
			model: models selectedItem;
			tools: SmallGPTalkImageTools all;
			yourself ].
	self append: 'You:', String cr, text, String cr, String cr, 'Assistant:', String cr.
	input text: ''.
	self setBusy: true status: 'Running...'.
	[ run := session send: text onEvent: [ :event | self onUI: [ self receiveEvent: event ] ] ]
		on: Error do: [ :error |
			input text: text.
			self append: String cr, '[Request did not start.]', String cr.
			self setBusy: false status: error messageText ]
]

{ #category : 'events' }
SmallGPTalkChat >> receiveEvent: event [
	| type |
	type := event at: #type.
	type = #text ifTrue: [ self append: (event at: #text) ].
	type = #toolStarted ifTrue: [
		self append: String cr, '[Tool: ', (event at: #call) name, ']', String cr ].
	type = #toolResult ifTrue: [
		self append: (event at: #result) text, String cr ].
	type = #finished ifTrue: [
		self append: String cr, '[', (event at: #state) asString, ']', String cr, String cr.
		self setBusy: false status: ((event at: #error)
			ifNil: [ 'Ready.' ] ifNotNil: [ :error | error messageText ]) ]
]

{ #category : 'actions' }
SmallGPTalkChat >> stop [
	login ifNotNil: [ login cancel ].
	run ifNotNil: [ run cancel ].
	busy ifTrue: [ status label: 'Stopping. Wait for the operation to stop.' ]
]

{ #category : 'actions' }
SmallGPTalkChat >> closeChat [
	closed := true.
	self stop
]

{ #category : 'private' }
SmallGPTalkChat >> installModelOptions: catalog [
	self clearConversation.
	modelOptions := catalog.
	models items: (catalog collect: [ :item | item at: 'slug' ]).
	(models items includes: 'gpt-5.6-luna') ifTrue: [ models selectItem: 'gpt-5.6-luna' ].
	self setBusy: false status: (models selectedItem
		ifNil: [ 'The default model is not available. Select a model.' ]
		ifNotNil: [ 'Ready. Enter a message.' ])
]

{ #category : 'private' }
SmallGPTalkChat >> selectModel [
	| option levels |
	option := modelOptions detect: [ :item | (item at: 'slug') = models selectedItem ] ifNone: [ nil ].
	option ifNotNil: [
		levels := (option at: 'supported_reasoning_levels' ifAbsent: [ #() ]) collect: [ :item | item at: 'effort' ].
		effort items: levels.
		(levels includes: 'medium') ifTrue: [ effort selectItem: 'medium' ] ].
	self updateControls
]
