"Supply controlled HTTP responses for provider tests."
Class {
	#name : #SmallGPTalkProviderClient,
	#superclass : #ZnClient,
	#instVars : [ 'replyCode', 'replyBody', 'replyType', 'postCount', 'getCount', 'closeCount', 'postFailure', 'postBlock', 'capturedRequest' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : #initialization }
SmallGPTalkProviderClient >> initialize [
	super initialize.
	replyCode := 200.
	replyBody := ''.
	replyType := 'text/event-stream'.
	postCount := 0.
	getCount := 0.
	closeCount := 0
]

{ #category : #accessing }
SmallGPTalkProviderClient >> replyType: aString [
	replyType := aString
]

{ #category : #accessing }
SmallGPTalkProviderClient >> replyCode: aNumber body: aString [
	replyCode := aNumber.
	replyBody := aString
]

{ #category : #accessing }
SmallGPTalkProviderClient >> postFailure: aBoolean [
	postFailure := aBoolean
]

{ #category : #accessing }
SmallGPTalkProviderClient >> postBlock: aBlock [
	postBlock := aBlock
]

{ #category : #accessing }
SmallGPTalkProviderClient >> postCount [
	^ postCount
]

{ #category : #accessing }
SmallGPTalkProviderClient >> getCount [
	^ getCount
]

{ #category : #accessing }
SmallGPTalkProviderClient >> closeCount [
	^ closeCount
]

{ #category : #accessing }
SmallGPTalkProviderClient >> capturedRequest [
	^ capturedRequest
]

{ #category : 'operations' }
SmallGPTalkProviderClient >> post [
	postCount := postCount + 1.
	capturedRequest := request copy.
	postBlock ifNotNil: [ postBlock value ].
	postFailure = true ifTrue: [ self error: 'The test connection failed.' ].
	response := ZnResponse statusCode: replyCode.
	response entity: (ZnEntity text: replyBody).
	response entity contentType: replyType asZnMimeType.
	^ self contents
]

{ #category : 'operations' }
SmallGPTalkProviderClient >> get [
	getCount := getCount + 1.
	capturedRequest := request copy.
	response := ZnResponse statusCode: replyCode.
	response entity: (ZnEntity json: replyBody).
	^ self contents
]

{ #category : 'accessing - response' }
SmallGPTalkProviderClient >> contents [
	^ self streaming
		ifTrue: [ replyBody utf8Encoded readStream ]
		ifFalse: [ replyBody ]
]

{ #category : 'cleanup' }
SmallGPTalkProviderClient >> close [
	closeCount := closeCount + 1.
	super close
]
