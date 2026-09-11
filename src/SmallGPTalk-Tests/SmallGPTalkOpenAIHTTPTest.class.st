Class {
 #name : 'SmallGPTalkOpenAIHTTPTest',
 #superclass : 'TestCase',
 #instVars : [ 'server', 'received', 'count', 'status', 'tokenResponse', 'eventType', 'catalogResponse', 'streamedText' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkOpenAIHTTPTest >> setUp [
 super setUp.
 count := 0.
 status := 200.
 eventType := 'text/event-stream'.
 server := ZnServer startOn: 0.
 server delegate: self
]

{ #category : 'running' }
SmallGPTalkOpenAIHTTPTest >> tearDown [
 server ifNotNil: [ server stop ].
 super tearDown
]

{ #category : 'server protocol' }
SmallGPTalkOpenAIHTTPTest >> handleRequest: request [
 | response payload |
 count := count + 1.
 catalogResponse ifNotNil: [
  received := request method.
  response := ZnResponse ok: (ZnEntity json: (STONJSON toString: catalogResponse)).
  response statusLine code: status.
  ^ response ].
 tokenResponse ifNotNil: [
  received := request entity fields copy.
  response := ZnResponse ok: (ZnEntity json: (STONJSON toString: tokenResponse)).
  response statusLine code: status.
  ^ response ].
 received := STONJSON fromString: request contents.
 payload := 'data: {"type":"response.completed","response":{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"¡Hola! 日本語"}]}]}}', String lf, String lf.
 streamedText = true ifTrue: [
  payload := 'data: {"type":"response.output_text.delta","delta":"¡Hola!"}', String lf, String lf, payload ].
 response := ZnResponse ok: (ZnEntity with: (eventType = 'application/octet-stream'
  ifTrue: [ payload utf8Encoded ] ifFalse: [ payload ]) type: eventType).
 response statusLine code: status.
 ^ response
]

{ #category : 'tests' }
SmallGPTalkOpenAIHTTPTest >> testHTTPPostReadsUTF8EventStream [
 | transport reply body |
 transport := SmallGPTalkOpenAIHTTP endpoint: 'http://127.0.0.1:', server port asString, '/responses'
  clients: [ ZnClient new ].
 body := Dictionary new at: 'model' put: 'test-model'; yourself.
 reply := transport post: body headers: Dictionary new.
 self assert: reply text equals: '¡Hola! 日本語'.
 self assert: received equals: body.
 self assert: count equals: 1
]

{ #category : 'tests' }
SmallGPTalkOpenAIHTTPTest >> testCatalogGETReadsJSON [
 | transport result |
 catalogResponse := Dictionary new at: 'models' put: #(); yourself.
 transport := SmallGPTalkOpenAIHTTP endpoint: 'http://127.0.0.1:', server port asString, '/models'
  clients: [ ZnClient new ].
 result := transport getJSONWithHeaders: Dictionary new.
 self assert: result equals: catalogResponse.
 self assert: received equals: #GET.
 self assert: count equals: 1
]

{ #category : 'tests' }
SmallGPTalkOpenAIHTTPTest >> testRateLimitDoesNotRetry [
 | transport |
 status := 429.
 transport := SmallGPTalkOpenAIHTTP endpoint: 'http://127.0.0.1:', server port asString, '/responses'
  clients: [ ZnClient new ].
 self should: [ transport post: Dictionary new headers: Dictionary new ]
  raise: Error withExceptionDo: [ :error | self assert: (error messageText includesSubstring: '429') ].
 self assert: count equals: 1
]

{ #category : 'tests' }
SmallGPTalkOpenAIHTTPTest >> testAuthenticationFailureHasAnHTTPStatus [
 | transport |
 status := 401.
 transport := SmallGPTalkOpenAIHTTP endpoint: 'http://127.0.0.1:', server port asString, '/responses'
  clients: [ ZnClient new ].
 self should: [ transport post: Dictionary new headers: Dictionary new ]
  raise: SmallGPTalkHTTPFailure withExceptionDo: [ :failure |
   self assert: failure status equals: 401 ].
 self assert: count equals: 1
]

{ #category : 'account protocol' }
SmallGPTalkOpenAIHTTPTest >> withHeadersDo: aBlock [ ^ aBlock value: Dictionary new ]

{ #category : 'tests' }
SmallGPTalkOpenAIHTTPTest >> testSessionUsesTheComposedHTTPModel [
 | transport model session run seen |
 streamedText := true.
 transport := SmallGPTalkOpenAIHTTP endpoint: 'http://127.0.0.1:', server port asString, '/responses'
  clients: [ ZnClient new ].
 model := SmallGPTalkOpenAIModel model: 'test-model' effort: 'low' account: self transport: transport.
 session := (SmallGPTalkAgent named: 'Ada') newSessionWith: model.
 seen := OrderedCollection new.
 session whenChanged: [ :exchange | seen add: exchange partialText ].
 run := session send: 'Hello'. run wait.
 self assert: run state equals: #completed.
 self assert: run result text equals: '¡Hola! 日本語'.
 self assert: (seen includes: '¡Hola!').
 self assert: (received at: 'model') equals: 'test-model'.
 self assert: ((received at: 'input') first at: 'content') equals: 'Hello'.
 self assert: count equals: 1
]

{ #category : 'tests' }
SmallGPTalkOpenAIHTTPTest >> testTokenFormIsPostedAndTemporaryBodiesAreRemoved [
 | transport client form result |
 client := ZnClient new.
 transport := SmallGPTalkOpenAIHTTP endpoint: 'http://127.0.0.1:', server port asString, '/token'
  clients: [ client ].
 tokenResponse := Dictionary new at: 'access_token' put: 'test-only-token'; yourself.
 form := Dictionary new at: 'code' put: 'test + code'; at: 'grant_type' put: 'authorization_code'; yourself.
 result := transport postForm: form.
 self assert: received size equals: form size.
 form keysAndValuesDo: [ :key :value | self assert: (received at: key) equals: value ].
 self assert: result equals: tokenResponse.
 self assert: client request entity isNil.
 self assert: client response entity isNil.
 self assert: count equals: 1
]

{ #category : 'tests' }
SmallGPTalkOpenAIHTTPTest >> testCodexOctetStreamContainsTheSameSSEProtocol [
 | transport reply |
 eventType := 'application/octet-stream'.
 transport := SmallGPTalkOpenAIHTTP endpoint: 'http://127.0.0.1:', server port asString, '/responses'
  clients: [ ZnClient new ].
 reply := transport post: Dictionary new headers: Dictionary new.
 self assert: reply text equals: '¡Hola! 日本語'
]

{ #category : 'tests' }
SmallGPTalkOpenAIHTTPTest >> testCloseFailureStillClearsAuthenticationHeaders [
 | transport client headers |
 client := SmallGPTalkCloseFailingClient new.
 transport := SmallGPTalkOpenAIHTTP endpoint: 'http://127.0.0.1:', server port asString, '/responses'
  clients: [ client ].
 headers := Dictionary new at: 'Authorization' put: 'Bearer test-only'; yourself.
 self should: [ transport post: Dictionary new headers: headers ] raise: Error
  withExceptionDo: [ :error | self assert: error messageText equals: 'Test connection close failed.' ].
 self deny: (client request headers includesKey: 'Authorization').
 self assert: count equals: 1
]
