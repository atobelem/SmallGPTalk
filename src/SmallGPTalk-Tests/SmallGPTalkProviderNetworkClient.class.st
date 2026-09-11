"Simulate network operations and connection cleanup in provider tests."
Class {
	#name : #SmallGPTalkProviderNetworkClient,
	#superclass : #ZnClient,
	#instVars : [ 'localUrl', 'closedConnection' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : #'accessing' }
SmallGPTalkProviderNetworkClient >> localUrl: aUrl [
	localUrl := aUrl
]

{ #category : 'accessing - request' }
SmallGPTalkProviderNetworkClient >> url: aUrl [
	^ super url: localUrl
]

{ #category : #'accessing' }
SmallGPTalkProviderNetworkClient >> closedConnection [
	^ closedConnection = true
]

{ #category : 'cleanup' }
SmallGPTalkProviderNetworkClient >> close [
	| hadConnection |
	hadConnection := self isConnected.
	super close.
	hadConnection ifTrue: [ closedConnection := self isConnected not ]
]
