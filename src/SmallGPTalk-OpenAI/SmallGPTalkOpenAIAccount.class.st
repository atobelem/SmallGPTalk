"Coordinate account login, credential renewal, and sign-out through a credential store."
Class {
	#name : #SmallGPTalkOpenAIAccount,
	#superclass : #Object,
	#instVars : [ 'store', 'transport', 'coordination', 'clock', 'loginTimeoutSeconds' ],
	#category : #'SmallGPTalk-OpenAI'
}

{ #category : #initialization }
SmallGPTalkOpenAIAccount >> initialize [
	super initialize.
	self credentialStore: SmallGPTalkKeychainStore new.
	transport := SmallGPTalkOpenAIAuthTransport new.
	clock := [ DateAndTime now asUnixTime ].
	loginTimeoutSeconds := 900
]

{ #category : #accessing }
SmallGPTalkOpenAIAccount >> credentialStore: anObject [
	store := anObject.
	coordination := SmallGPTalkOpenAIAuthState forStore: store
]

{ #category : #accessing }
SmallGPTalkOpenAIAccount >> transport: anObject [
	transport := anObject
]

{ #category : #accessing }
SmallGPTalkOpenAIAccount >> transport [
	^ transport
]

{ #category : #accessing }
SmallGPTalkOpenAIAccount >> clock: aBlock [
	clock := aBlock
]

{ #category : #accessing }
SmallGPTalkOpenAIAccount >> now [
	^ clock value
]

{ #category : #accessing }
SmallGPTalkOpenAIAccount >> loginTimeoutSeconds: seconds [
	(seconds isNumber and: [ seconds > 0 ]) ifFalse: [
		SmallGPTalkOpenAIAuthError signal: 'The login timeout must be positive.' ].
	loginTimeoutSeconds := seconds
]

{ #category : #login }
SmallGPTalkOpenAIAccount >> beginLogin [
	| operation |
	operation := self newLogin.
	operation start.
	^ operation
]

{ #category : #private }
SmallGPTalkOpenAIAccount >> newLogin [
	^ coordination lock critical: [
		(coordination activeLogin notNil and: [ coordination activeLogin isActive ]) ifTrue: [
			SmallGPTalkOpenAIAuthError signal: 'A login operation is active.' ].
		coordination nextGeneration.
		coordination activeLogin: (SmallGPTalkOpenAILogin new
			account: self generation: coordination generation;
			timeoutSeconds: loginTimeoutSeconds;
			yourself).
		coordination activeLogin ]
]

{ #category : #testing }
SmallGPTalkOpenAIAccount >> isAuthenticated [
	^ coordination lock critical: [
		| record |
		record := store read.
		record notNil and: [
			(record at: 'refresh_token' ifAbsent: [ '' ]) notEmpty ] ]
]

{ #category : #credentials }
SmallGPTalkOpenAIAccount >> credentials [
	^ coordination lock critical: [
		| record |
		record := self readCredentials.
		(record at: 'expires_at') <= (self now + 60)
			ifTrue: [ self renew: record ]
			ifFalse: [ record ] ]
]

{ #category : #credentials }
SmallGPTalkOpenAIAccount >> refreshCredentials [
	^ coordination lock critical: [ self renew: self readCredentials ]
]

{ #category : #private }
SmallGPTalkOpenAIAccount >> readCredentials [
	^ store read ifNil: [
		SmallGPTalkOpenAIAuthError signal: 'Sign in to the OpenAI account.' ]
]

{ #category : #private }
SmallGPTalkOpenAIAccount >> renew: record [
	| response renewed |
	response := transport postForm: (Dictionary new
		at: 'grant_type' put: 'refresh_token';
		at: 'refresh_token' put: (record at: 'refresh_token');
		at: 'client_id' put: SmallGPTalkOpenAIAuth clientId;
		yourself).
	renewed := SmallGPTalkOpenAIAuth credentialsFrom: response previous: record now: self now.
	store write: renewed.
	^ renewed
]

{ #category : #login }
SmallGPTalkOpenAIAccount >> logout [
	| operation |
	[ coordination lock critical: [
		coordination nextGeneration.
		operation := coordination activeLogin.
		coordination activeLogin: nil.
		store delete ]
	] ensure: [ operation ifNotNil: [ operation cancel ] ].
	^ self
]

{ #category : #private }
SmallGPTalkOpenAIAccount >> completeLogin: operation credentials: record generation: expectedGeneration [
	^ coordination lock critical: [
		(coordination generation = expectedGeneration and: [ operation state = #exchanging ])
			ifFalse: [ false ]
			ifTrue: [ store write: record. operation complete. true ] ]
]

{ #category : #private }
SmallGPTalkOpenAIAccount >> cancelLogin: operation [
	coordination lock critical: [
		(operation == coordination activeLogin and: [ operation isCancellable ]) ifTrue: [
			coordination nextGeneration ].
		operation requestCancellation ]
]

{ #category : #creation }
SmallGPTalkOpenAIAccount class >> credentialStore: aStore [
	^ self new credentialStore: aStore; yourself
]

{ #category : #private }
SmallGPTalkOpenAIAccount >> releaseLogin: operation [
	coordination releaseLogin: operation
]
