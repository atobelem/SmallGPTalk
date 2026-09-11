"Provide a streamed response body for local transport tests."
Class {
	#name : #SmallGPTalkProviderNetworkEntity,
	#superclass : #ZnEntity,
	#instVars : [ 'bytes', 'release' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : 'testing' }
SmallGPTalkProviderNetworkEntity class >> designatedMimeType [
	^ nil
]

{ #category : #'testing' }
SmallGPTalkProviderNetworkEntity class >> matches: aMimeType [
	^ false
]

{ #category : #'accessing' }
SmallGPTalkProviderNetworkEntity >> text: aString [
	bytes := aString utf8Encoded.
	self contentType: 'text/event-stream; charset=utf-8'.
	self contentLength: bytes size
]

{ #category : #'accessing' }
SmallGPTalkProviderNetworkEntity >> release: aSemaphore [
	release := aSemaphore
]

{ #category : #'testing' }
SmallGPTalkProviderNetworkEntity >> isEmpty [
	^ bytes isEmpty
]

{ #category : #'writing' }
SmallGPTalkProviderNetworkEntity >> writeOn: aStream [
	bytes do: [ :byte |
		aStream nextPutAll: (ByteArray with: byte); flush.
		(Delay forMilliseconds: 1) wait ].
	release ifNotNil: [ release waitTimeoutMilliseconds: 5000 ]
]
