"Define OAuth client settings and credential conversion for OpenAI account login."
Class {
	#name : #SmallGPTalkOpenAIAuth,
	#superclass : #Object,
	#category : #'SmallGPTalk-OpenAI'
}

{ #category : #constants }
SmallGPTalkOpenAIAuth class >> clientId [
	^ 'app_EMoamEEZ73f0CkXaXp7hrann'
]

{ #category : #constants }
SmallGPTalkOpenAIAuth class >> redirectUri [
	^ 'http://localhost:1455/auth/callback'
]

{ #category : #constants }
SmallGPTalkOpenAIAuth class >> tokenUrl [
	^ 'https://auth.openai.com/oauth/token'
]

{ #category : #encoding }
SmallGPTalkOpenAIAuth class >> base64Url: bytes [
	^ (((ZnBase64Encoder new noPadding; encode: bytes)
		copyReplaceAll: '+' with: '-') copyReplaceAll: '/' with: '_')
]

{ #category : #encoding }
SmallGPTalkOpenAIAuth class >> decodeBase64Url: text [
	^ ZnBase64Encoder new beLenient; decode:
		((text copyReplaceAll: '-' with: '+') copyReplaceAll: '_' with: '/')
]

{ #category : #encoding }
SmallGPTalkOpenAIAuth class >> challengeFor: verifier [
	^ self base64Url: (SHA256 hashMessage: verifier)
]

{ #category : #login }
SmallGPTalkOpenAIAuth class >> authorizationUrlFor: verifier state: state [
	^ 'https://auth.openai.com/oauth/authorize' asZnUrl
		queryAt: 'response_type' put: 'code';
		queryAt: 'client_id' put: self clientId;
		queryAt: 'redirect_uri' put: self redirectUri;
		queryAt: 'scope' put: 'openid profile email offline_access';
		queryAt: 'code_challenge' put: (self challengeFor: verifier);
		queryAt: 'code_challenge_method' put: 'S256';
		queryAt: 'state' put: state;
		queryAt: 'id_token_add_organizations' put: 'true';
		queryAt: 'codex_cli_simplified_flow' put: 'true';
		queryAt: 'originator' put: 'smallgptalk';
		asString
]

{ #category : #validation }
SmallGPTalkOpenAIAuth class >> accountIdFrom: token [
	| parts payload accountId |
	[
		parts := token splitOn: '.'.
		parts size = 3 ifFalse: [ self error: 'Invalid token.' ].
		payload := STONJSON fromString: (self decodeBase64Url: parts second) utf8Decoded.
		accountId := (payload at: 'https://api.openai.com/auth') at: 'chatgpt_account_id'.
		(accountId isString and: [ accountId notEmpty ])
			ifFalse: [ self error: 'Missing account.' ].
		^ accountId
	] on: Error do: [ :exception |
		SmallGPTalkOpenAIAuthError signal: 'The token has no valid account identifier.' ]
]

{ #category : #validation }
SmallGPTalkOpenAIAuth class >> credentialsFrom: response previous: previous now: seconds [
	| access refresh lifetime |
	(response isKindOf: Dictionary) ifFalse: [
		SmallGPTalkOpenAIAuthError signal: 'The token response is not an object.' ].
	access := response at: 'access_token' ifAbsent: [ nil ].
	refresh := response at: 'refresh_token' ifAbsent: [
		previous ifNotNil: [ previous at: 'refresh_token' ifAbsent: [ nil ] ] ].
	lifetime := response at: 'expires_in' ifAbsent: [ nil ].
	((access isString and: [ access notEmpty ]) and: [
		(refresh isString and: [ refresh notEmpty ]) and: [
			lifetime isNumber and: [ lifetime > 0 ] ] ]) ifFalse: [
		SmallGPTalkOpenAIAuthError signal: 'The token response has invalid fields.' ].
	^ Dictionary new
		at: 'access_token' put: access;
		at: 'refresh_token' put: refresh;
		at: 'expires_at' put: seconds + lifetime;
		at: 'account_id' put: (self accountIdFrom: access);
		yourself
]
