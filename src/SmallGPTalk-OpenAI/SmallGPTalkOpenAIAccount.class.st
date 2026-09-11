"Use a stored login and renew it before authorizing a request."
Class {
 #name : 'SmallGPTalkOpenAIAccount',
 #superclass : 'Object',
 #instVars : [ 'store', 'renewer', 'access' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'instance creation' }
SmallGPTalkOpenAIAccount class >> store: credentialStore renewer: renewal [
 ^ self new store: credentialStore renewer: renewal; yourself
]

{ #category : 'initialization' }
SmallGPTalkOpenAIAccount >> store: credentialStore renewer: renewal [
 store := credentialStore.
 access := SmallGPTalkAccountAccess for: credentialStore.
 renewer := renewal
]

{ #category : 'testing' }
SmallGPTalkOpenAIAccount >> isAuthenticated [
 ^ access critical: [
  store read ifNil: [ false ] ifNotNil: [ :record | self validate: record. true ] ]
]

{ #category : 'authentication' }
SmallGPTalkOpenAIAccount >> logout [
 | pending |
 [ access critical: [ pending := access login. access login: nil. store delete ] ]
  ensure: [ pending ifNotNil: [ pending cancel ] ]
]

{ #category : 'authorization' }
SmallGPTalkOpenAIAccount >> withHeadersDo: aBlock [
 | headers |
 headers := access critical: [ self requestHeaders ].
 ^ [
  [ aBlock value: headers ] on: SmallGPTalkHTTPFailure do: [ :failure |
   failure status = 401 ifFalse: [ failure pass ].
   access critical: [
    self renewRejectedHeaders: headers.
    headers removeAll.
    headers := self requestHeaders ].
   aBlock value: headers ]
 ] ensure: [ headers removeAll ]
]

{ #category : 'private' }
SmallGPTalkOpenAIAccount >> requestHeaders [
 | record |
 record := store read ifNil: [ self error: 'Log in before sending a request.' ].
 self validate: record.
 (record at: 'expires_at') <= (DateAndTime now asUnixTime + 60) ifTrue: [
  record := self renewRecord: record ].
 ^ Dictionary new
  at: 'Authorization' put: 'Bearer ', (record at: 'access_token');
  at: 'chatgpt-account-id' put: (record at: 'account_id');
  at: 'originator' put: 'smallgptalk';
  at: 'User-Agent' put: 'SmallGPTalk/0.1';
  at: 'OpenAI-Beta' put: 'responses=experimental'; yourself
]

{ #category : 'private' }
SmallGPTalkOpenAIAccount >> renewRecord: previous [
 | renewed |
 renewed := renewer renew: previous.
 self validate: renewed.
 (renewed at: 'expires_at') <= (DateAndTime now asUnixTime + 60)
  ifTrue: [ self error: 'The renewed login has expired.' ].
 store write: renewed.
 ^ renewed
]

{ #category : 'private' }
SmallGPTalkOpenAIAccount >> renewRejectedHeaders: headers [
 | current |
 current := store read ifNil: [ self error: 'Log in before sending a request.' ].
 self validate: current.
 (headers at: 'Authorization') = ('Bearer ', (current at: 'access_token'))
  ifTrue: [ self renewRecord: current ]
]

{ #category : 'private' }
SmallGPTalkOpenAIAccount >> validate: record [
 (record isKindOf: Dictionary) ifFalse: [ self error: 'The stored login is invalid.' ].
 #('access_token' 'refresh_token' 'account_id') do: [ :key |
  | value |
  value := record at: key ifAbsent: [ nil ].
  (value isString and: [ value notEmpty ]) ifFalse: [ self error: 'The stored login is incomplete.' ] ].
 (record at: 'expires_at' ifAbsent: [ nil ]) isNumber
  ifFalse: [ self error: 'The stored login has no valid expiry time.' ]
]

{ #category : 'login' }
SmallGPTalkOpenAIAccount >> beginLogin [
 ^ self beginLoginWith: SmallGPTalkOAuthRequest fresh server: (SmallGPTalkCallbackServer on: 1455)
]

{ #category : 'login' }
SmallGPTalkOpenAIAccount >> beginLoginWith: authorization server: server [
 ^ access critical: [
  | callback operation |
  (access login notNil and: [ (#(completed failed cancelled) includes: access login state) not ])
   ifTrue: [ self error: 'A login is already active.' ].
  callback := SmallGPTalkOAuthCallback request: authorization.
  server delegate: callback.
  operation := SmallGPTalkLogin callback: callback server: server tokens: renewer
   onSuccess: [ :record | self commitLogin: operation record: record ].
  access login: operation.
  operation start ]
]

{ #category : 'private' }
SmallGPTalkOpenAIAccount >> commitLogin: operation record: record [
 access critical: [
  access login == operation ifFalse: [ self error: 'This login is no longer active.' ].
  self validate: record.
  store write: record.
  access login: nil ]
]

{ #category : 'instance creation' }
SmallGPTalkOpenAIAccount class >> openAI [
 ^ self store: SmallGPTalkCredentialStore loginKeychain renewer: SmallGPTalkOAuthTokens openAI
]
