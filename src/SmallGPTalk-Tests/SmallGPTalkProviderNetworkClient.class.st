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

{ #category : #'accessing' }
SmallGPTalkProviderNetworkClient >> url: aUrl [
	^ super url: localUrl
]

{ #category : #'accessing' }
SmallGPTalkProviderNetworkClient >> closedConnection [
	^ closedConnection = true
]

{ #category : #'operations' }
SmallGPTalkProviderNetworkClient >> close [
	| hadConnection |
	hadConnection := self isConnected.
	super close.
	hadConnection ifTrue: [ closedConnection := self isConnected not ]
]
