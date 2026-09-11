Class {
 #name : 'SmallGPTalkOAuthRequestTest',
 #superclass : 'TestCase',
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'fixtures' }
SmallGPTalkOAuthRequestTest >> request [
 ^ SmallGPTalkOAuthRequest verifier: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' state: 'test-state'
]

{ #category : 'tests' }
SmallGPTalkOAuthRequestTest >> testAuthorizationURLUsesThePKCEChallenge [
 | url |
 url := self request authorizationUrl asZnUrl.
 self assert: (url queryAt: 'code_challenge') equals: 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM'.
 self assert: (url queryAt: 'code_challenge_method') equals: 'S256'.
 self assert: (url queryAt: 'state') equals: 'test-state'.
 self assert: (url queryAt: 'redirect_uri') equals: 'http://localhost:1455/auth/callback'.
 self assert: (url queryAt: 'client_id') equals: 'app_EMoamEEZ73f0CkXaXp7hrann'.
 self deny: (url asString includesSubstring: 'dBjftJeZ')
]

{ #category : 'tests' }
SmallGPTalkOAuthRequestTest >> testCallbackStateMustMatchBeforeTheCodeCanBeUsed [
 | request form |
 request := self request.
 self should: [ request tokenFormFor: 'test-code' state: 'wrong-state' ] raise: Error.
 form := request tokenFormFor: 'test-code' state: 'test-state'.
 self assert: (form at: 'grant_type') equals: 'authorization_code'.
 self assert: (form at: 'code') equals: 'test-code'.
 self assert: (form at: 'code_verifier') equals: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'.
 self should: [ request tokenFormFor: 'test-code' state: 'test-state' ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkOAuthRequestTest >> testEmptyCodeDoesNotConsumeTheRequest [
 | request |
 request := self request.
 self should: [ request tokenFormFor: '' state: 'test-state' ] raise: Error.
 self assert: (request tokenFormFor: 'valid-code' state: 'test-state') notEmpty
]

{ #category : 'tests' }
SmallGPTalkOAuthRequestTest >> testFreshRequestUsesSeparateRandomValues [
 | request reads url |
 reads := 0.
 request := SmallGPTalkOAuthRequest freshUsing: [ :count |
  self assert: count equals: 32.
  reads := reads + 1.
  ByteArray new: count withAll: reads ].
 url := request authorizationUrl asZnUrl.
 self assert: reads equals: 2.
 self assert: (url queryAt: 'state') size equals: 43.
 self assert: (url queryAt: 'code_challenge') size equals: 43
]
