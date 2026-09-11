Class {
 #name : 'SmallGPTalkOpenAIAccountTest',
 #superclass : 'TestCase',
 #instVars : [ 'record', 'renewals', 'writes', 'renewalError', 'storageError', 'loginRecord', 'transportAction', 'renewalAction' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkOpenAIAccountTest >> setUp [
 super setUp.
 renewals := 0.
 writes := 0.
 record := Dictionary new at: 'access_token' put: 'test-access';
  at: 'refresh_token' put: 'test-refresh'; at: 'account_id' put: 'test-account';
  at: 'expires_at' put: DateAndTime now asUnixTime + 3600; yourself
]

{ #category : 'store protocol' }
SmallGPTalkOpenAIAccountTest >> read [ ^ record deepCopy ]

{ #category : 'store protocol' }
SmallGPTalkOpenAIAccountTest >> write: credentials [
 storageError ifNotNil: [ self error: storageError ].
 writes := writes + 1.
 record := credentials deepCopy
]

{ #category : 'store protocol' }
SmallGPTalkOpenAIAccountTest >> delete [ record := nil ]

{ #category : 'renewal protocol' }
SmallGPTalkOpenAIAccountTest >> renew: credentials [
 renewalError ifNotNil: [ self error: renewalError ].
 renewals := renewals + 1.
 renewalAction ifNotNil: [ renewalAction value ].
 ^ credentials copy at: 'access_token' put: 'test-renewed';
  at: 'expires_at' put: DateAndTime now asUnixTime + 3600; yourself
]

{ #category : 'tests' }
SmallGPTalkOpenAIAccountTest >> testNewAccountUsesStoredLoginAndClearsTemporaryHeaders [
 | account retained |
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 self assert: account isAuthenticated.
 account withHeadersDo: [ :headers |
  retained := headers.
  self assert: (headers at: 'Authorization') equals: 'Bearer test-access'.
  self assert: (headers at: 'chatgpt-account-id') equals: 'test-account' ].
 self assert: retained isEmpty.
 self assert: renewals equals: 0.
 self assert: (SmallGPTalkOpenAIAccount store: self renewer: self) isAuthenticated.
 account logout.
 self deny: account isAuthenticated.
 self should: [ account withHeadersDo: [ :headers | self fail ] ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkOpenAIAccountTest >> testExpiredCredentialsAreRenewedAndStoredBeforeUse [
 | account |
 record at: 'expires_at' put: 0.
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 account withHeadersDo: [ :headers |
  self assert: writes equals: 1.
  self assert: (headers at: 'Authorization') equals: 'Bearer test-renewed' ].
 account withHeadersDo: [ :headers | ].
 self assert: renewals equals: 1.
 self assert: writes equals: 1
]

{ #category : 'tests' }
SmallGPTalkOpenAIAccountTest >> testStorageFailureStopsCredentialUse [
 | account used |
 record at: 'expires_at' put: 0.
 storageError := 'Credential storage denied.'.
 used := false.
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 self should: [ account withHeadersDo: [ :headers | used := true ] ]
  raise: Error withExceptionDo: [ :error | self assert: error messageText equals: storageError ].
 self deny: used.
 self assert: (record at: 'access_token') equals: 'test-access'
]

{ #category : 'tests' }
SmallGPTalkOpenAIAccountTest >> testRequestFailureClearsTemporaryHeaders [
 | account retained |
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 self should: [ account withHeadersDo: [ :headers | retained := headers. self error: 'Request failed.' ] ] raise: Error.
 self assert: retained isEmpty.
 self assert: account isAuthenticated
]

{ #category : 'tests' }
SmallGPTalkOpenAIAccountTest >> testRenewalFailureDoesNotAuthorizeOrReplaceTheRecord [
 | account used previous |
 record at: 'expires_at' put: 0.
 previous := record deepCopy.
 renewalError := 'Login renewal failed.'.
 used := false.
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 self should: [ account withHeadersDo: [ :headers | used := true ] ]
  raise: Error withExceptionDo: [ :error | self assert: error messageText equals: renewalError ].
 self deny: used.
 self assert: record equals: previous.
 self assert: writes equals: 0
]

{ #category : 'tests - request renewal' }
SmallGPTalkOpenAIAccountTest >> testAuthenticationFailureRenewsOnceAndClearsBothHeaderSets [
 | account attempts retained result |
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 attempts := 0.
 retained := OrderedCollection new.
 result := account withHeadersDo: [ :headers |
  attempts := attempts + 1.
  retained add: headers.
  attempts = 1 ifTrue: [ (Smalltalk globals at: #SmallGPTalkHTTPFailure) status: 401 ].
  self assert: (headers at: 'Authorization') equals: 'Bearer test-renewed'.
  'Done.' ].
 self assert: result equals: 'Done.'.
 self assert: attempts equals: 2.
 self assert: renewals equals: 1.
 self assert: writes equals: 1.
 self assert: (retained allSatisfy: #isEmpty)
]

{ #category : 'tests - request renewal' }
SmallGPTalkOpenAIAccountTest >> testRepeatedAuthenticationFailureStopsAfterOneRenewal [
 | account attempts |
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 attempts := 0.
 self should: [ account withHeadersDo: [ :headers |
  attempts := attempts + 1.
  (Smalltalk globals at: #SmallGPTalkHTTPFailure) status: 401 ] ]
  raise: Error withExceptionDo: [ :failure |
   self assert: failure messageText equals: 'The model request failed with HTTP 401.' ].
 self assert: attempts equals: 2.
 self assert: renewals equals: 1
]

{ #category : 'tests - request renewal' }
SmallGPTalkOpenAIAccountTest >> testOtherHTTPFailuresDoNotRenewOrRetry [
 | account attempts |
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 #(403 429 500) do: [ :status |
  attempts := 0.
  self should: [ account withHeadersDo: [ :headers |
   attempts := attempts + 1. SmallGPTalkHTTPFailure status: status ] ]
   raise: SmallGPTalkHTTPFailure.
  self assert: attempts equals: 1 ].
 self assert: renewals equals: 0
]

{ #category : 'tests - request renewal' }
SmallGPTalkOpenAIAccountTest >> testLogoutDuringARejectedRequestDoesNotRestoreCredentials [
 | account attempts |
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 attempts := 0.
 self should: [ account withHeadersDo: [ :headers |
  attempts := attempts + 1.
  account logout.
  SmallGPTalkHTTPFailure status: 401 ] ] raise: Error.
 self assert: attempts equals: 1.
 self assert: renewals equals: 0.
 self deny: account isAuthenticated
]

{ #category : 'tests - request renewal' }
SmallGPTalkOpenAIAccountTest >> testAnOldRejectionUsesTheAlreadyRenewedCredential [
 | account attempts |
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 attempts := 0.
 account withHeadersDo: [ :headers |
  attempts := attempts + 1.
  attempts = 1 ifTrue: [
   record at: 'access_token' put: 'newer-credential'.
   SmallGPTalkHTTPFailure status: 401 ].
  self assert: (headers at: 'Authorization') equals: 'Bearer newer-credential' ].
 self assert: attempts equals: 2.
 self assert: renewals equals: 0
]

{ #category : 'tests - request renewal' }
SmallGPTalkOpenAIAccountTest >> testFailedRenewalStorageStopsTheRetryAndClearsHeaders [
 | account attempts retained |
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 storageError := 'Credential storage denied.'.
 attempts := 0.
 self should: [ account withHeadersDo: [ :headers |
  retained := headers.
  attempts := attempts + 1.
  SmallGPTalkHTTPFailure status: 401 ] ]
  raise: Error withExceptionDo: [ :failure | self assert: failure messageText equals: storageError ].
 self assert: attempts equals: 1.
 self assert: retained isEmpty.
 self assert: (record at: 'access_token') equals: 'test-access'
]

{ #category : 'transport protocol' }
SmallGPTalkOpenAIAccountTest >> post: body headers: headers [ ^ transportAction value: body ]

{ #category : 'tests - request renewal' }
SmallGPTalkOpenAIAccountTest >> testRenewalContinuesAfterTheCompletedEvaluation [
 | account model session run bodies call |
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 bodies := OrderedCollection new.
 call := SmallGPTalkCall id: 'once' name: 'evaluate' arguments:
  (Dictionary new at: 'source' put: 'OrderedCollection with: 42'; yourself).
 transportAction := [ :body |
  bodies add: body.
  bodies size = 1 ifTrue: [ SmallGPTalkReply text: '' calls: { call } ] ifFalse: [
   bodies size = 2 ifTrue: [ SmallGPTalkHTTPFailure status: 401 ].
   SmallGPTalkReply text: 'Done.' calls: #() ] ].
 model := SmallGPTalkOpenAIModel model: 'test-model' effort: 'low' account: account transport: self.
 session := SmallGPTalkSession withModel: model.
 session tools: { SmallGPTalkEvaluate new }.
 run := session send: 'Evaluate once'. run wait.
 self assert: run state equals: #completed.
 self assert: bodies size equals: 3.
 self assert: bodies second identicalTo: bodies third.
 self assert: ((bodies third at: 'input') anySatisfy: [ :item |
  (item at: 'type' ifAbsent: [ '' ]) = 'function_call_output' ]).
 self assert: renewals equals: 1.
 self assert: run exchange calls size equals: 1.
 self assert: run exchange calls first identicalTo: call.
 self assert: call result asArray equals: #(42)
]

{ #category : 'token protocol' }
SmallGPTalkOpenAIAccountTest >> exchange: form [ ^ loginRecord deepCopy ]

{ #category : 'tests - login' }
SmallGPTalkOpenAIAccountTest >> testLoginCommitsToTheAccountsStore [
 | account authorization server login client |
 loginRecord := record deepCopy.
 record := nil.
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 authorization := SmallGPTalkOAuthRequest verifier: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' state: 'test-state'.
 server := SmallGPTalkCallbackServer on: 0.
 login := account beginLoginWith: authorization server: server.
 client := ZnClient new.
 [
  client get: 'http://127.0.0.1:', server port asString, '/auth/callback?state=test-state&code=test-code'.
  login wait.
  self assert: login state equals: #completed.
  self assert: account isAuthenticated.
  self assert: writes equals: 1
 ] ensure: [ client close. login cancel; wait ]
]

{ #category : 'tests - login' }
SmallGPTalkOpenAIAccountTest >> testLogoutInvalidatesAPendingLogin [
 | account authorization server login |
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 authorization := SmallGPTalkOAuthRequest verifier: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' state: 'test-state'.
 server := SmallGPTalkCallbackServer on: 0.
 login := account beginLoginWith: authorization server: server.
 [
  account logout.
  login wait.
  self assert: login state equals: #cancelled.
  self deny: account isAuthenticated.
  self deny: server isRunning.
  self assert: writes equals: 0
 ] ensure: [ login cancel; wait ]
]

{ #category : 'tests - login' }
SmallGPTalkOpenAIAccountTest >> testAnotherAccountForTheSameStoreCancelsThePendingLogin [
 | first second authorization server login |
 first := SmallGPTalkOpenAIAccount store: self renewer: self.
 second := SmallGPTalkOpenAIAccount store: self renewer: self.
 authorization := SmallGPTalkOAuthRequest
  verifier: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' state: 'test-state'.
 server := SmallGPTalkCallbackServer on: 0.
 login := first beginLoginWith: authorization server: server.
 [
  second logout.
  self assert: (#(cancelling cancelled) includes: login state).
  login wait.
  self deny: first isAuthenticated.
  self assert: writes equals: 0
 ] ensure: [ login cancel; wait ]
]

{ #category : 'tests - coordination' }
SmallGPTalkOpenAIAccountTest >> testLogoutWaitsForAnotherAccountsRenewalAndDeletesItsRecord [
 | first second entered release renewalDone logoutStarted logoutDone worker signer errors |
 first := SmallGPTalkOpenAIAccount store: self renewer: self.
 second := SmallGPTalkOpenAIAccount store: self renewer: self.
 record at: 'expires_at' put: 0.
 entered := Semaphore new.
 release := Semaphore new.
 renewalDone := Semaphore new.
 logoutStarted := Semaphore new.
 logoutDone := Semaphore new.
 errors := SharedQueue new.
 renewalAction := [ entered signal. release wait ].
 worker := [
  [ [ first withHeadersDo: [ :headers | ] ] on: Error do: [ :error | errors nextPut: error messageText ] ]
   ensure: [ renewalDone signal ] ] fork.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  signer := [
   [ [ logoutStarted signal. second logout ] on: Error do: [ :error | errors nextPut: error messageText ] ]
    ensure: [ logoutDone signal ] ] fork.
  self deny: (logoutStarted waitTimeoutMilliseconds: 1000).
  self assert: (logoutDone waitTimeoutMilliseconds: 30).
  release signal.
  self deny: (renewalDone waitTimeoutMilliseconds: 1000).
  self deny: (logoutDone waitTimeoutMilliseconds: 1000).
  self assert: errors isEmpty.
  self assert: renewals equals: 1.
  self assert: writes equals: 1.
  self deny: first isAuthenticated.
  self deny: second isAuthenticated
 ] ensure: [ release signal. worker terminate. signer ifNotNil: [ signer terminate ] ]
]

{ #category : 'tests - measurement' }
SmallGPTalkOpenAIAccountTest >> testModelRecordsInputUsageWithoutRejectingMissingTelemetry [
 | model account usage reply |
 account := SmallGPTalkOpenAIAccount store: self renewer: self.
 model := SmallGPTalkOpenAIModel model: 'test-model' effort: 'low' account: account transport: self.
 model contextWindow: 1000.
 usage := Dictionary new at: 'input_tokens' put: 37; yourself.
 transportAction := [ :body | (SmallGPTalkReply text: 'Done.' calls: #())
  providerData: (Dictionary new at: 'usage' put: usage; yourself); yourself ].
 reply := model respondTo: (SmallGPTalkRequest text: 'Hello' history: #() agent: nil).
 self assert: reply usage inputTokens equals: 37.
 self assert: reply usage capacity equals: 1000.
 self assert: reply usage percentage equals: 4.
 { nil. 'invalid'. Dictionary new. Dictionary new at: 'input_tokens' put: -1; yourself } do: [ :value |
  usage := value.
  reply := model respondTo: (SmallGPTalkRequest text: 'Hello' history: #() agent: nil).
  self assert: reply text equals: 'Done.'.
  self assert: reply usage isNil ]
]
