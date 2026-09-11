[
 | account provider |
 account := SmallGPTalkOpenAIAccount openAI.
 account isAuthenticated ifFalse: [
  Stdio stdout nextPutAll: 'LOGIN_REQUIRED'; lf. Smalltalk exit: 2 ].
 provider := SmallGPTalkOpenAIProvider account: account.
 provider models do: [ :description |
  Stdio stdout nextPutAll: description identifier; nextPutAll: ' efforts=';
   nextPutAll: (STONJSON toString: description efforts); lf ].
 Smalltalk exit: 0
] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
