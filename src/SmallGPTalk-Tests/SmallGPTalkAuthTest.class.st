Class {
	#name : #SmallGPTalkAuthTest,
	#superclass : #TestCase,
	#instVars : [ 'store', 'account', 'transport', 'login' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : #running }
SmallGPTalkAuthTest >> setUp [
	super setUp.
	store := SmallGPTalkAuthMemoryStore new.
	transport := SmallGPTalkAuthTestTransport new response: self tokenResponse; yourself.
	account := SmallGPTalkOpenAIAccount credentialStore: store.
	account clock: [ 1000 ]; transport: transport
]

{ #category : #running }
SmallGPTalkAuthTest >> tearDown [
	login ifNotNil: [ login cancel ].
	super tearDown
]

{ #category : #fixtures }
SmallGPTalkAuthTest >> token [
	^ 'test.', (SmallGPTalkOpenAIAuth base64Url:
		'{"https://api.openai.com/auth":{"chatgpt_account_id":"test-account"}}' utf8Encoded), '.test'
]

{ #category : #fixtures }
SmallGPTalkAuthTest >> tokenResponse [
	^ Dictionary new
		at: 'access_token' put: self token;
		at: 'refresh_token' put: 'test-refresh';
		at: 'expires_in' put: 3600;
		yourself
]

{ #category : #fixtures }
SmallGPTalkAuthTest >> credentials [
	^ SmallGPTalkOpenAIAuth credentialsFrom: self tokenResponse previous: nil now: 1000
]

{ #category : #fixtures }
SmallGPTalkAuthTest >> prepareLogin [
	login := account newLogin.
	login prepare
]

{ #category : #fixtures }
SmallGPTalkAuthTest >> callbackWithState: state code: code [
	| url |
	url := SmallGPTalkOpenAIAuth redirectUri asZnUrl.
	state ifNotNil: [ url queryAt: 'state' put: state ].
	code ifNotNil: [ url queryAt: 'code' put: code ].
	^ ZnRequest get: url
]

{ #category : #fixtures }
SmallGPTalkAuthTest >> correctState [
	^ login authorizationUrl asZnUrl queryAt: 'state'
]

{ #category : #tests }
SmallGPTalkAuthTest >> testPkceStandardVector [
	self assert: (SmallGPTalkOpenAIAuth challengeFor:
		'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk')
		equals: 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM'
]

{ #category : #tests }
SmallGPTalkAuthTest >> testBase64UrlRoundTrip [
	| bytes encoded |
	bytes := #[251 255 254 0 1].
	encoded := SmallGPTalkOpenAIAuth base64Url: bytes.
	self deny: (encoded includes: $=).
	self deny: (encoded includes: $+).
	self assert: (SmallGPTalkOpenAIAuth decodeBase64Url: encoded) equals: bytes
]

{ #category : #tests }
SmallGPTalkAuthTest >> testAuthorizationUrl [
	| url |
	self prepareLogin.
	url := login authorizationUrl asZnUrl.
	self assert: (url queryAt: 'code_challenge_method') equals: 'S256'.
	self assert: (url queryAt: 'redirect_uri') equals: SmallGPTalkOpenAIAuth redirectUri.
	self assert: (url queryAt: 'state') size equals: 43.
	self assert: (url queryAt: 'client_id') equals: SmallGPTalkOpenAIAuth clientId.
	self assert: (url queryAt: 'code_verifier' ifAbsent: [ nil ]) isNil
]

{ #category : #tests }
SmallGPTalkAuthTest >> testStoredLoginSurvivesNewAccount [
	store write: self credentials.
	self assert: (SmallGPTalkOpenAIAccount credentialStore: store) isAuthenticated
]

{ #category : #tests }
SmallGPTalkAuthTest >> testValidCredentialsDoNotRenew [
	store write: self credentials.
	self assert: account credentials equals: self credentials.
	self assert: transport requests isEmpty
]

{ #category : #tests }
SmallGPTalkAuthTest >> testExpiryRenewsAndSaves [
	| expired renewed |
	expired := self credentials at: 'expires_at' put: 1060; yourself.
	store write: expired.
	renewed := account credentials.
	self assert: (renewed at: 'expires_at') equals: 4600.
	self assert: store read equals: renewed.
	self assert: transport requests size equals: 1.
	self assert: (transport requests first at: 'grant_type') equals: 'refresh_token'
]

{ #category : #tests }
SmallGPTalkAuthTest >> testRenewKeepsRefreshWhenResponseOmitsIt [
	store write: self credentials.
	transport response: (self tokenResponse removeKey: 'refresh_token'; yourself).
	self assert: (account refreshCredentials at: 'refresh_token') equals: 'test-refresh'
]

{ #category : #tests }
SmallGPTalkAuthTest >> testInvalidRenewDoesNotReplaceStoredCredentials [
	store write: self credentials.
	transport response: Dictionary new.
	self should: [ account refreshCredentials ] raise: SmallGPTalkOpenAIAuthError.
	self assert: store read equals: self credentials
]

{ #category : #tests }
SmallGPTalkAuthTest >> testLogoutDeletesStoredCredentials [
	store write: self credentials.
	account logout.
	self deny: account isAuthenticated.
	self should: [ account credentials ] raise: SmallGPTalkOpenAIAuthError
]

{ #category : #tests }
SmallGPTalkAuthTest >> testCallbackRejectsWrongState [
	self prepareLogin.
	self assert: (login handleRequest: (self callbackWithState: 'wrong' code: 'test-code')) code equals: 400.
	self assert: login state equals: #waiting.
	self assert: transport requests isEmpty
]

{ #category : #tests }
SmallGPTalkAuthTest >> testCallbackRequiresCode [
	self prepareLogin.
	self assert: (login handleRequest: (self callbackWithState: self correctState code: nil)) code equals: 400.
	self assert: login state equals: #waiting
]

{ #category : #tests }
SmallGPTalkAuthTest >> testCallbackCannotRunTwice [
	| request |
	self prepareLogin.
	request := self callbackWithState: self correctState code: 'test-code'.
	self assert: (login handleRequest: request) code equals: 200.
	self assert: (login handleRequest: request) code equals: 409.
	login awaitCallback; finish; wait.
	self assert: login state equals: #completed.
	self assert: transport requests size equals: 1.
	self assert: account isAuthenticated
]

{ #category : #tests }
SmallGPTalkAuthTest >> testCancelledLoginCannotAcceptCode [
	| request |
	self prepareLogin.
	request := self callbackWithState: self correctState code: 'test-code'.
	login cancel; wait.
	self assert: login state equals: #cancelled.
	self deny: (login handleRequest: request) isSuccess.
	self deny: account isAuthenticated
]

{ #category : #tests }
SmallGPTalkAuthTest >> testLateLoginCannotRestoreLogout [
	self prepareLogin.
	login handleRequest: (self callbackWithState: self correctState code: 'test-code').
	transport operation: [ account logout ].
	login awaitCallback; finish; wait.
	self deny: account isAuthenticated.
	self assert: login state equals: #cancelled.
	self assert: store writes equals: 0
]

{ #category : #tests }
SmallGPTalkAuthTest >> testRefusedCallbackFailsWithoutProviderText [
	| request |
	self prepareLogin.
	request := self callbackWithState: self correctState code: nil.
	request uri queryAt: 'error' put: 'test-secret'.
	self assert: (login handleRequest: request) code equals: 400.
	login finish.
	self assert: login state equals: #failed.
	self deny: (login error messageText includesSubstring: 'test-secret').
	login finish
]

{ #category : #tests }
SmallGPTalkAuthTest >> testMalformedTokenHasSafeError [
	self should: [ SmallGPTalkOpenAIAuth accountIdFrom: 'test-secret' ]
		raise: SmallGPTalkOpenAIAuthError
		withExceptionDo: [ :exception |
			self deny: (exception messageText includesSubstring: 'test-secret') ]
]

{ #category : #tests }
SmallGPTalkAuthTest >> testSecondActiveLoginIsRejected [
	self prepareLogin.
	self should: [ account newLogin ] raise: SmallGPTalkOpenAIAuthError
]

{ #category : #tests }
SmallGPTalkAuthTest >> testCallbackUsesOnlyGetAndExpectedPath [
	self prepareLogin.
	self assert: (login handleRequest: (ZnRequest get: '/other')) code equals: 404.
	self assert: transport requests isEmpty
]

{ #category : #tests }
SmallGPTalkAuthTest >> testCancelAfterCredentialCommitKeepsCompletedLogin [
	self prepareLogin.
	login handleRequest: (self callbackWithState: self correctState code: 'test-code').
	login awaitCallback.
	self assert: login state equals: #finishing.
	login cancel.
	self assert: login state equals: #finishing.
	login finish; wait.
	self assert: login state equals: #completed.
	self assert: account isAuthenticated
]

{ #category : #tests }
SmallGPTalkAuthTest >> testFailureWaitsForCleanup [
	| waiting waiter |
	self prepareLogin.
	waiting := Semaphore new.
	login fail: (SmallGPTalkOpenAIAuthError new messageText: 'Test failure.').
	waiter := [ login wait. waiting signal ] fork.
	[
		self assert: (waiting waitTimeoutMilliseconds: 20).
		login finish.
		self deny: (waiting waitTimeoutSeconds: 1).
		self assert: login state equals: #failed
	] ensure: [ waiter terminate ]
]

{ #category : #tests }
SmallGPTalkAuthTest >> testConcurrentExpiredReadsRenewOnce [
	| started release finished first second |
	store write: (self credentials at: 'expires_at' put: 1000; yourself).
	started := Semaphore new.
	release := Semaphore new.
	finished := Semaphore new.
	transport operation: [ started signal. release wait ].
	first := [ account credentials. finished signal ] fork.
	[
		self deny: (started waitTimeoutSeconds: 1).
		second := [ account credentials. finished signal ] fork.
		release signal.
		self deny: (finished waitTimeoutSeconds: 1).
		self deny: (finished waitTimeoutSeconds: 1).
		self assert: transport requests size equals: 1
	] ensure: [ release signal. first terminate. second ifNotNil: [ second terminate ] ]
]

{ #category : #tests }
SmallGPTalkAuthTest >> testLogoutDuringRefreshLeavesStoreEmpty [
	| started release finished first second |
	store write: self credentials.
	started := Semaphore new.
	release := Semaphore new.
	finished := Semaphore new.
	transport operation: [ started signal. release wait ].
	first := [ account refreshCredentials. finished signal ] fork.
	[
		self deny: (started waitTimeoutSeconds: 1).
		second := [ account logout. finished signal ] fork.
		release signal.
		self deny: (finished waitTimeoutSeconds: 1).
		self deny: (finished waitTimeoutSeconds: 1).
		self deny: account isAuthenticated
	] ensure: [ release signal. first terminate. second ifNotNil: [ second terminate ] ]
]

{ #category : #tests }
SmallGPTalkAuthTest >> testCallbackServerRejectsBusyPortWithoutStoppingOwner [
	| owner conflict |
	self prepareLogin.
	owner := SmallGPTalkOpenAIAuthServer on: 0.
	owner bindingAddress: #[127 0 0 1]; delegate: login; start.
	[
		conflict := SmallGPTalkOpenAIAuthServer on: owner port.
		conflict bindingAddress: #[127 0 0 1]; delegate: login.
		self should: [ conflict start ] raise: SmallGPTalkOpenAIAuthError.
		self assert: owner isListening
	] ensure: [ owner stop. conflict ifNotNil: [ conflict stop ] ]
]

{ #category : #tests }
SmallGPTalkAuthTest >> testCallbackWorksThroughZincOnLoopback [
	| server client url |
	self prepareLogin.
	server := SmallGPTalkOpenAIAuthServer on: 0.
	server bindingAddress: #[127 0 0 1]; delegate: login; start.
	client := ZnClient new.
	[
		url := (self callbackWithState: self correctState code: 'test-code') uri.
		url host: '127.0.0.1'; port: server port.
		client loggingOff; timeout: 2; get: url.
		self assert: client response code equals: 200.
		login awaitCallback; finish; wait.
		self assert: login state equals: #completed.
		self assert: transport requests size equals: 1
	] ensure: [ client close. server stop ]
]

{ #category : #tests }
SmallGPTalkAuthTest >> testCancelStopsTokenExchangeWithoutWritingCredentials [
	| started blocked process |
	self prepareLogin.
	login handleRequest: (self callbackWithState: self correctState code: 'test-code').
	started := Semaphore new.
	blocked := Semaphore new.
	transport operation: [ started signal. blocked wait ].
	process := [ [ login awaitCallback ] ensure: [ login finish ] ] newProcess.
	login instVarNamed: 'worker' put: process.
	process resume.
	[
		self deny: (started waitTimeoutSeconds: 1).
		login cancel; wait.
		self assert: login state equals: #cancelled.
		self deny: account isAuthenticated.
		self assert: store writes equals: 0.
		self assert: (login instVarNamed: 'verifier') isNil.
		self assert: (login instVarNamed: 'authorizationCode') isNil
	] ensure: [ process terminate ]
]

{ #category : #tests }
SmallGPTalkAuthTest >> testTwoAccountsShareNativeCoordination [
	| first second |
	first := SmallGPTalkKeychainStore new service: 'SmallGPTalk.Auth.Test'; account: 'test'; yourself.
	second := SmallGPTalkKeychainStore new service: 'SmallGPTalk.Auth.Test'; account: 'test'; yourself.
	self assert: (SmallGPTalkOpenAIAuthState forStore: first)
		identicalTo: (SmallGPTalkOpenAIAuthState forStore: second)
]

{ #category : #tests }
SmallGPTalkAuthTest >> testTwoAccountsCannotStartLoginForSameStore [
	| otherAccount |
	self prepareLogin.
	otherAccount := SmallGPTalkOpenAIAccount credentialStore: store.
	self should: [ otherAccount newLogin ] raise: SmallGPTalkOpenAIAuthError
]

{ #category : #tests }
SmallGPTalkAuthTest >> testLogoutFromOtherAccountRejectsLateLogin [
	| otherAccount |
	self prepareLogin.
	otherAccount := SmallGPTalkOpenAIAccount credentialStore: store.
	login handleRequest: (self callbackWithState: self correctState code: 'test-code').
	transport operation: [ otherAccount logout ].
	login awaitCallback; finish; wait.
	self deny: otherAccount isAuthenticated.
	self deny: account isAuthenticated.
	self assert: login state equals: #cancelled.
	self assert: store writes equals: 0
]

{ #category : #tests }
SmallGPTalkAuthTest >> testConcurrentAccountsRenewOnce [
	| otherAccount started release finished first second |
	store write: (self credentials at: 'expires_at' put: 1000; yourself).
	otherAccount := SmallGPTalkOpenAIAccount credentialStore: store.
	otherAccount clock: [ 1000 ]; transport: transport.
	started := Semaphore new.
	release := Semaphore new.
	finished := Semaphore new.
	transport operation: [ started signal. release wait ].
	first := [ account credentials. finished signal ] fork.
	[
		self deny: (started waitTimeoutSeconds: 1).
		second := [ otherAccount credentials. finished signal ] fork.
		release signal.
		self deny: (finished waitTimeoutSeconds: 1).
		self deny: (finished waitTimeoutSeconds: 1).
		self assert: transport requests size equals: 1
	] ensure: [ release signal. first terminate. second ifNotNil: [ second terminate ] ]
]

{ #category : #tests }
SmallGPTalkAuthTest >> testFinishedLoginReleasesSharedOperation [
	self prepareLogin.
	login cancel; wait.
	self assert: (SmallGPTalkOpenAIAuthState forStore: store) activeLogin isNil
]

{ #category : #tests }
SmallGPTalkAuthTest >> testErrorCallbackCannotReplaceAcceptedCode [
	| request |
	self prepareLogin.
	request := self callbackWithState: self correctState code: 'test-code'.
	self assert: (login handleRequest: request) code equals: 200.
	request uri queryAt: 'error' put: 'refused'.
	self assert: (login handleRequest: request) code equals: 409.
	login awaitCallback; finish; wait.
	self assert: login state equals: #completed
]

{ #category : #tests }
SmallGPTalkAuthTest >> testCallbackTimeoutIsReported [
	self prepareLogin.
	login timeoutSeconds: 0.01.
	self should: [ login awaitCallback ] raise: SmallGPTalkOpenAIAuthError
]
