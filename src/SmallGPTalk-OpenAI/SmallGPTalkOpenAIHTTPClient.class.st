Class {
	#name : 'SmallGPTalkOpenAIHTTPClient',
	#superclass : 'ZnClient',
	#instVars : [ 'trustedHost' ],
	#category : 'SmallGPTalk-OpenAI',
	#package : 'SmallGPTalk-OpenAI'
}

{ #category : 'private' }
SmallGPTalkOpenAIHTTPClient >> newConnectionTo: url [
	self requireHTTPS: url.
	(ZnNetworkingUtils shouldProxyUrl: url) ifTrue: [
		self error: 'The OpenAI connection does not support an HTTP proxy.' ].
	trustedHost := nil.
	^ super newConnectionTo: url
]

{ #category : 'private' }
SmallGPTalkOpenAIHTTPClient >> setupTLSTo: url [
	[
		connection sslSession certificateName: self certificate.
		connection sslSession serverName: url host.
		connection connect.
		self validateTLS: connection sslSession for: url
	] on: Error do: [ :failure | self close. failure pass ]
]

{ #category : 'private' }
SmallGPTalkOpenAIHTTPClient >> requireHTTPS: url [
	(url notNil and: [ url hasSecureScheme and: [ url host isString and: [ url host isNotEmpty ] ] ])
		ifFalse: [ self error: 'The OpenAI connection requires HTTPS.' ]
]

{ #category : 'private' }
SmallGPTalkOpenAIHTTPClient >> validateTLS: session for: url [
	| peer |
	self requireHTTPS: url.
	session certificateVerificationState = 0 ifFalse: [
		self error: 'The server certificate is not trusted.' ].
	peer := session peerCertificateName.
	(peer isString and: [ peer asLowercase = url host asLowercase ]) ifFalse: [
		self error: 'The server certificate does not match the host.' ].
	trustedHost := url host asLowercase
]

{ #category : 'private - protocol' }
SmallGPTalkOpenAIHTTPClient >> writeRequest [
	self requireHTTPS: request url.
	trustedHost = request url host asLowercase ifFalse: [
		self error: 'Verify the server certificate before the request.' ].
	^ super writeRequest
]

{ #category : 'cleanup' }
SmallGPTalkOpenAIHTTPClient >> close [
	trustedHost := nil.
	^ super close
]
