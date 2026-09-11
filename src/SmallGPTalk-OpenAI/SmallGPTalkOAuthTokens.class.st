"Exchange authorization forms and convert token responses to credential records."
Class {
 #name : 'SmallGPTalkOAuthTokens',
 #superclass : 'Object',
 #instVars : [ 'transport' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'instance creation' }
SmallGPTalkOAuthTokens class >> transport: http [ ^ self new transport: http; yourself ]

{ #category : 'initialization' }
SmallGPTalkOAuthTokens >> transport: http [ transport := http ]

{ #category : 'tokens' }
SmallGPTalkOAuthTokens >> exchange: form [
 ^ self recordFrom: (transport postForm: form) previous: nil
]

{ #category : 'tokens' }
SmallGPTalkOAuthTokens >> renew: record [
 | form |
 form := Dictionary new at: 'grant_type' put: 'refresh_token';
  at: 'client_id' put: SmallGPTalkOAuthRequest clientId;
  at: 'refresh_token' put: (record at: 'refresh_token'); yourself.
 ^ [ self recordFrom: (transport postForm: form) previous: record ]
  ensure: [ form removeAll ]
]

{ #category : 'private' }
SmallGPTalkOAuthTokens >> recordFrom: response previous: previous [
 | access refresh lifetime |
 (response isKindOf: Dictionary) ifFalse: [ self error: 'The token response must be an object.' ].
 access := response at: 'access_token' ifAbsent: [ nil ].
 refresh := response at: 'refresh_token' ifAbsent: [ previous ifNotNil: [ previous at: 'refresh_token' ] ].
 lifetime := response at: 'expires_in' ifAbsent: [ nil ].
 ((access isString and: [ access notEmpty ]) and: [
  (refresh isString and: [ refresh notEmpty ]) and: [ lifetime isNumber and: [ lifetime > 0 ] ] ])
  ifFalse: [ self error: 'The token response has invalid fields.' ].
 ^ Dictionary new at: 'access_token' put: access; at: 'refresh_token' put: refresh;
  at: 'account_id' put: (self accountIdFrom: access);
  at: 'expires_at' put: DateAndTime now asUnixTime + lifetime; yourself
]

{ #category : 'private' }
SmallGPTalkOAuthTokens >> accountIdFrom: access [
 ^ [
  | parts encoded payload identifier |
  parts := access splitOn: '.'.
  parts size = 3 ifFalse: [ self error: 'Invalid token structure.' ].
  encoded := (parts second copyReplaceAll: '-' with: '+') copyReplaceAll: '_' with: '/'.
  payload := STONJSON fromString: (ZnBase64Encoder new beLenient; decode: encoded) utf8Decoded.
  identifier := (payload at: 'https://api.openai.com/auth') at: 'chatgpt_account_id'.
  (identifier isString and: [ identifier notEmpty ]) ifFalse: [ self error: 'Invalid account identifier.' ].
  identifier
 ] on: Error do: [ :error | self error: 'The token has no valid account identifier.' ]
]

{ #category : 'instance creation' }
SmallGPTalkOAuthTokens class >> openAI [
 ^ self transport: (SmallGPTalkOpenAIHTTP endpoint: 'https://auth.openai.com/oauth/token'
  clients: [ SmallGPTalkTLSClient new ])
]
