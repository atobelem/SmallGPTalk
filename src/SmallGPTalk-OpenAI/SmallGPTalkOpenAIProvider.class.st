"Convert session history to OpenAI requests and return complete model responses."
Class {
	#name : #SmallGPTalkOpenAIProvider,
	#superclass : #Object,
	#instVars : [ 'account', 'clientFactory', 'clientVersion', 'catalogTimeoutSeconds' ],
	#category : #'SmallGPTalk-OpenAI'
}

{ #category : #'instance creation' }
SmallGPTalkOpenAIProvider class >> account: anAccount [
	^ self new account: anAccount; yourself
]

{ #category : #accessing }
SmallGPTalkOpenAIProvider class >> endpoint [
	^ 'https://chatgpt.com/backend-api/codex/responses'
]

{ #category : #accessing }
SmallGPTalkOpenAIProvider class >> referenceRevision [
	^ '6160683a4a8012f0d1cd30c145df18b4ca6f5176'
]

{ #category : #initialization }
SmallGPTalkOpenAIProvider >> initialize [
	super initialize.
	clientFactory := [ SmallGPTalkOpenAIHTTPClient new ].
	clientVersion := '0.153.4'.
	catalogTimeoutSeconds := 120
]

{ #category : #accessing }
SmallGPTalkOpenAIProvider >> clientVersion [
	"This is the Codex protocol version. It is not the SmallGPTalk version."
	^ clientVersion
]

{ #category : #accessing }
SmallGPTalkOpenAIProvider >> clientVersion: aString [
	(aString isString and: [ aString isNotEmpty ])
		ifFalse: [ self error: 'The Codex protocol version must be a string.' ].
	clientVersion := aString
]

{ #category : #accessing }
SmallGPTalkOpenAIProvider >> catalogTimeoutSeconds: aNumber [
	(aNumber isNumber and: [ aNumber > 0 ])
		ifFalse: [ self error: 'The catalog time limit must be greater than zero.' ].
	catalogTimeoutSeconds := aNumber
]

{ #category : #accessing }
SmallGPTalkOpenAIProvider >> modelOptions [
	| catalog |
	account ifNil: [ self error: 'Set an OpenAI account.' ].
	catalog := [ self modelCatalogWith: account credentials ]
		on: SmallGPTalkOpenAIResponseError
		do: [ :failure |
			failure status = 401 ifFalse: [ failure pass ].
			self modelCatalogWith: account refreshCredentials ].
	^ (catalog at: 'models') select: [ :model | (model at: 'visibility' ifAbsent: [ 'list' ]) = 'list' ]
]

{ #category : #'private - transport' }
SmallGPTalkOpenAIProvider >> modelCatalogWith: credentials [
	| client |
	client := clientFactory value.
	^[
		self configure: client credentials: credentials timeout: catalogTimeoutSeconds.
		client
			url: 'https://chatgpt.com/backend-api/codex/models';
			queryAt: 'client_version' put: clientVersion;
			accept: 'application/json';
			get.
		self checkResponse: client response.
		STONJSON fromString: client contents
	] ensure: [ self release: client ]
]

{ #category : #accessing }
SmallGPTalkOpenAIProvider >> account [
	^ account
]

{ #category : #accessing }
SmallGPTalkOpenAIProvider >> account: anAccount [
	account := anAccount
]

{ #category : #accessing }
SmallGPTalkOpenAIProvider >> clientFactory: aBlock [
	clientFactory := aBlock
]

{ #category : #requesting }
SmallGPTalkOpenAIProvider >> respondTo: aSession onText: aBlock run: aRun [
	| body credentials |
	aRun checkCancellation.
	account ifNil: [ self error: 'Set an OpenAI account.' ].
	body := self requestBodyFor: aSession.
	credentials := account credentials.
	^ [
		[ self request: body credentials: credentials onText: aBlock run: aRun ]
			on: SmallGPTalkOpenAIResponseError
			do: [ :failure |
				failure status = 401 ifFalse: [ failure pass ].
				aRun checkCancellation.
				credentials := account refreshCredentials.
				aRun checkCancellation.
				self request: body credentials: credentials onText: aBlock run: aRun ]
	] ensure: [ credentials := nil ]
]

{ #category : #'private - transport' }
SmallGPTalkOpenAIProvider >> request: body credentials: credentials onText: aBlock run: aRun [
	^ aRun
		supervise: [
			| client |
			client := clientFactory value.
			[
				self configure: client credentials: credentials timeout: aRun requestTimeoutSeconds.
				client
					url: self class endpoint;
					streaming: true;
					entity: (ZnEntity json: (self encodeJSON: body)).
				aRun checkCancellation.
				client post.
				self checkResponse: client response.
				(self acceptsStreamType: client response contentType)
					ifFalse: [ self error: 'OpenAI did not return an event stream.' ].
				SmallGPTalkOpenAIStream new
					onText: aBlock;
					readFrom: (ZnCharacterReadStream on: client contents encoding: 'utf8') run: aRun
			] ensure: [ self release: client ] ]
		timeoutSeconds: aRun requestTimeoutSeconds
]

{ #category : #'private - transport' }
SmallGPTalkOpenAIProvider >> acceptsStreamType: aMimeType [
	^ (aMimeType matches: 'text/event-stream' asZnMimeType)
		or: [ aMimeType matches: 'application/octet-stream' asZnMimeType ]
]

{ #category : #'private - transport' }
SmallGPTalkOpenAIProvider >> configure: client credentials: credentials timeout: seconds [
	client
		loggingOff;
		signalProgress: false;
		numberOfRetries: 0;
		dontFollowRedirects;
		timeout: seconds;
		enforceHttpSuccess: false;
		headerAt: 'Authorization' put: 'Bearer ', (credentials at: 'access_token');
		headerAt: 'chatgpt-account-id' put: (credentials at: 'account_id');
		headerAt: 'originator' put: 'smallgptalk';
		headerAt: 'User-Agent' put: 'SmallGPTalk/0.1';
		headerAt: 'OpenAI-Beta' put: 'responses=experimental';
		accept: 'text/event-stream'
]

{ #category : #'private - transport' }
SmallGPTalkOpenAIProvider >> release: client [
	[ client close ] ensure: [
		client request headers removeKey: 'Authorization' ifAbsent: [ ].
		client request headers removeKey: 'chatgpt-account-id' ifAbsent: [ ].
		client resetCredentials ]
]

{ #category : #'private - transport' }
SmallGPTalkOpenAIProvider >> checkResponse: response [
	response code = 200 ifTrue: [ ^ self ].
	(SmallGPTalkOpenAIResponseError status: response code) signal
]

{ #category : #'private - conversion' }
SmallGPTalkOpenAIProvider >> requestBodyFor: aSession [
	| body |
	self validateReasoningEffort: aSession reasoningEffort.
	(aSession model isString and: [ aSession model trimBoth isNotEmpty ])
		ifFalse: [ self error: 'Set an explicit OpenAI model identifier.' ].
	body := Dictionary new
		at: 'model' put: aSession model;
		at: 'reasoning' put: (Dictionary new at: 'effort' put: aSession reasoningEffort; yourself);
		at: 'store' put: false;
		at: 'stream' put: true;
		at: 'instructions' put: aSession instructions;
		at: 'input' put: (self inputFor: aSession context messages);
		at: 'include' put: #('reasoning.encrypted_content');
		at: 'tool_choice' put: 'auto';
		at: 'parallel_tool_calls' put: true;
		yourself.
	aSession tools ifNotEmpty: [
		body at: 'tools' put: (aSession tools collect: [ :tool | self definitionFor: tool ]) asArray ].
	^ body
]

{ #category : #'private - conversion' }
SmallGPTalkOpenAIProvider >> definitionFor: tool [
	^ Dictionary new
		at: 'type' put: 'function';
		at: 'name' put: tool name;
		at: 'description' put: tool description;
		at: 'parameters' put: tool inputSchema;
		at: 'strict' put: false;
		yourself
]

{ #category : #'private - conversion' }
SmallGPTalkOpenAIProvider >> inputFor: messages [
	| items |
	items := OrderedCollection new.
	messages do: [ :message |
		message role = #user ifTrue: [
			items add: (Dictionary new
				at: 'role' put: 'user';
				at: 'content' put: message text;
				yourself) ].
		message role = #assistant ifTrue: [
			message providerItems
				ifEmpty: [ self addAssistant: message to: items ]
				ifNotEmpty: [ items addAll: message providerItems ] ].
		message role = #tool ifTrue: [
			items add: (Dictionary new
				at: 'type' put: 'function_call_output';
				at: 'call_id' put: message callId;
				at: 'output' put: message text;
				yourself) ] ].
	^ items asArray
]

{ #category : #'private - conversion' }
SmallGPTalkOpenAIProvider >> addAssistant: message to: items [
	message text ifNotEmpty: [
		items add: (Dictionary new
			at: 'role' put: 'assistant';
			at: 'content' put: message text;
			yourself) ].
	message toolCalls do: [ :call |
		items add: (Dictionary new
			at: 'type' put: 'function_call';
			at: 'call_id' put: call id;
			at: 'name' put: call name;
			at: 'arguments' put: (self encodeJSON: call arguments);
			yourself) ]
]

{ #category : #'private - conversion' }
SmallGPTalkOpenAIProvider >> encodeJSON: anObject [
	self validateJSON: anObject ancestors: IdentitySet new.
	^ String streamContents: [ :stream |
		(STON jsonWriter on: stream)
			referencePolicy: #ignore;
			nextPut: anObject ]
]

{ #category : #'private - conversion' }
SmallGPTalkOpenAIProvider >> validateJSON: anObject ancestors: ancestors [
	((anObject isKindOf: Dictionary) or: [ anObject isArray ])
		ifFalse: [ ^ self ].
	(ancestors includes: anObject) ifTrue: [
		self error: 'The OpenAI request contains a circular reference.' ].
	ancestors add: anObject.
	[ anObject do: [ :value | self validateJSON: value ancestors: ancestors ] ]
		ensure: [ ancestors remove: anObject ]
]

{ #category : #accessing }
SmallGPTalkOpenAIProvider >> models [
	^ (self modelOptions collect: [ :model | model at: 'slug' ]) asArray
]

{ #category : 'validation' }
SmallGPTalkOpenAIProvider >> validateReasoningEffort: effort [
	(#('none' 'minimal' 'low' 'medium' 'high' 'xhigh' 'max' 'ultra') includes: effort)
		ifFalse: [ self error: 'Select a valid OpenAI reasoning effort.' ]
]
