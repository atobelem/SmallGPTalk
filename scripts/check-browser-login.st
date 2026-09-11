[
 | account login directory |
 directory := (OSPlatform current environment at: 'SMALLGPTALK_LOGIN_CHECK_DIR') asFileReference.
 account := SmallGPTalkOpenAIAccount openAI.
 login := account beginLogin.
 (directory / 'authorization-url.txt') writeStreamDo: [ :stream | stream nextPutAll: login authorizationUrl ].
 login wait.
 login state = #completed ifFalse: [ Error signal: (login error ifNil: [ 'Login cancelled.' ]) ].
 account isAuthenticated ifFalse: [ Error signal: 'The login record was not stored.' ].
 Stdio stdout nextPutAll: 'PASS: browser login completed and stored in Keychain.'; lf.
 Smalltalk exit: 0
] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
