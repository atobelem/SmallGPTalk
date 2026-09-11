Class {
 #name : 'SmallGPTalkOpenAIResponseTest',
 #superclass : 'TestCase',
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkOpenAIResponseTest >> testDecodeTextCallsAndProviderData [
 | response reply |
 response := STONJSON fromString: '{"status":"completed","output":[{"type":"reasoning","id":"r1","encrypted_content":"test-only"},{"type":"message","status":"completed","content":[{"type":"output_text","text":"Compute."}]},{"type":"function_call","status":"completed","call_id":"c1","name":"evaluate","arguments":"{\"source\":\"6 factorial\"}"}]}'.
 reply := SmallGPTalkOpenAIResponse new decode: response.
 self assert: reply text equals: 'Compute.'.
 self assert: reply calls size equals: 1.
 self assert: reply calls first id equals: 'c1'.
 self assert: (reply calls first arguments at: 'source') equals: '6 factorial'.
 self assert: reply providerData equals: response.
 (response at: 'output') first at: 'encrypted_content' put: 'changed'.
 self assert: ((reply providerData at: 'output') first at: 'encrypted_content') equals: 'test-only'.
 self assert: reply copy providerData equals: reply providerData
]

{ #category : 'tests' }
SmallGPTalkOpenAIResponseTest >> testIncompleteResponseCannotProduceCalls [
 | decoder response |
 decoder := SmallGPTalkOpenAIResponse new.
 response := STONJSON fromString: '{"status":"incomplete","output":[{"type":"function_call","call_id":"c1","name":"evaluate","arguments":"{}"}]}'.
 self should: [ decoder decode: response ] raise: Error.
 response at: 'status' put: 'completed'.
 (response at: 'output') first at: 'status' put: 'in_progress'.
 self should: [ decoder decode: response ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkOpenAIResponseTest >> testInvalidArgumentsReturnAToolFailure [
 | response reply call |
 response := STONJSON fromString: '{"status":"completed","output":[{"type":"function_call","call_id":"c1","name":"evaluate","arguments":"not json"}]}'.
 reply := SmallGPTalkOpenAIResponse new decode: response.
 call := reply calls first.
 call executeWith: { SmallGPTalkEvaluate new }.
 self assert: call state equals: #failed.
 self assert: call operation isNil.
 self assert: call error notEmpty
]
