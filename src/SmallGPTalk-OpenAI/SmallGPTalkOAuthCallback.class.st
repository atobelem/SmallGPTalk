"Receive one valid browser callback and release its form to one consumer."
Class {
 #name : 'SmallGPTalkOAuthCallback',
 #superclass : 'Object',
 #instVars : [ 'request', 'ready', 'lock', 'state', 'form', 'url' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'instance creation' }
SmallGPTalkOAuthCallback class >> request: authorization [
 ^ self new request: authorization; yourself
]

{ #category : 'initialization' }
SmallGPTalkOAuthCallback >> request: authorization [
 request := authorization.
 url := request authorizationUrl.
 ready := Semaphore new.
 lock := Semaphore forMutualExclusion.
 state := #waiting
]

{ #category : 'accessing' }
SmallGPTalkOAuthCallback >> authorizationUrl [ ^ url copy ]

{ #category : 'server protocol' }
SmallGPTalkOAuthCallback >> handleRequest: incoming [
 (incoming method = #GET and: [ incoming uri path = 'auth/callback' ])
  ifFalse: [ ^ self response: 404 text: 'The callback route is not available.' ].
 ^ lock critical: [
  state = #waiting ifFalse: [ self response: 409 text: 'This callback is closed.' ]
   ifTrue: [
    [
     self receive: incoming
    ] on: Error do: [ :error | self response: 400 text: 'The login callback is invalid.' ] ] ]
]

{ #category : 'waiting' }
SmallGPTalkOAuthCallback >> awaitForm [
 ready wait.
 ready signal.
 ^ lock critical: [
  | result |
  state = #cancelled ifTrue: [ self error: 'The login callback was cancelled.' ].
  state = #refused ifTrue: [ self error: 'The login was not authorized.' ].
  state = #received ifFalse: [ self error: 'The login form has already been received.' ].
  result := form.
  form := nil.
  state := #consumed.
  result ]
]

{ #category : 'private' }
SmallGPTalkOAuthCallback >> receive: incoming [
 | callbackState |
 callbackState := incoming uri queryAt: 'state' ifAbsent: [ nil ].
 (incoming uri queryAt: 'error' ifAbsent: [ nil ]) ifNotNil: [
  request refuseForState: callbackState.
  request := nil.
  state := #refused.
  ready signal.
  ^ self response: 200 text: 'The login was not authorized. Return to Pharo.' ].
 form := request tokenFormFor: (incoming uri queryAt: 'code' ifAbsent: [ nil ])
  state: callbackState.
 request := nil.
 state := #received.
 ready signal.
 ^ self response: 200 text: 'The login code was received. Return to Pharo.'
]

{ #category : 'cancellation' }
SmallGPTalkOAuthCallback >> cancel [
 lock critical: [
  (#(waiting received) includes: state) ifTrue: [
   state := #cancelled.
   request := nil.
   form ifNotNil: [ form removeAll. form := nil ].
   ready signal ] ]
]

{ #category : 'private' }
SmallGPTalkOAuthCallback >> response: code text: text [
 ^ (ZnResponse statusCode: code) entity: (ZnEntity text: text); setConnectionClose; yourself
]
