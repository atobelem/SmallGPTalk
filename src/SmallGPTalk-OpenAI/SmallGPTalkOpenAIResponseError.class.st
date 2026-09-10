Class {
	#name : #SmallGPTalkOpenAIResponseError,
	#superclass : #Error,
	#instVars : [ 'status' ],
	#category : #'SmallGPTalk-OpenAI'
}

{ #category : #'instance creation' }
SmallGPTalkOpenAIResponseError class >> status: aNumber [
	^ self new status: aNumber; yourself
]

{ #category : #accessing }
SmallGPTalkOpenAIResponseError >> status [
	^ status
]

{ #category : #accessing }
SmallGPTalkOpenAIResponseError >> status: aNumber [
	status := aNumber
]

{ #category : #accessing }
SmallGPTalkOpenAIResponseError >> messageText [
	status = 401 ifTrue: [ ^ 'OpenAI did not accept the account credentials. Sign in again.' ].
	status = 429 ifTrue: [ ^ 'The OpenAI account limit or rate limit was reached.' ].
	^ 'The OpenAI request failed. HTTP status: ', status asString, '.'
]
