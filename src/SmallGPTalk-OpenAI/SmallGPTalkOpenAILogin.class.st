"Track one cancellable browser login operation through callback and token exchange."
Class {
	#name : #SmallGPTalkOpenAILogin,
	#superclass : #Object,
	#instVars : [ 'account', 'generation', 'authorizationUrl', 'verifier', 'oauthState', 'authorizationCode', 'state', 'error', 'lock', 'callback', 'done', 'worker', 'server', 'timeoutSeconds' ],
	#category : #'SmallGPTalk-OpenAI'
}

{ #category : #initialization }
SmallGPTalkOpenAILogin >> initialize [
	super initialize.
	lock := Mutex new.
	callback := Semaphore new.
	done := Semaphore new.
	state := #ready.
	timeoutSeconds := 900
]

{ #category : #initialization }
SmallGPTalkOpenAILogin >> account: anAccount generation: anInteger [
	account := anAccount.
	generation := anInteger
]

{ #category : #accessing }
SmallGPTalkOpenAILogin >> timeoutSeconds: seconds [
	timeoutSeconds := seconds
]

{ #category : #accessing }
SmallGPTalkOpenAILogin >> authorizationUrl [
	^ authorizationUrl
]

{ #category : #accessing }
SmallGPTalkOpenAILogin >> state [
	^ state
]

{ #category : 'error handling' }
SmallGPTalkOpenAILogin >> error [
	^ error
]

{ #category : #testing }
SmallGPTalkOpenAILogin >> isActive [
	^ #(ready waiting exchanging finishing failing cancelling) includes: state
]

{ #category : #running }
SmallGPTalkOpenAILogin >> start [
	state = #ready ifFalse: [
		SmallGPTalkOpenAIAuthError signal: 'The login operation has started.' ].
	[
		self prepare.
		server := SmallGPTalkOpenAIAuthServer on: 1455.
		server bindingAddress: #[127 0 0 1]; delegate: self; start.
		worker := [ [
			[ [ self awaitCallback ]
				valueWithinMilliseconds: (timeoutSeconds * 1000) rounded
				onTimeout: [ SmallGPTalkOpenAIAuthError signal: 'The login time limit expired.' ]
			] on: Error do: [ :exception | self fail: exception ]
		] ensure: [ self finish ] ]
			forkAt: Processor userBackgroundPriority named: 'SmallGPTalk account login'
	] on: Error do: [ :exception | self fail: exception. self finish ].
	^ self
]

{ #category : #private }
SmallGPTalkOpenAILogin >> prepare [
	verifier := SmallGPTalkOpenAIAuth base64Url: (SmallGPTalkSecureRandom bytes: 32).
	oauthState := SmallGPTalkOpenAIAuth base64Url: (SmallGPTalkSecureRandom bytes: 32).
	authorizationUrl := SmallGPTalkOpenAIAuth authorizationUrlFor: verifier state: oauthState.
	state := #waiting
]

{ #category : #private }
SmallGPTalkOpenAILogin >> awaitCallback [
	(callback waitTimeoutSeconds: timeoutSeconds) ifTrue: [
		SmallGPTalkOpenAIAuthError signal: 'The login time limit expired.' ].
	lock critical: [
		state = #waiting ifFalse: [ ^ self ].
		state := #exchanging ].
	self exchangeCode
]

{ #category : #private }
SmallGPTalkOpenAILogin >> exchangeCode [
	| response record |
	response := account transport postForm: (Dictionary new
		at: 'grant_type' put: 'authorization_code';
		at: 'client_id' put: SmallGPTalkOpenAIAuth clientId;
		at: 'code' put: authorizationCode;
		at: 'code_verifier' put: verifier;
		at: 'redirect_uri' put: SmallGPTalkOpenAIAuth redirectUri;
		yourself).
	record := SmallGPTalkOpenAIAuth credentialsFrom: response previous: nil now: account now.
	(account completeLogin: self credentials: record generation: generation)
		ifFalse: [ self requestCancellation ]
]

{ #category : #callbacks }
SmallGPTalkOpenAILogin >> handleRequest: request [
	| url code |
	url := request uri.
	(request method = #GET and: [ url path = 'auth/callback' ]) ifFalse: [
		^ self responseCode: 404 text: 'The callback route is not available.' ].
	(url queryAt: 'state' ifAbsent: [ nil ]) = oauthState ifFalse: [
		^ self responseCode: 400 text: 'The login state does not match.' ].
	(url queryAt: 'error' ifAbsent: [ nil ]) ifNotNil: [
		^ lock critical: [
			(state = #waiting and: [ authorizationCode isNil ])
				ifFalse: [ self responseCode: 409 text: 'This login callback is closed.' ]
				ifTrue: [
					self fail: (SmallGPTalkOpenAIAuthError new messageText: 'The account login was refused.').
					callback signal.
					self responseCode: 400 text: 'The account login was refused.' ] ] ].
	code := url queryAt: 'code' ifAbsent: [ nil ].
	(code isString and: [ code notEmpty ]) ifFalse: [
		^ self responseCode: 400 text: 'The callback has no authorization code.' ].
	^ lock critical: [
		(state = #waiting and: [ authorizationCode isNil ])
			ifFalse: [ self responseCode: 409 text: 'This login callback is closed.' ]
			ifTrue: [
				authorizationCode := code.
				callback signal.
				self responseCode: 200 text: 'The login code was received. Return to Pharo.' ] ]
]

{ #category : #callbacks }
SmallGPTalkOpenAILogin >> responseCode: code text: text [
	^ (ZnResponse statusCode: code)
		entity: (ZnEntity text: text);
		setConnectionClose;
		yourself
]

{ #category : #callbacks }
SmallGPTalkOpenAILogin >> callbackServerFailed [
	self fail: (SmallGPTalkOpenAIAuthError new messageText: 'The login callback server stopped.').
	callback signal
]

{ #category : #running }
SmallGPTalkOpenAILogin >> wait [
	done wait.
	done signal.
	^ self
]

{ #category : #running }
SmallGPTalkOpenAILogin >> cancel [
	account cancelLogin: self.
	state = #cancelling ifTrue: [
		worker ifNotNil: [ worker terminate ].
		self finish ].
	^ self
]

{ #category : #private }
SmallGPTalkOpenAILogin >> requestCancellation [
	lock critical: [ self isCancellable ifTrue: [ state := #cancelling ] ].
	callback signal
]

{ #category : #private }
SmallGPTalkOpenAILogin >> complete [
	lock critical: [ state := #finishing ]
]

{ #category : #private }
SmallGPTalkOpenAILogin >> fail: exception [
	lock critical: [
		(#(ready waiting exchanging) includes: state) ifTrue: [
			error := SmallGPTalkOpenAIAuthError new messageText:
				((exception isKindOf: SmallGPTalkOpenAIAuthError)
					ifTrue: [ exception messageText ]
					ifFalse: [ 'The account login failed.' ]).
			state := #failing ] ]
]

{ #category : #private }
SmallGPTalkOpenAILogin >> finish [
	server ifNotNil: [ server stop. server := nil ].
	verifier := nil.
	oauthState := nil.
	authorizationCode := nil.
	lock critical: [
		state = #cancelling ifTrue: [ state := #cancelled ].
		state = #finishing ifTrue: [ state := #completed ].
		state = #failing ifTrue: [ state := #failed ] ].
	account releaseLogin: self.
	done signal
]

{ #category : #testing }
SmallGPTalkOpenAILogin >> isCancellable [
	^ #(ready waiting exchanging cancelling) includes: state
]
