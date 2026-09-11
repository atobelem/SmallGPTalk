"Bind the login listener before returning, only on the loopback interface."
Class {
 #name : 'SmallGPTalkCallbackServer',
 #superclass : 'ZnSingleThreadedServer',
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'initialization' }
SmallGPTalkCallbackServer >> initialize [
 super initialize.
 self bindingAddress: #[127 0 0 1].
 self loggingOff
]

{ #category : 'lifecycle' }
SmallGPTalkCallbackServer >> start [
 self isRunning ifTrue: [ self error: 'The callback server is already running.' ].
 [ self initializeServerSocket ] on: Error do: [ :error |
  self releaseServerSocket.
  self error: 'The login callback port is not available.' ].
 process := [
  [ [ self serveConnectionOn: serverSocket ] repeat ]
   ensure: [ self releaseServerSocket. self closeDelegate ]
 ] forkAt: Processor highIOPriority
]

{ #category : 'private' }
SmallGPTalkCallbackServer >> closeDelegate [
 self delegate ifNotNil: [ :callback | callback cancel ]
]
