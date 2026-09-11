Class {
	#name : #SmallGPTalkProviderNetworkTest,
	#superclass : #TestCase,
	#instVars : [ 'server', 'client', 'session', 'run', 'release', 'finished', 'textReceived', 'deltas' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : #'running' }
SmallGPTalkProviderNetworkTest >> setUp [
	| provider |
	super setUp.
	release := Semaphore new.
	finished := Semaphore new.
	textReceived := Semaphore new.
	deltas := OrderedCollection new.
	server := SmallGPTalkProviderNetworkServer on: 0.
	server bindingAddress: #(127 0 0 1) asByteArray; loggingOff.
	server start.
	client := SmallGPTalkProviderNetworkClient new localUrl: server localUrl; yourself.
	provider := SmallGPTalkOpenAIProvider account: SmallGPTalkProviderAccount new.
	provider clientFactory: [ client ].
	session := SmallGPTalkSession new
		provider: provider;
		model: 'local-test-model';
		requestTimeoutSeconds: 4;
		yourself
]

{ #category : #'running' }
SmallGPTalkProviderNetworkTest >> tearDown [
	run ifNotNil: [ run cancel; wait ].
	release ifNotNil: [ release signal ].
	client ifNotNil: [ client close ].
	server ifNotNil: [ server stop ].
	super tearDown
]

{ #category : #'helpers' }
SmallGPTalkProviderNetworkTest >> serve: aString stalled: aBoolean [
	^ self serve: aString type: 'text/event-stream; charset=utf-8' stalled: aBoolean
]

{ #category : #'helpers' }
SmallGPTalkProviderNetworkTest >> serve: aString type: aMimeString stalled: aBoolean [
	| entity |
	entity := SmallGPTalkProviderNetworkEntity new text: aString; yourself.
	entity contentType: aMimeString.
	aBoolean ifTrue: [ entity release: release ].
	server onRequestRespond: [ :request |
		(ZnResponse ok: entity) setTransferEncodingChunked; yourself ]
]

{ #category : #'tests' }
SmallGPTalkProviderNetworkTest >> testOctetStreamEventsThroughALocalSocket [
	self serve: self textEvent,
		'data: {"type":"response.completed","response":{"status":"completed","output":[{"type":"message","id":"msg_local","role":"assistant","content":[{"type":"output_text","text":"café 日本語"}]}]}}',
		String crlf, String crlf type: 'application/octet-stream' stalled: false.
	self startRun.
	self assertFinished.
	self assert: run state equals: #completed.
	self assert: run result text equals: 'café 日本語'.
	self assert: client closedConnection.
	self deny: client isConnected
]

{ #category : #'helpers' }
SmallGPTalkProviderNetworkTest >> startRun [
	run := session send: 'Test the local stream.' onEvent: [ :event |
		(event at: #type) = #text ifTrue: [
			deltas add: (event at: #text).
			textReceived signal ].
		(event at: #type) = #finished ifTrue: [ finished signal ] ]
]

{ #category : #'helpers' }
SmallGPTalkProviderNetworkTest >> assertFinished [
	self deny: (finished waitTimeoutMilliseconds: 5000)
		description: 'The local request did not stop within five seconds.'
]

{ #category : #'helpers' }
SmallGPTalkProviderNetworkTest >> textEvent [
	^ 'data: {"type":"response.output_text.delta","delta":"café 日本語"}', String crlf, String crlf
]

{ #category : #'tests' }
SmallGPTalkProviderNetworkTest >> testFragmentedUtf8ThroughALocalSocket [
	self serve: self textEvent,
		'data: {"type":"response.completed","response":{"status":"completed","output":[{"type":"message","id":"msg_local","role":"assistant","content":[{"type":"output_text","text":"café 日本語"}]}]}}',
		String crlf, String crlf stalled: false.
	self startRun.
	self assertFinished.
	self assert: run state equals: #completed.
	self assert: run result text equals: 'café 日本語'.
	self assert: deltas asArray equals: #('café 日本語').
	self assert: client closedConnection.
	self deny: client isConnected.
	self deny: (client request headers includesKey: 'Authorization')
]

{ #category : #'tests' }
SmallGPTalkProviderNetworkTest >> testCancellationClosesAStalledSocket [
	self serve: self textEvent stalled: true.
	self startRun.
	self deny: (textReceived waitTimeoutMilliseconds: 2000).
	run cancel.
	self assertFinished.
	self assert: run state equals: #cancelled.
	self assert: session messages size equals: 1.
	self assert: client closedConnection.
	self deny: client isConnected.
	self deny: (client request headers includesKey: 'Authorization')
]

{ #category : #'tests' }
SmallGPTalkProviderNetworkTest >> testTimeoutClosesAStalledSocket [
	self serve: self textEvent stalled: true.
	session requestTimeoutSeconds: 0.5.
	self startRun.
	self deny: (textReceived waitTimeoutMilliseconds: 2000).
	self assertFinished.
	self assert: run state equals: #failed.
	self assert: session messages size equals: 1.
	self assert: client closedConnection.
	self deny: client isConnected.
	self deny: (client request headers includesKey: 'Authorization')
]

{ #category : 'tests' }
SmallGPTalkProviderNetworkTest >> testServerHandlesClientDisconnect [
	self serve: self textEvent stalled: true.
	self startRun.
	self deny: (textReceived waitTimeoutMilliseconds: 2000).
	run cancel.
	self assertFinished.
	release signal.
	self deny: (server waitForDisconnectMilliseconds: 2000).
	self assert: server disconnectCount > 0.
	self assert: server isRunning.
	self assert: run state equals: #cancelled
]
