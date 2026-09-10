Class {
	#name : 'SmallGPTalkKeychainTLSTest',
	#superclass : 'TestCase',
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkKeychainTLSTest >> testValidCertificate [
	SmallGPTalkOpenAIHTTPClient new
		validateTLS: (SmallGPTalkKeychainTLSSessionStub new verificationState: 0 peer: 'AUTH.OPENAI.COM'; yourself)
		for: 'https://auth.openai.com' asZnUrl
]

{ #category : 'tests' }
SmallGPTalkKeychainTLSTest >> testRejectsUntrustedCertificate [
	#(-1 1 2 4 8 16 32) do: [ :status |
		self should: [ SmallGPTalkOpenAIHTTPClient new
			validateTLS: (SmallGPTalkKeychainTLSSessionStub new verificationState: status peer: 'auth.openai.com'; yourself)
			for: 'https://auth.openai.com' asZnUrl ] raise: Error ]
]

{ #category : 'tests' }
SmallGPTalkKeychainTLSTest >> testRejectsWrongCertificateHost [
	#('wrong.example' '*.openai.com' '') do: [ :host |
		self should: [ SmallGPTalkOpenAIHTTPClient new
			validateTLS: (SmallGPTalkKeychainTLSSessionStub new verificationState: 0 peer: host; yourself)
			for: 'https://auth.openai.com' asZnUrl ] raise: Error ]
]

{ #category : 'tests' }
SmallGPTalkKeychainTLSTest >> testRejectsHTTPBeforeConnection [
	| client |
	client := SmallGPTalkOpenAIHTTPClient new.
	self should: [ client newConnectionTo: 'http://auth.openai.com' asZnUrl ] raise: Error.
	self assert: client connection isNil
]

{ #category : 'tests' }
SmallGPTalkKeychainTLSTest >> testRejectsRequestBeforeVerification [
	| client |
	client := SmallGPTalkOpenAIHTTPClient new url: 'https://auth.openai.com'; yourself.
	self should: [ client writeRequest ] raise: Error.
	self assert: client connection isNil
]

{ #category : 'tests' }
SmallGPTalkKeychainTLSTest >> testRejectsHostChangeAfterVerification [
	| client |
	client := SmallGPTalkOpenAIHTTPClient new.
	client validateTLS: (SmallGPTalkKeychainTLSSessionStub new verificationState: 0 peer: 'auth.openai.com'; yourself)
		for: 'https://auth.openai.com' asZnUrl.
	client url: 'https://wrong.example'.
	self should: [ client writeRequest ] raise: Error
]
