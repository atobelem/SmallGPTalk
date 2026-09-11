| provider session run results |
provider := SmallGPTalkOpenAIProvider account: SmallGPTalkOpenAIAccount new.
results := OrderedCollection new.
session := SmallGPTalkSession new
 provider: provider;
 reasoningEffort: 'medium';
 model: 'gpt-5.6-luna';
 tools: SmallGPTalkImageTools all;
 yourself.
run := session send: 'Use evaluate to execute only this Smalltalk expression: 6 * 7. Report the result.' onEvent: [ :event |
 (event at: #type) = #toolResult ifTrue: [ results add: (event at: #result) ] ].
run wait.
run state = #completed ifFalse: [ Error signal: run error messageText ].
(results anySatisfy: [ :result |
 result isError not and: [ ((STONJSON fromString: result text) at: 'value') = '42' ] ])
 ifFalse: [ Error signal: 'The model did not evaluate the expression successfully.' ].
Stdio stdout nextPutAll: 'Evaluate passed with gpt-5.6-luna and medium effort.'; lf;
 nextPutAll: run result text; lf.
Smalltalk exit: 0.
