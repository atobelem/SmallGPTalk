"Receive the local OAuth callback without taking over an occupied port."
Class {
	#name : #SmallGPTalkOpenAIAuthServer,
	#superclass : #ZnSingleThreadedServer,
	#category : #'SmallGPTalk-OpenAI'
}

{ #category : 'public' }
SmallGPTalkOpenAIAuthServer >> start [
	self isRunning ifTrue: [ self error: 'The callback server is active.' ].
	self loggingOff.
	[ self initializeServerSocket ] on: Error do: [ :exception |
		self releaseServerSocket.
		SmallGPTalkOpenAIAuthError signal: 'Cannot open the login callback port. Close the other login operation.' ].
	process := [ [
		[ [ self serveConnectionOn: serverSocket ] repeat ]
			on: Error do: [ :exception | self delegate callbackServerFailed ]
	] ensure: [ self releaseServerSocket ] ]
		forkAt: Processor highIOPriority named: 'SmallGPTalk login callback'
]

{ #category : 'private' }
SmallGPTalkOpenAIAuthServer >> closeDelegate [
	"The login operation owns this server."
	^ self
]
