| failures |
failures := 0.
#('https://auth.openai.com/.well-known/openid-configuration' 'https://chatgpt.com/backend-api/codex/responses' 'https://expired.badssl.com/' 'https://wrong.host.badssl.com/') withIndexDo: [ :url :index |
 | client outcome rejected |
 client := SmallGPTalkTLSClient new numberOfRetries: 0; followRedirects: false; timeout: 15; yourself.
 rejected := false.
 [
  [ client get: url. outcome := 'HTTP ', client response code asString ]
   on: Error do: [ :error | rejected := true. outcome := error messageText ]
 ] ensure: [ client close ].
 ((index <= 2 and: [ rejected ]) or: [ index > 2 and: [ rejected not or: [ (outcome beginsWith: 'The TLS certificate') not ] ] ]) ifTrue: [ failures := failures + 1 ].
 Stdio stdout nextPutAll: url; nextPutAll: ' -> '; nextPutAll: outcome; lf ].
Smalltalk exit: (failures = 0 ifTrue: [ 0 ] ifFalse: [ 1 ])
