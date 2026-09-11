Class {
 #name : 'SmallGPTalkOAuthTokensTest',
 #superclass : 'TestCase',
 #instVars : [ 'answer', 'received' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkOAuthTokensTest >> setUp [
 | payload |
 super setUp.
 payload := ZnBase64Encoder new noPadding; encode: '{"https://api.openai.com/auth":{"chatgpt_account_id":"test-account"}}' utf8Encoded.
 payload := (payload copyReplaceAll: '+' with: '-') copyReplaceAll: '/' with: '_'.
 answer := Dictionary new at: 'access_token' put: 'test.', payload, '.test';
  at: 'refresh_token' put: 'test-refresh'; at: 'expires_in' put: 3600; yourself
]

{ #category : 'transport protocol' }
SmallGPTalkOAuthTokensTest >> postForm: form [ received := form copy. ^ answer copy ]

{ #category : 'tests' }
SmallGPTalkOAuthTokensTest >> testCodeExchangeCreatesTheStoredRecord [
 | tokens record before form |
 tokens := SmallGPTalkOAuthTokens transport: self.
 form := Dictionary new at: 'grant_type' put: 'authorization_code'; at: 'code' put: 'test-code'; yourself.
 before := DateAndTime now asUnixTime.
 record := tokens exchange: form.
 self assert: received equals: form.
 self assert: (record at: 'account_id') equals: 'test-account'.
 self assert: (record at: 'refresh_token') equals: 'test-refresh'.
 self assert: (record at: 'expires_at') >= (before + 3600)
]

{ #category : 'tests' }
SmallGPTalkOAuthTokensTest >> testRenewalKeepsThePreviousRefreshTokenWhenOmitted [
 | tokens record |
 tokens := SmallGPTalkOAuthTokens transport: self.
 answer removeKey: 'refresh_token'.
 record := tokens renew: (Dictionary new at: 'refresh_token' put: 'previous-test-refresh'; yourself).
 self assert: (record at: 'refresh_token') equals: 'previous-test-refresh'.
 self assert: (received at: 'grant_type') equals: 'refresh_token'.
 self assert: (received at: 'refresh_token') equals: 'previous-test-refresh'.
 self assert: (received at: 'client_id') equals: 'app_EMoamEEZ73f0CkXaXp7hrann'
]

{ #category : 'tests' }
SmallGPTalkOAuthTokensTest >> testInvalidTokenResponseHasAnErrorWithoutTokenText [
 | tokens |
 tokens := SmallGPTalkOAuthTokens transport: self.
 answer at: 'access_token' put: 'invalid-test-secret'.
 self should: [ tokens exchange: Dictionary new ] raise: Error withExceptionDo: [ :error |
  self deny: (error messageText includesSubstring: 'invalid-test-secret') ].
 answer at: 'expires_in' put: -1.
 self should: [ tokens exchange: Dictionary new ] raise: Error
]
