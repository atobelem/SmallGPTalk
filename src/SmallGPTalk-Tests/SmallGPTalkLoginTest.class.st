Class {
 #name : 'SmallGPTalkLoginTest',
 #superclass : 'TestCase',
 #instVars : [ 'action', 'server', 'callback', 'committed' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkLoginTest >> setUp [
 super setUp.
 callback := SmallGPTalkOAuthCallback request: (SmallGPTalkOAuthRequest
  verifier: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' state: 'test-state').
 server := SmallGPTalkCallbackServer on: 0.
 server delegate: callback.
 action := [ :form | Dictionary new at: 'test' put: 'credential-record'; yourself ]
]

{ #category : 'running' }
SmallGPTalkLoginTest >> tearDown [
 server stop.
 callback cancel.
 super tearDown
]

{ #category : 'token protocol' }
SmallGPTalkLoginTest >> exchange: form [ ^ action value: form ]

{ #category : 'fixtures' }
SmallGPTalkLoginTest >> login [
 ^ SmallGPTalkLogin callback: callback server: server tokens: self
  onSuccess: [ :record | committed := record ]
]

{ #category : 'fixtures' }
SmallGPTalkLoginTest >> deliverCode [
 | client |
 client := ZnClient new.
 [ client get: 'http://127.0.0.1:', server port asString, '/auth/callback?state=test-state&code=test-code' ]
  ensure: [ client close ]
]

{ #category : 'tests' }
SmallGPTalkLoginTest >> testLoginCommitsAfterTokenExchangeAndStopsItsServer [
 | login |
 login := self login.
 [
  login start.
  self assert: server isListening.
  self assert: login authorizationUrl equals: callback authorizationUrl.
  self deliverCode.
  self assert: login wait identicalTo: login.
  self assert: login state equals: #completed.
  self assert: (committed at: 'test') equals: 'credential-record'.
  self deny: server isRunning
 ] ensure: [ login cancel; wait ]
]

{ #category : 'tests' }
SmallGPTalkLoginTest >> testCancellationStopsTokenWorkWithoutCommitting [
 | login entered stopped |
 entered := Semaphore new.
 stopped := Semaphore new.
 action := [ :form | [ entered signal. Semaphore new wait ] ensure: [ stopped signal ] ].
 login := self login.
 [
  login start.
  self deliverCode.
  self deny: (entered waitTimeoutMilliseconds: 1000).
  login cancel; wait.
  self assert: login state equals: #cancelled.
  self assert: committed isNil.
  self deny: (stopped waitTimeoutMilliseconds: 1000).
  self deny: server isRunning
 ] ensure: [ login cancel; wait ]
]

{ #category : 'tests' }
SmallGPTalkLoginTest >> testLoginTimeoutStopsTheCallbackWait [
 | login |
 login := self login timeoutSeconds: 0.03; yourself.
 [
  login start; wait.
  self assert: login state equals: #failed.
  self assert: login error notEmpty.
  self assert: committed isNil.
  self deny: server isRunning
 ] ensure: [ login cancel; wait ]
]

{ #category : 'tests' }
SmallGPTalkLoginTest >> testOccupiedPortReturnsAFailedLoginWithoutAUrl [
 | owner login |
 owner := SmallGPTalkCallbackServer on: 0.
 owner delegate: callback.
 [
  owner start.
  server port: owner port.
  login := self login start.
  self assert: login state equals: #failed.
  self assert: login error equals: 'The login callback port is not available.'.
  self should: [ login authorizationUrl ] raise: Error.
  self assert: login wait identicalTo: login.
  self assert: committed isNil.
  self deny: server isRunning.
  self assert: owner isListening
 ] ensure: [ login ifNotNil: [ login cancel; wait ]. owner stop ]
]

{ #category : 'tests' }
SmallGPTalkLoginTest >> testRefusalFailsTheLoginWithoutTokenExchange [
 | login exchanged |
 exchanged := false.
 action := [ :form | exchanged := true. self error: 'Unexpected token exchange.' ].
 login := self login timeoutSeconds: 1; yourself.
 [
  login start.
  callback handleRequest: (ZnRequest get:
   '/auth/callback?state=test-state&error=access_denied').
  login wait.
  self assert: login state equals: #failed.
  self assert: login error equals: 'The login was not authorized.'.
  self deny: exchanged.
  self assert: committed isNil.
  self deny: server isRunning
 ] ensure: [ login cancel; wait ]
]
