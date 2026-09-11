"Select models through the account catalog before creating request adapters."
Class {
 #name : 'SmallGPTalkOpenAIProvider',
 #superclass : 'Object',
 #instVars : [ 'account', 'catalog', 'responses', 'models' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'instance creation' }
SmallGPTalkOpenAIProvider class >> account: connection catalog: catalogTransport responses: responseTransport [
 ^ self new account: connection catalog: catalogTransport responses: responseTransport; yourself
]

{ #category : 'instance creation' }
SmallGPTalkOpenAIProvider class >> account: connection [
 ^ self account: connection
  catalog: (SmallGPTalkOpenAIHTTP
   endpoint: 'https://chatgpt.com/backend-api/codex/models?client_version=0.153.4'
   clients: [ SmallGPTalkTLSClient new ])
  responses: (SmallGPTalkOpenAIHTTP
   endpoint: 'https://chatgpt.com/backend-api/codex/responses'
   clients: [ SmallGPTalkTLSClient new ])
]

{ #category : 'initialization' }
SmallGPTalkOpenAIProvider >> account: connection catalog: catalogTransport responses: responseTransport [
 account := connection.
 catalog := catalogTransport.
 responses := responseTransport
]

{ #category : 'catalog' }
SmallGPTalkOpenAIProvider >> refreshModels [
 | data records selected |
 data := account withHeadersDo: [ :headers | catalog getJSONWithHeaders: headers ].
 data isDictionary ifFalse: [ self error: 'The model catalog is invalid.' ].
 records := data at: 'models' ifAbsent: [ nil ].
 (records isArray and: [ records allSatisfy: #isDictionary ])
  ifFalse: [ self error: 'The model catalog is invalid.' ].
 selected := (records select: [ :record | (record at: 'visibility' ifAbsent: [ 'list' ]) = 'list' ])
  collect: [ :record | SmallGPTalkOpenAIModelDescription from: record ].
 (selected collect: #identifier) asSet size = selected size
  ifFalse: [ self error: 'The catalog has repeated model identifiers.' ].
 models := selected.
 ^ self models
]

{ #category : 'accessing' }
SmallGPTalkOpenAIProvider >> models [
 models ifNil: [ self refreshModels ].
 ^ models copy
]

{ #category : 'selection' }
SmallGPTalkOpenAIProvider >> model: identifier effort: level [
 | description |
 description := self models detect: [ :each | each identifier = identifier ]
  ifNone: [ self error: 'The model is not in the account catalog.' ].
 description requireEffort: level.
 ^ (SmallGPTalkOpenAIModel model: identifier effort: level account: account transport: responses)
  contextWindow: description contextWindow; yourself
]

{ #category : 'selection' }
SmallGPTalkOpenAIProvider >> defaultModel [
 ^ self model: 'gpt-5.6-luna' effort: 'low'
]
