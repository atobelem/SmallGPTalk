[
 | account model session run agent measured previews |
 account := SmallGPTalkOpenAIAccount openAI.
 account isAuthenticated ifFalse: [ Error signal: 'Log in before the live check.' ].
 model := (SmallGPTalkOpenAIProvider account: account) defaultModel.
 agent := SmallGPTalkAgent named: 'SmallGPTalk'.
 agent instructions: 'You are SmallGPTalk. Use simplified English. Follow the user request.'.
 session := agent newSessionWith: model.
 previews := 0.
 session whenChanged: [ :exchange | exchange partialText ifNotEmpty: [ previews := previews + 1 ] ].
 run := session send: 'Reply with exactly: Ready.'.
 run wait.
 Stdio stdout nextPutAll: 'Model: gpt-5.6-luna. Effort: low. State: '; nextPutAll: run state asString; lf.
 run state = #completed ifFalse: [ Error signal: run error ].
 Stdio stdout nextPutAll: run result text; lf.
 previews > 0 ifFalse: [ Error signal: 'The response had no incremental text.' ].
 Stdio stdout nextPutAll: 'Text previews: '; print: previews; lf.
 measured := run exchange modelUsage.
 measured ifNil: [ Error signal: 'The response has no measured context usage.' ].
 (measured capacity = model contextWindow) ifFalse: [ Error signal: 'The usage has the wrong model capacity.' ].
 Stdio stdout nextPutAll: 'Input tokens: '; print: measured inputTokens;
  nextPutAll: '. Capacity: '; print: measured capacity;
  nextPutAll: '. Percent: '; print: measured percentage; lf.
 Smalltalk exit: 0
] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
