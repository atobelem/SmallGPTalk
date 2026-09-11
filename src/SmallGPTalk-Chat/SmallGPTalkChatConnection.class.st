"Coordinate account operations without a dependency on widgets."
Class {
	#name : 'SmallGPTalkChatConnection',
	#superclass : 'Object',
	#instVars : [ 'account', 'provider', 'login', 'state', 'cancelRequested' ],
	#category : 'SmallGPTalk-Chat',
	#package : 'SmallGPTalk-Chat'
}

{ #category : 'initialization' }
SmallGPTalkChatConnection >> initialize [
	super initialize.
	account := SmallGPTalkOpenAIAccount new.
	provider := SmallGPTalkOpenAIProvider account: account.
	state := #idle.
	cancelRequested := false
]

{ #category : 'accessing' }
SmallGPTalkChatConnection >> provider [
	^ provider
]

{ #category : 'accessing' }
SmallGPTalkChatConnection >> account: anAccount provider: aProvider [
	state = #idle ifFalse: [ self error: 'Wait for the account operation to stop.' ].
	account := anAccount.
	provider := aProvider
]

{ #category : 'accessing' }
SmallGPTalkChatConnection >> state [
	^ state
]

{ #category : 'private' }
SmallGPTalkChatConnection >> perform: operation onEvent: observer [
	state = #idle ifFalse: [ self error: 'An account operation is already active.' ].
	state := #working.
	cancelRequested := false.
	[
		[
			[ operation value: observer ] on: Error do: [ :error |
				observer value: (Dictionary new at: #type put: #failed;
					at: #error put: (SmallGPTalkFailure fromException: error); yourself) ]
		] ensure: [ login := nil. state := #idle ]
	] forkAt: Processor userBackgroundPriority
]

{ #category : 'private' }
SmallGPTalkChatConnection >> checkCancellation [
	cancelRequested ifTrue: [ SmallGPTalkCancelled signal: 'Connection cancelled.' ]
]

{ #category : 'actions' }
SmallGPTalkChatConnection >> connectOnEvent: observer [
	self perform: [ :events |
		| catalog |
		account isAuthenticated ifFalse: [
			self checkCancellation.
			login := account beginLogin.
			cancelRequested ifTrue: [ login cancel ].
			self checkCancellation.
			events value: (Dictionary new at: #type put: #authorization;
				at: #url put: login authorizationUrl; yourself).
			login wait.
			login state = #completed ifFalse: [
				self error: (login error ifNil: [ 'Login stopped.' ] ifNotNil: [ :error | error messageText ]) ] ].
		self checkCancellation.
		events value: (Dictionary new at: #type put: #loadingModels; yourself).
		catalog := provider modelOptions.
		self checkCancellation.
		events value: (Dictionary new at: #type put: #connected; at: #models put: catalog; yourself)
	] onEvent: observer
]

{ #category : 'actions' }
SmallGPTalkChatConnection >> logoutOnEvent: observer [
	self perform: [ :events |
		account logout.
		events value: (Dictionary new at: #type put: #signedOut; yourself)
	] onEvent: observer
]

{ #category : 'actions' }
SmallGPTalkChatConnection >> cancel [
	cancelRequested := true.
	login ifNotNil: [ login cancel ]
]
