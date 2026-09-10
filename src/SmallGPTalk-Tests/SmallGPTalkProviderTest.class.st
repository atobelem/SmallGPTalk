Class {
	#name : #SmallGPTalkProviderTest,
	#superclass : #TestCase,
	#instVars : [ 'provider', 'account', 'session' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : #running }
SmallGPTalkProviderTest >> setUp [
	super setUp.
	account := SmallGPTalkProviderAccount new.
	provider := SmallGPTalkOpenAIProvider account: account.
	session := SmallGPTalkSession new
		provider: provider;
		model: 'explicit-test-model';
		yourself
]

{ #category : #private }
SmallGPTalkProviderTest >> completeBody [
	^ 'data: {"type":"response.completed","response":{"status":"completed","output":[{"type":"message","id":"msg_1","role":"assistant","status":"completed","content":[{"type":"output_text","text":"Done.","annotations":[]}]}]}}', String lf, String lf
]

{ #category : #private }
SmallGPTalkProviderTest >> clientCode: aNumber body: aString [
	^ SmallGPTalkProviderClient new replyCode: aNumber body: aString; yourself
]

{ #category : #tests }
SmallGPTalkProviderTest >> testAllImageToolSchemasSerialize [
	| body decoded |
	session tools: SmallGPTalkImageTools all.
	body := provider requestBodyFor: session.
	decoded := STONJSON fromString: (provider encodeJSON: body).
	self assert: decoded equals: body.
	self assert: (decoded at: 'tools') size equals: 1
]

{ #category : #tests }
SmallGPTalkProviderTest >> testSharedJSONValuesAreRepeated [
	| value decoded |
	value := Dictionary new at: 'choices' put: #('a' 'b'); yourself.
	decoded := STONJSON fromString: (provider encodeJSON: { value. value }).
	self assert: decoded equals: { value. value }.
	self deny: decoded first identicalTo: decoded second
]

{ #category : #tests }
SmallGPTalkProviderTest >> testCircularJSONValuesAreRejected [
	| cycle |
	cycle := Array new: 1.
	cycle at: 1 put: (Dictionary new at: 'cycle' put: cycle; yourself).
	self should: [ provider encodeJSON: cycle ] raise: Error
]

{ #category : #tests }
SmallGPTalkProviderTest >> testRequestWithAllImageToolsSerializes [
	| client run |
	client := self clientCode: 200 body: self completeBody.
	provider clientFactory: [ client ].
	session tools: SmallGPTalkImageTools all.
	run := (session send: 'Test.' onEvent: [ :event | ]) wait.
	self assert: run state equals: #completed.
	self assert: client postCount equals: 1.
	self assert: ((STONJSON fromString: client capturedRequest entity contents) at: 'tools') size equals: 1
]

{ #category : #tests }
SmallGPTalkProviderTest >> testFinalizedToolItemsContinueTheConversation [
	| reasoning call events body first second clients tool run sent |
	reasoning := STONJSON fromString: '{"type":"reasoning","id":"rs_final","encrypted_content":"test-cipher","summary":[]}'.
	call := Dictionary new
		at: 'type' put: 'function_call';
		at: 'id' put: 'fc_final';
		at: 'call_id' put: 'call_final';
		at: 'name' put: 'fixture';
		at: 'status' put: 'completed';
		at: 'arguments' put: '{"text":"Test."}';
		yourself.
	events := {
		(Dictionary new at: 'type' put: 'response.output_item.done'; at: 'output_index' put: 0; at: 'item' put: reasoning; yourself).
		(Dictionary new at: 'type' put: 'response.output_item.done'; at: 'output_index' put: 1; at: 'item' put: call; yourself).
		(STONJSON fromString: '{"type":"response.completed","response":{"status":"completed","output":[]}}') }.
	body := String streamContents: [ :stream |
		events do: [ :event | stream nextPutAll: 'data: '; nextPutAll: (STONJSON toString: event); lf; lf ] ].
	first := self clientCode: 200 body: body.
	second := self clientCode: 200 body: self completeBody.
	clients := { first. second } readStream.
	provider clientFactory: [ clients next ].
	tool := SmallGPTalkCoreTestTool new.
	session tools: { tool }.
	run := (session send: 'Test.' onEvent: [ :event | ]) wait.
	self assert: run state equals: #completed.
	self assert: run result text equals: 'Done.'.
	self assert: tool executionCount equals: 1.
	self assert: session messages size equals: 4.
	sent := (STONJSON fromString: second capturedRequest entity contents) at: 'input'.
	self assert: sent size equals: 4.
	self assert: sent second equals: reasoning.
	self assert: (sent third at: 'call_id') equals: 'call_final'.
	self assert: (sent fourth at: 'call_id') equals: 'call_final'.
	self assert: (sent fourth at: 'output') equals: 'Tool complete.'
]

{ #category : #tests }
SmallGPTalkProviderTest >> testOctetStreamRequiresCompleteEvents [
	| client run |
	client := self clientCode: 200 body: 'A binary response is not an event stream.'.
	client replyType: 'application/octet-stream'.
	provider clientFactory: [ client ].
	run := (session send: 'Test.' onEvent: [ :event | ]) wait.
	self assert: run state equals: #failed.
	self assert: session messages size equals: 1.
	self assert: client postCount equals: 1.
	self assert: client closeCount equals: 1
]

{ #category : #tests }
SmallGPTalkProviderTest >> testJsonIsNotAnEventStream [
	| client run |
	client := self clientCode: 200 body: self completeBody.
	client replyType: 'application/json'.
	provider clientFactory: [ client ].
	run := (session send: 'Test.' onEvent: [ :event | ]) wait.
	self assert: run state equals: #failed.
	self assert: session messages size equals: 1
]

{ #category : #tests }
SmallGPTalkProviderTest >> testExplicitModelAndNoStorage [
	| body |
	session addMessage: (SmallGPTalkMessage user: 'Test.').
	body := provider requestBodyFor: session.
	self assert: (body at: 'model') equals: 'explicit-test-model'.
	self deny: (body at: 'store').
	self assert: (body at: 'stream').
	self assert: (body at: 'include') equals: #('reasoning.encrypted_content').
	self assert: ((body at: 'input') first at: 'content') equals: 'Test.'.
	session model: ''.
	self should: [ provider requestBodyFor: session ] raise: Error
]

{ #category : #tests }
SmallGPTalkProviderTest >> testReplayUsesProviderItemsOnceAndExactCallId [
	| assistant raw call result input |
	raw := STONJSON fromString: '[{"type":"reasoning","id":"rs_1","encrypted_content":"test-cipher","summary":[]},{"type":"function_call","id":"fc_1","call_id":"call_exact","name":"read","arguments":"{}","status":"completed"}]'.
	call := SmallGPTalkToolCall id: 'call_exact' name: 'read' arguments: Dictionary new.
	assistant := SmallGPTalkMessage assistant: ''.
	assistant providerItems: raw; toolCalls: { call }.
	result := SmallGPTalkMessage toolResult: (SmallGPTalkToolResult text: 'Read result.') for: call.
	input := provider inputFor: { assistant. result }.
	self assert: input size equals: 3.
	self assert: input first equals: raw first.
	self assert: (input last at: 'type') equals: 'function_call_output'.
	self assert: (input last at: 'call_id') equals: 'call_exact'.
	self assert: (input last at: 'output') equals: 'Read result.'
]

{ #category : #tests }
SmallGPTalkProviderTest >> testSuccessfulRequestClosesAndClearsCredentials [
	| client run |
	client := self clientCode: 200 body: self completeBody.
	provider clientFactory: [ client ].
	run := (session send: 'Test.' onEvent: [ :event | ]) wait.
	self assert: run state equals: #completed.
	self assert: run result text equals: 'Done.'.
	self assert: client postCount equals: 1.
	self assert: client closeCount equals: 1.
	self deny: (client request headers includesKey: 'Authorization').
	self assert: client numberOfRetries equals: 0.
	self deny: client followRedirects
]

{ #category : #tests }
SmallGPTalkProviderTest >> testOneRenewalForUnauthorizedRequest [
	| clients first second run |
	first := self clientCode: 401 body: ''.
	second := self clientCode: 200 body: self completeBody.
	clients := { first. second } readStream.
	provider clientFactory: [ clients next ].
	run := (session send: 'Test.' onEvent: [ :event | ]) wait.
	self assert: run state equals: #completed.
	self assert: account refreshCount equals: 1.
	self assert: first postCount + second postCount equals: 2.
	self assert: first closeCount + second closeCount equals: 2
]

{ #category : #tests }
SmallGPTalkProviderTest >> testSecondUnauthorizedResponseFails [
	| client run |
	client := self clientCode: 401 body: ''.
	provider clientFactory: [ client ].
	run := (session send: 'Test.' onEvent: [ :event | ]) wait.
	self assert: run state equals: #failed.
	self assert: account refreshCount equals: 1.
	self assert: client postCount equals: 2
]

{ #category : #tests }
SmallGPTalkProviderTest >> testRateLimitDoesNotRetry [
	| client run |
	client := self clientCode: 429 body: ''.
	provider clientFactory: [ client ].
	run := (session send: 'Test.' onEvent: [ :event | ]) wait.
	self assert: run state equals: #failed.
	self assert: client postCount equals: 1.
	self assert: account refreshCount equals: 0
]

{ #category : #tests }
SmallGPTalkProviderTest >> testConnectionFailureDoesNotRetry [
	| client run |
	client := SmallGPTalkProviderClient new postFailure: true; yourself.
	provider clientFactory: [ client ].
	run := (session send: 'Test.' onEvent: [ :event | ]) wait.
	self assert: run state equals: #failed.
	self assert: client postCount equals: 1.
	self assert: client closeCount equals: 1.
	self assert: account refreshCount equals: 0
]

{ #category : #tests }
SmallGPTalkProviderTest >> testBrokenStreamDoesNotCommitOrRetry [
	| client run |
	client := self clientCode: 200 body: 'data: {"type":"response.output_text.delta","delta":"Part"}', String lf, String lf.
	provider clientFactory: [ client ].
	run := (session send: 'Test.' onEvent: [ :event | ]) wait.
	self assert: run state equals: #failed.
	self assert: session messages size equals: 1.
	self assert: client postCount equals: 1
]

{ #category : #tests }
SmallGPTalkProviderTest >> testCancellationClosesBlockedRequest [
	| client entered run |
	entered := Semaphore new.
	client := SmallGPTalkProviderClient new
		postBlock: [ entered signal. Semaphore new wait ];
		yourself.
	provider clientFactory: [ client ].
	run := session send: 'Test.' onEvent: [ :event | ].
	self deny: (entered waitTimeoutMilliseconds: 2000).
	run cancel; wait.
	self assert: run state equals: #cancelled.
	self assert: client closeCount equals: 1.
	self assert: client postCount equals: 1
]

{ #category : #tests }
SmallGPTalkProviderTest >> testTimeoutClosesBlockedRequest [
	| client run |
	client := SmallGPTalkProviderClient new postBlock: [ Semaphore new wait ]; yourself.
	provider clientFactory: [ client ].
	session requestTimeoutSeconds: 0.05.
	run := (session send: 'Test.' onEvent: [ :event | ]) wait.
	self assert: run state equals: #failed.
	self assert: client closeCount equals: 1
]

{ #category : #tests }
SmallGPTalkProviderTest >> testAccountModelCatalog [
	| client |
	client := self clientCode: 200 body: '{"models":[{"slug":"available","visibility":"list","supported_in_api":false},{"slug":"hidden","visibility":"hide"}]}'.
	provider clientFactory: [ client ].
	self assert: provider models equals: #('available').
	self assert: client getCount equals: 1.
	self assert: client closeCount equals: 1.
	self assert: (client capturedRequest url queryAt: 'client_version') equals: '0.153.4'
]

{ #category : #tests }
SmallGPTalkProviderTest >> testReasoningEffortIsSent [
	self assert: ((provider requestBodyFor: session) at: 'reasoning')
		equals: (Dictionary new at: 'effort' put: 'medium'; yourself).
	provider reasoningEffort: 'high'.
	self assert: (((provider requestBodyFor: session) at: 'reasoning') at: 'effort') equals: 'high'.
	self should: [ provider reasoningEffort: 'invalid' ] raise: Error
]
