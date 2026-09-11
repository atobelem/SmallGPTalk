"Report an HTTP status without retaining request headers or response data."
Class {
 #name : 'SmallGPTalkHTTPFailure',
 #superclass : 'Error',
 #instVars : [ 'status' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'signalling' }
SmallGPTalkHTTPFailure class >> status: code [
 ^ (self new status: code; yourself) signal
]

{ #category : 'initialization' }
SmallGPTalkHTTPFailure >> status: code [ status := code ]

{ #category : 'accessing' }
SmallGPTalkHTTPFailure >> status [ ^ status ]

{ #category : 'accessing' }
SmallGPTalkHTTPFailure >> messageText [
 ^ 'The model request failed with HTTP ', status asString, '.'
]
