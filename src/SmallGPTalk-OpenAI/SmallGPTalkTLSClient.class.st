"Gate HTTP writes on a verified direct TLS connection."
Class {
 #name : 'SmallGPTalkTLSClient',
 #superclass : 'ZnClient',
 #instVars : [ 'verifiedHost' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'private' }
SmallGPTalkTLSClient >> newConnectionTo: url [
 verifiedHost := nil.
 url hasSecureScheme ifFalse: [ self error: 'Use HTTPS for account requests.' ].
 (ZnNetworkingUtils shouldProxyUrl: url) ifTrue: [ self error: 'Account requests require a direct TLS connection.' ].
 ^ super newConnectionTo: url
]

{ #category : 'private' }
SmallGPTalkTLSClient >> setupTLSTo: url [
 [
  super setupTLSTo: url.
  self verify: connection sslSession for: url host
 ] on: Error do: [ :error | self close. error pass ]
]

{ #category : 'verification' }
SmallGPTalkTLSClient >> verify: tls for: host [
 verifiedHost := nil.
 tls certificateVerificationState = 0 ifFalse: [ self error: 'The TLS certificate is not trusted.' ].
 (tls peerCertificateName isString and: [ tls peerCertificateName asLowercase = host asLowercase ])
  ifFalse: [ self error: 'The TLS certificate does not match the host.' ].
 verifiedHost := host asLowercase
]

{ #category : 'private' }
SmallGPTalkTLSClient >> writeRequest [
 (request url hasSecureScheme and: [ verifiedHost = request url host asLowercase ])
  ifFalse: [ self error: 'Verify TLS before sending the request.' ].
 ^ super writeRequest
]

{ #category : 'cleanup' }
SmallGPTalkTLSClient >> close [
 verifiedHost := nil.
 ^ super close
]
