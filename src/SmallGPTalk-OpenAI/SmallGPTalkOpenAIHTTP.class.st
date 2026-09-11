"Send one request through a supplied HTTP client and close its stream."
Class {
 #name : 'SmallGPTalkOpenAIHTTP',
 #superclass : 'Object',
 #instVars : [ 'endpoint', 'clients' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'instance creation' }
SmallGPTalkOpenAIHTTP class >> endpoint: url clients: factory [
 ^ self new endpoint: url clients: factory; yourself
]

{ #category : 'initialization' }
SmallGPTalkOpenAIHTTP >> endpoint: url clients: factory [
 endpoint := url copy.
 clients := factory
]

{ #category : 'requests' }
SmallGPTalkOpenAIHTTP >> getJSONWithHeaders: headers [
 | client |
 client := clients value.
 [
  client loggingOff; url: endpoint; numberOfRetries: 0; followRedirects: false;
   timeout: 30; accept: 'application/json'.
  headers keysAndValuesDo: [ :key :value | client headerAt: key put: value ].
  client get.
  client response isSuccess ifFalse: [ SmallGPTalkHTTPFailure status: client response code ].
  ^ [ STONJSON fromString: client contents ] on: Error do: [ :error |
   self error: 'The catalog response is not valid JSON.' ]
 ] ensure: [
  [ client close ] ensure: [
   headers keysDo: [ :key | client request headers removeKey: key ifAbsent: [ ] ] ] ]
]

{ #category : 'requests' }
SmallGPTalkOpenAIHTTP >> post: body headers: headers [
 ^ self post: body headers: headers onText: [ :text | ]
]

{ #category : 'requests' }
SmallGPTalkOpenAIHTTP >> post: body headers: headers onText: observer [
 | client bytes decoder encoder |
 client := clients value.
 [
  client loggingOff; url: endpoint; numberOfRetries: 0; followRedirects: false;
   timeout: 120; streaming: true; accept: 'text/event-stream';
   entity: (ZnEntity json: (STONJSON toString: body)).
  headers keysAndValuesDo: [ :key :value | client headerAt: key put: value ].
  bytes := client post.
  client response isSuccess ifFalse: [
   SmallGPTalkHTTPFailure status: client response code ].
  ((client response contentType matches: 'text/event-stream' asZnMimeType)
   or: [ client response contentType matches: 'application/octet-stream' asZnMimeType ])
   ifFalse: [ self error: 'The model response is not an event stream.' ].
  decoder := SmallGPTalkOpenAIStream new.
  decoder whenText: observer.
  encoder := ZnUTF8Encoder new.
  [ decoder isComplete not and: [ bytes atEnd not ] ] whileTrue: [
   decoder consume: (encoder nextFromStream: bytes) asString ].
  ^ decoder finish
 ] ensure: [
  [ client close ] ensure: [
   headers keysDo: [ :key | client request headers removeKey: key ifAbsent: [ ] ] ] ]
]

{ #category : 'requests' }
SmallGPTalkOpenAIHTTP >> postForm: fields [
 | client |
 client := clients value.
 [
  client loggingOff; url: endpoint; numberOfRetries: 0; followRedirects: false;
   timeout: 120; accept: 'application/json'.
  fields keysAndValuesDo: [ :key :value | client formAt: key put: value ].
  client post.
  client response isSuccess ifFalse: [
   self error: 'The token request failed with HTTP ', client response code asString, '.' ].
  ^ [ STONJSON fromString: client response contents ] on: Error do: [ :error |
   self error: 'The token response is not valid JSON.' ]
 ] ensure: [
  [ client close ] ensure: [
   client request entity: nil.
   client response ifNotNil: [ :response | response entity: nil ] ] ]
]
