Class {
	#name : #SmallGPTalkOpenAIAuthTransport,
	#superclass : #Object,
	#instVars : [ 'timeoutSeconds' ],
	#category : #'SmallGPTalk-OpenAI'
}

{ #category : #initialization }
SmallGPTalkOpenAIAuthTransport >> initialize [
	super initialize.
	timeoutSeconds := 120
]

{ #category : #accessing }
SmallGPTalkOpenAIAuthTransport >> timeoutSeconds: seconds [
	(seconds isNumber and: [ seconds > 0 ]) ifFalse: [
		SmallGPTalkOpenAIAuthError signal: 'The request timeout must be positive.' ].
	timeoutSeconds := seconds
]

{ #category : #requests }
SmallGPTalkOpenAIAuthTransport >> postForm: fields [
	| client response |
	client := SmallGPTalkOpenAIHTTPClient new.
	[
		client loggingOff;
			url: SmallGPTalkOpenAIAuth tokenUrl;
			numberOfRetries: 0;
			followRedirects: false;
			timeout: timeoutSeconds.
		fields keysAndValuesDo: [ :key :value | client formAt: key put: value ].
		[ [ client post ]
			valueWithinMilliseconds: (timeoutSeconds * 1000) rounded
			onTimeout: [ SmallGPTalkOpenAIAuthError signal: 'The account request time limit expired.' ]
		] on: Error do: [ :exception |
			SmallGPTalkOpenAIAuthError signal: 'The account request failed.' ].
		response := client response.
		response isSuccess ifFalse: [
			SmallGPTalkOpenAIAuthError signal: 'The account request failed. HTTP status: ', response code asString ].
		^ [ STONJSON fromString: response contents ] on: Error do: [ :exception |
			SmallGPTalkOpenAIAuthError signal: 'The account response is not valid JSON.' ]
	] ensure: [
		client resetEntity; resetCredentials; close.
		response ifNotNil: [ response entity: nil ] ]
]
