[
 | account model agent session run fork fixture check |
 check := [ :condition :message | condition ifFalse: [ Error signal: message ] ].
 account := SmallGPTalkOpenAIAccount openAI.
 check value: account isAuthenticated value: 'Log in before the live check.'.
 fixture := (Object << #SmallGPTalkLiveFixture) sharedVariables: { #Count }; package: 'SmallGPTalk-Live'; install.
 fixture class compile: 'count ^ Count ifNil: [ 0 ]' classified: 'testing'.
 fixture class compile: 'increment Count := self count + 1. ^ Count' classified: 'testing'.
 model := (SmallGPTalkOpenAIProvider account: account) defaultModel.
 agent := SmallGPTalkAgent named: 'SmallGPTalk'.
 agent instructions: 'You are SmallGPTalk, a Smalltalk agent in Pharo. Use evaluate for image operations. Completed image changes remain. Do not repeat completed changes. Use simplified English.'.
 session := agent newSessionWith: model.
 session tools: { SmallGPTalkEvaluate new }.
 session context autoCompactPercentage: nil; autoCompactLimit: 100.
 run := session send: 'Use evaluate exactly once with this source: SmallGPTalkLiveFixture increment. Then report its result.'.
 run wait.
 run state = #completed ifFalse: [
  Stdio stdout nextPutAll: 'Fixture count: '; print: fixture count; lf.
  run exchange calls do: [ :call |
   Stdio stdout nextPutAll: 'Call state: '; print: call state;
    nextPutAll: '. Error: '; nextPutAll: (call error ifNil: [ 'none' ]); lf ] ].
 check value: (run state = #completed) value: ('Evaluation failed: ', (run error ifNil: [ '' ])).
 check value: (fixture count = 1) value: 'The fixture was not changed exactly once.'.
 check value: (run exchange calls size = 1) value: 'Expected one evaluation call.'.
 check value: run exchange modelContext summary notNil value: 'The tool turn was not compacted.'.
 Stdio stdout nextPutAll: 'PASS: one real evaluation, independently verified.'; lf.
 Stdio stdout nextPutAll: 'PASS: automatic compaction within the tool turn.'; lf.
 fork := session forkAt: run exchange.
 run := fork send: 'Without calling tools, state the result of the completed evaluation.'.
 run wait.
 check value: (run state = #completed) value: ('Fork continuation failed: ', (run error ifNil: [ '' ])).
 check value: (fixture count = 1) value: 'Fork repeated the mutation.'.
 check value: (session conversation size = 1) value: 'Fork changed the source conversation.'.
 Stdio stdout nextPutAll: 'PASS: independent fork continuation.'; lf.
 run := fork compact. run wait.
 check value: (run state = #completed) value: ('Compaction failed: ', (run error ifNil: [ '' ])).
 check value: fork context summary notNil value: 'No summary was stored.'.
 check value: (fork conversation size = 2) value: 'Compaction removed history.'.
 run := fork send: 'Without calling tools, state which expression was evaluated and its result.'.
 run wait.
 check value: (run state = #completed) value: ('Summary continuation failed: ', (run error ifNil: [ '' ])).
 check value: (fixture count = 1) value: 'Continuation repeated the mutation.'.
 Stdio stdout nextPutAll: 'PASS: compact and continue without repeating the mutation.'; lf.
 Stdio stdout nextPutAll: 'Model: gpt-5.6-luna. Effort: low.'; lf.
 Smalltalk exit: 0
] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
