Class {
	#name : 'SmallGPTalkKeychainTLSSessionStub',
	#superclass : 'Object',
	#instVars : [ 'verificationState', 'peer' ],
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'accessing' }
SmallGPTalkKeychainTLSSessionStub >> verificationState: anInteger peer: aString [
	verificationState := anInteger.
	peer := aString
]

{ #category : 'accessing' }
SmallGPTalkKeychainTLSSessionStub >> certificateVerificationState [
	^ verificationState
]

{ #category : 'accessing' }
SmallGPTalkKeychainTLSSessionStub >> peerCertificateName [
	^ peer
]
