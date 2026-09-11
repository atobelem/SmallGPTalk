Class {
 #name : 'SmallGPTalkOAuthCallbackTest',
 #superclass : 'TestCase',
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'fixtures' }
SmallGPTalkOAuthCallbackTest >> callback [
 ^ SmallGPTalkOAuthCallback request: (SmallGPTalkOAuthRequest
  verifier: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' state: 'test-state')
]

{ #category : 'tests' }
SmallGPTalkOAuthCallbackTest >> testValidCallbackDeliversOneForm [
 | callback response form |
 callback := self callback.
 response := callback handleRequest: (ZnRequest get: '/auth/callback?state=test-state&code=test-code').
 self assert: response code equals: 200.
 form := callback awaitForm.
 self assert: (form at: 'code') equals: 'test-code'.
 self should: [ callback awaitForm ] raise: Error.
 self assert: (callback handleRequest: (ZnRequest get: '/auth/callback?state=test-state&code=test-code')) code equals: 409
]

{ #category : 'tests' }
SmallGPTalkOAuthCallbackTest >> testWrongRouteAndWrongStateDoNotConsumeTheCallback [
 | callback |
 callback := self callback.
 self assert: (callback handleRequest: (ZnRequest get: '/wrong')) code equals: 404.
 self assert: (callback handleRequest: (ZnRequest get: '/auth/callback?state=wrong&code=test-code')) code equals: 400.
 self assert: (callback handleRequest: (ZnRequest get: '/auth/callback?state=test-state&code=test-code')) code equals: 200.
 self assert: (callback awaitForm at: 'code') equals: 'test-code'
]

{ #category : 'tests' }
SmallGPTalkOAuthCallbackTest >> testRefusalReleasesTheConsumerAndClosesTheCallback [
 | callback process done message response |
 callback := self callback.
 done := Semaphore new.
 process := [
  [ callback awaitForm ] on: Error do: [ :failure | message := failure messageText ].
  done signal ] fork.
 [
  response := callback handleRequest: (ZnRequest get:
   '/auth/callback?state=test-state&error=access_denied&error_description=private-detail').
  self assert: response code equals: 200.
  self deny: (done waitTimeoutMilliseconds: 1000).
  self assert: message equals: 'The login was not authorized.'.
  self deny: (response entity contents includesSubstring: 'private-detail').
  self assert: (callback handleRequest: (ZnRequest get:
   '/auth/callback?state=test-state&code=test-code')) code equals: 409
 ] ensure: [ callback cancel. process terminate ]
]

{ #category : 'tests' }
SmallGPTalkOAuthCallbackTest >> testRefusalWithWrongStateDoesNotCloseTheCallback [
 | callback |
 callback := self callback.
 self assert: (callback handleRequest: (ZnRequest get:
  '/auth/callback?state=wrong&error=access_denied')) code equals: 400.
 self assert: (callback handleRequest: (ZnRequest get:
  '/auth/callback?state=test-state&code=test-code')) code equals: 200.
 self assert: (callback awaitForm at: 'code') equals: 'test-code'
]

{ #category : 'tests' }
SmallGPTalkOAuthCallbackTest >> testCancelReleasesAWaitingConsumer [
 | callback process done error |
 callback := self callback.
 done := Semaphore new.
 process := [ [ callback awaitForm ] on: Error do: [ :failure | error := failure messageText ]. done signal ] fork.
 [
  callback cancel.
  self deny: (done waitTimeoutMilliseconds: 1000).
  self assert: error equals: 'The login callback was cancelled.'.
  self assert: (callback handleRequest: (ZnRequest get: '/auth/callback?state=test-state&code=test-code')) code equals: 409
 ] ensure: [ process terminate ]
]

{ #category : 'tests - server' }
SmallGPTalkOAuthCallbackTest >> testServerReceivesTheCallbackOnLoopback [
 | callback server client |
 callback := self callback.
 server := SmallGPTalkCallbackServer on: 0.
 server delegate: callback.
 client := ZnClient new.
 [
  server start.
  self assert: server bindingAddress equals: #[127 0 0 1].
  client get: 'http://127.0.0.1:', server port asString, '/auth/callback?state=test-state&code=test-code'.
  self assert: client response code equals: 200.
  self assert: (callback awaitForm at: 'code') equals: 'test-code'
 ] ensure: [ client close. server stop. callback cancel ]
]

{ #category : 'tests - server' }
SmallGPTalkOAuthCallbackTest >> testAnOccupiedCallbackPortDoesNotStopItsOwner [
 | first second |
 first := SmallGPTalkCallbackServer on: 0.
 first delegate: self callback.
 [
  first start.
  second := SmallGPTalkCallbackServer on: first port.
  second delegate: self callback.
  self should: [ second start ] raise: Error.
  self assert: first isRunning.
  self assert: first isListening
 ] ensure: [ second ifNotNil: [ second stop ]. first stop ]
]
