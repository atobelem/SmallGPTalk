Class {
 #name : 'SmallGPTalkTLSTest',
 #superclass : 'TestCase',
 #instVars : [ 'verification', 'peer' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'TLS protocol' }
SmallGPTalkTLSTest >> certificateVerificationState [ ^ verification ]

{ #category : 'TLS protocol' }
SmallGPTalkTLSTest >> peerCertificateName [ ^ peer ]

{ #category : 'tests' }
SmallGPTalkTLSTest >> testPlainHTTPIsRejectedBeforeConnection [
 | client |
 client := SmallGPTalkTLSClient new.
 self should: [ client newConnectionTo: 'http://127.0.0.1:1' asZnUrl ]
  raise: Error withExceptionDo: [ :error | self assert: error messageText equals: 'Use HTTPS for account requests.' ]
]

{ #category : 'tests' }
SmallGPTalkTLSTest >> testUntrustedCertificateAndDifferentHostAreRejected [
 | client |
 client := SmallGPTalkTLSClient new.
 verification := 1. peer := 'auth.openai.com'.
 self should: [ client verify: self for: 'auth.openai.com' ] raise: Error.
 verification := 0. peer := 'other.example'.
 self should: [ client verify: self for: 'auth.openai.com' ] raise: Error.
 peer := 'auth.openai.com'.
 client verify: self for: 'auth.openai.com'
]

{ #category : 'tests' }
SmallGPTalkTLSTest >> testRequestCannotBeWrittenBeforeVerification [
 | client |
 client := SmallGPTalkTLSClient new url: 'https://auth.openai.com'; yourself.
 self should: [ client writeRequest ] raise: Error
  withExceptionDo: [ :error | self assert: error messageText equals: 'Verify TLS before sending the request.' ]
]
