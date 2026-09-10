Class {
	#name : #SmallGPTalkProviderAccount,
	#superclass : #Object,
	#instVars : [ 'refreshCount' ],
	#category : #'SmallGPTalk-Tests'
}

{ #category : #initialization }
SmallGPTalkProviderAccount >> initialize [
	super initialize.
	refreshCount := 0
]

{ #category : #accessing }
SmallGPTalkProviderAccount >> credentials [
	^ Dictionary new
		at: 'access_token' put: 'test-access';
		at: 'account_id' put: 'test-account';
		yourself
]

{ #category : #accessing }
SmallGPTalkProviderAccount >> refreshCredentials [
	refreshCount := refreshCount + 1.
	^ self credentials
]

{ #category : #accessing }
SmallGPTalkProviderAccount >> refreshCount [
	^ refreshCount
]
