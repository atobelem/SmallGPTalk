[
 | first second |
 first := SmallGPTalkOAuthRequest fresh authorizationUrl asZnUrl.
 second := SmallGPTalkOAuthRequest fresh authorizationUrl asZnUrl.
 ((first queryAt: 'state') size = 43 and: [ (first queryAt: 'state') ~= (second queryAt: 'state') ])
  ifFalse: [ Error signal: 'The native random state check failed.' ].
 (first queryAt: 'code_challenge') = (second queryAt: 'code_challenge')
  ifTrue: [ Error signal: 'The native PKCE check failed.' ].
 Stdio stdout nextPutAll: 'PASS: native Security random bytes and PKCE request creation.'; lf.
 Smalltalk exit: 0
] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
