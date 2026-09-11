"Return controlled model responses and count requests in offline tests."
Class {
	#name : #SmallGPTalkCoreTestProvider,
	#superclass : #Object,
	#instVars : [ 'responseBlock', 'requestCount' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : #'initialization' }
SmallGPTalkCoreTestProvider >> initialize [
	super initialize.
	requestCount := 0
]

{ #category : #'accessing' }
SmallGPTalkCoreTestProvider >> responseBlock: aBlock [
	responseBlock := aBlock
]

{ #category : #'accessing' }
SmallGPTalkCoreTestProvider >> requestCount [
	^ requestCount
]

{ #category : #'requests' }
SmallGPTalkCoreTestProvider >> respondTo: aSession onText: aBlock run: aRun [
	requestCount := requestCount + 1.
	^ responseBlock value: aSession value: aBlock value: aRun
]
