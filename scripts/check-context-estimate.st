[
 | account model session run measured estimate |
 account := SmallGPTalkOpenAIAccount openAI.
 account isAuthenticated ifFalse: [ Error signal: 'Log in before the live check.' ].
 model := (SmallGPTalkOpenAIProvider account: account) defaultModel.
 session := SmallGPTalkSession withModel: model.
 run := session send: 'Reply with exactly: Ready.'. run wait.
 run state = #completed ifFalse: [ Error signal: run error ].
 measured := run exchange modelUsage.
 measured inputBytes > 0 ifFalse: [ Error signal: 'The request byte size is missing.' ].
 estimate := session estimateFor: 'Explain this expression: 6 factorial.'.
 estimate inputTokens > measured inputTokens ifFalse: [ Error signal: 'The estimate did not include new input.' ].
 Stdio stdout nextPutAll: 'PASS: live request, measured input, and local next-request estimate. Measured: ';
  print: measured inputTokens; nextPutAll: '. Estimated: '; print: estimate inputTokens; lf.
 Smalltalk exit: 0
] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
