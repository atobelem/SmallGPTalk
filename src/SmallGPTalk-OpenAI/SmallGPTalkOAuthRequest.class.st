"Bind one authorization code to its PKCE verifier and callback state."
Class {
 #name : 'SmallGPTalkOAuthRequest',
 #superclass : 'Object',
 #instVars : [ 'verifier', 'state', 'used', 'lock' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'instance creation' }
SmallGPTalkOAuthRequest class >> verifier: secret state: callbackState [
 ^ self new verifier: secret state: callbackState; yourself
]

{ #category : 'initialization' }
SmallGPTalkOAuthRequest >> verifier: secret state: callbackState [
 verifier := secret copy.
 state := callbackState copy.
 used := false.
 lock := Semaphore forMutualExclusion
]

{ #category : 'settings' }
SmallGPTalkOAuthRequest >> clientId [ ^ self class clientId ]

{ #category : 'settings' }
SmallGPTalkOAuthRequest >> redirectUri [ ^ 'http://localhost:1455/auth/callback' ]

{ #category : 'authorization' }
SmallGPTalkOAuthRequest >> authorizationUrl [
 | encoded |
 encoded := ZnBase64Encoder new noPadding; encode: (SHA256 hashMessage: verifier).
 encoded := (encoded copyReplaceAll: '+' with: '-') copyReplaceAll: '/' with: '_'.
 ^ ('https://auth.openai.com/oauth/authorize' asZnUrl
  queryAt: 'response_type' put: 'code';
  queryAt: 'client_id' put: self clientId;
  queryAt: 'redirect_uri' put: self redirectUri;
  queryAt: 'scope' put: 'openid profile email offline_access';
  queryAt: 'code_challenge' put: encoded;
  queryAt: 'code_challenge_method' put: 'S256';
  queryAt: 'state' put: state;
  queryAt: 'id_token_add_organizations' put: 'true';
  queryAt: 'codex_cli_simplified_flow' put: 'true';
  queryAt: 'originator' put: 'smallgptalk'; yourself) asString
]

{ #category : 'authorization' }
SmallGPTalkOAuthRequest >> tokenFormFor: code state: callbackState [
 ^ lock critical: [
  | form |
  used ifTrue: [ self error: 'This login code has already been used.' ].
  callbackState = state ifFalse: [ self error: 'The login callback state does not match.' ].
  (code isString and: [ code notEmpty ]) ifFalse: [ self error: 'The login callback has no code.' ].
  form := Dictionary new at: 'grant_type' put: 'authorization_code';
   at: 'client_id' put: self clientId; at: 'redirect_uri' put: self redirectUri;
   at: 'code' put: code; at: 'code_verifier' put: verifier; yourself.
  used := true.
  verifier := nil.
  form ]
]

{ #category : 'authorization' }
SmallGPTalkOAuthRequest >> refuseForState: callbackState [
 lock critical: [
  used ifTrue: [ self error: 'This login code has already been used.' ].
  callbackState = state ifFalse: [ self error: 'The login callback state does not match.' ].
  used := true.
  verifier := nil ]
]

{ #category : 'instance creation' }
SmallGPTalkOAuthRequest class >> fresh [
 ^ self freshUsing: [ :count | SmallGPTalkSecurity uniqueInstance randomBytes: count ]
]

{ #category : 'instance creation' }
SmallGPTalkOAuthRequest class >> freshUsing: random [
 | secret callbackState encode |
 encode := [ :bytes |
  ((ZnBase64Encoder new noPadding; encode: bytes)
   copyReplaceAll: '+' with: '-') copyReplaceAll: '/' with: '_' ].
 secret := encode value: (random value: 32).
 callbackState := encode value: (random value: 32).
 ^ self verifier: secret state: callbackState
]

{ #category : 'settings' }
SmallGPTalkOAuthRequest class >> clientId [ ^ 'app_EMoamEEZ73f0CkXaXp7hrann' ]
