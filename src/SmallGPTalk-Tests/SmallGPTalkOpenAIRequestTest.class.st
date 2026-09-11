Class {
 #name : 'SmallGPTalkOpenAIRequestTest',
 #superclass : 'TestCase',
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkOpenAIRequestTest >> testRequestUsesExplicitModelEffortAndSuppliedTools [
 | agent request body |
 agent := SmallGPTalkAgent named: 'Ada'.
 agent instructions: 'Use Smalltalk.'.
 request := (SmallGPTalkRequest text: 'Hello' history: #() agent: agent)
  withTools: { SmallGPTalkEvaluate new }.
 body := SmallGPTalkOpenAIRequest new encode: request model: 'test-model' effort: 'low'.
 self assert: (body at: 'model') equals: 'test-model'.
 self assert: ((body at: 'reasoning') at: 'effort') equals: 'low'.
 self deny: (body at: 'store').
 self assert: (body at: 'stream').
 self assert: (body at: 'instructions') equals: 'Use Smalltalk.'.
 self assert: ((body at: 'tools') first at: 'name') equals: 'evaluate'.
 self assert: ((body at: 'input') last at: 'content') equals: 'Hello'.
 self should: [ SmallGPTalkOpenAIRequest new encode: request model: '' effort: 'low' ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkOpenAIRequestTest >> testContinuationUsesRecordedOutputAndKeepsProviderItems [
 | request reply call body input |
 reply := SmallGPTalkOpenAIResponse new decode: (STONJSON fromString:
  '{"status":"completed","output":[{"type":"reasoning","id":"r1","encrypted_content":"test-only"},{"type":"function_call","call_id":"c1","name":"evaluate","arguments":"{\"source\":\"OrderedCollection with: 42\"}"}]}').
 call := reply calls first.
 call executeWith: { SmallGPTalkEvaluate new }.
 call result add: 'Later change'.
 request := (SmallGPTalkRequest text: 'Evaluate' history: #() agent: nil) following: { reply }.
 body := SmallGPTalkOpenAIRequest new encode: request model: 'test-model' effort: 'low'.
 input := body at: 'input'.
 self assert: (input second at: 'encrypted_content') equals: 'test-only'.
 self assert: (input third at: 'call_id') equals: 'c1'.
 self assert: (input fourth at: 'type') equals: 'function_call_output'.
 self assert: (input fourth at: 'call_id') equals: 'c1'.
 self deny: ((input fourth at: 'output') includesSubstring: 'Later change').
 self assert: call result size equals: 2
]

{ #category : 'tests' }
SmallGPTalkOpenAIRequestTest >> testSummaryRequestHasNoToolsAndIncludesTheSummary [
 | request body |
 request := ((SmallGPTalkRequest text: 'Summarize' history: #() agent: nil)
  withTools: { SmallGPTalkEvaluate new }) withSummary: 'Earlier work.'.
 body := SmallGPTalkOpenAIRequest new encode: request forCompaction model: 'test-model' effort: 'low'.
 self assert: (body at: 'tools') isEmpty.
 self assert: ((body at: 'input') first at: 'content') equals: 'Earlier work.'
]

{ #category : 'tests' }
SmallGPTalkOpenAIRequestTest >> testMidTurnSummaryFollowsTheRequestItHasAlreadyExecuted [
 | request compacted input |
 request := SmallGPTalkRequest text: 'Increment once.' history: #() agent: nil.
 compacted := SmallGPTalkContext new request: request
  summarizedBy: 'The increment is complete. Its result is 1. Only report the result.'.
 input := (SmallGPTalkOpenAIRequest new encode: compacted model: 'test-model' effort: 'low') at: 'input'.
 self assert: (input first at: 'role') equals: 'user'.
 self assert: (input first at: 'content') equals: 'Increment once.'.
 self assert: (input last at: 'role') equals: 'assistant'.
 self assert: (input last at: 'content') equals: compacted summary.
 self assert: request summary isNil
]
