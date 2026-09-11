"Record client disconnects in local stream tests. Other server errors remain visible."
Class {
	#name : 'SmallGPTalkProviderNetworkServer',
	#superclass : 'ZnSingleThreadedServer',
	#instVars : [ 'disconnectCount', 'disconnected' ],
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'initialization' }
SmallGPTalkProviderNetworkServer >> initialize [
	super initialize.
	disconnectCount := 0.
	disconnected := Semaphore new
]

{ #category : 'request handling' }
SmallGPTalkProviderNetworkServer >> serveConnectionOn: listeningSocket [
	[ super serveConnectionOn: listeningSocket ] on: ConnectionClosed do: [ :exception |
		disconnectCount := disconnectCount + 1.
		disconnected signal ]
]

{ #category : 'accessing' }
SmallGPTalkProviderNetworkServer >> disconnectCount [ ^ disconnectCount ]

{ #category : 'synchronization' }
SmallGPTalkProviderNetworkServer >> waitForDisconnectMilliseconds: milliseconds [
	^ disconnected waitTimeoutMilliseconds: milliseconds
]
