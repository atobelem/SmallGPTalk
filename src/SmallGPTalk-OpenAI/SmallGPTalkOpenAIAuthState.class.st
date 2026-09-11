"Share login and credential synchronization across account objects for one store."
Class {
	#name : #SmallGPTalkOpenAIAuthState,
	#superclass : #Object,
	#instVars : [ 'lock', 'generation', 'activeLogin' ],
	#classVars : [ 'NativeStates', 'OtherStates', 'RegistryLock' ],
	#category : #'SmallGPTalk-OpenAI'
}

{ #category : 'class initialization' }
SmallGPTalkOpenAIAuthState class >> initialize [
	NativeStates := Dictionary new.
	OtherStates := WeakIdentityKeyDictionary new.
	RegistryLock := Mutex new
]

{ #category : #accessing }
SmallGPTalkOpenAIAuthState class >> forStore: aStore [
	RegistryLock ifNil: [ self initialize ].
	^ RegistryLock critical: [
		(aStore isKindOf: SmallGPTalkKeychainStore)
			ifTrue: [ NativeStates
				at: { aStore service copy. aStore account copy }
				ifAbsentPut: [ self new ] ]
			ifFalse: [ OtherStates at: aStore ifAbsentPut: [ self new ] ] ]
]

{ #category : #initialization }
SmallGPTalkOpenAIAuthState >> initialize [
	super initialize.
	lock := Mutex new.
	generation := 0
]

{ #category : #accessing }
SmallGPTalkOpenAIAuthState >> lock [
	^ lock
]

{ #category : #accessing }
SmallGPTalkOpenAIAuthState >> generation [
	^ generation
]

{ #category : #accessing }
SmallGPTalkOpenAIAuthState >> nextGeneration [
	generation := generation + 1.
	^ generation
]

{ #category : #accessing }
SmallGPTalkOpenAIAuthState >> activeLogin [
	^ activeLogin
]

{ #category : #accessing }
SmallGPTalkOpenAIAuthState >> activeLogin: operation [
	activeLogin := operation
]

{ #category : #accessing }
SmallGPTalkOpenAIAuthState >> releaseLogin: operation [
	lock critical: [ activeLogin == operation ifTrue: [ activeLogin := nil ] ]
]
