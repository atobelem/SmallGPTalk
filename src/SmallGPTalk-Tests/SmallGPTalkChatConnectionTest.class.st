Class {
	#name : 'SmallGPTalkChatConnectionTest',
	#superclass : 'TestCase',
	#instVars : [ 'connection', 'fixture', 'events', 'finished' ],
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkChatConnectionTest >> setUp [
	super setUp.
	fixture := SmallGPTalkConnectionFixture new.
	connection := SmallGPTalkChatConnection new account: fixture provider: fixture; yourself.
	events := OrderedCollection new.
	finished := Semaphore new
]

{ #category : 'running' }
SmallGPTalkChatConnectionTest >> tearDown [
	connection cancel.
	super tearDown
]

{ #category : 'private' }
SmallGPTalkChatConnectionTest >> record: event [
	events add: event.
	(#(connected failed signedOut) includes: (event at: #type)) ifTrue: [ finished signal ]
]

{ #category : 'tests' }
SmallGPTalkChatConnectionTest >> testRestoresAccountAndLoadsCatalog [
	fixture catalogBlock: [ #('catalog-fixture') ].
	connection connectOnEvent: [ :event | self record: event ].
	self deny: (finished waitTimeoutMilliseconds: 2000).
	self assert: (events collect: [ :event | event at: #type ]) asArray equals: #(loadingModels connected).
	self assert: (events last at: #models) equals: #('catalog-fixture')
]

{ #category : 'tests' }
SmallGPTalkChatConnectionTest >> testCatalogFailureIsDetached [
	fixture catalogBlock: [ Error signal: 'Catalog unavailable.' ].
	connection connectOnEvent: [ :event | self record: event ].
	self deny: (finished waitTimeoutMilliseconds: 2000).
	self assert: (events last at: #type) equals: #failed.
	self assert: (events last at: #error) class equals: SmallGPTalkFailure
]

{ #category : 'tests' }
SmallGPTalkChatConnectionTest >> testCancelLoginDoesNotRequestCatalog [
	fixture authenticated: false.
	connection connectOnEvent: [ :event |
		(event at: #type) = #authorization ifTrue: [ connection cancel ].
		self record: event ].
	self deny: (finished waitTimeoutMilliseconds: 2000).
	self assert: fixture requests equals: 0.
	self assert: (events last at: #type) equals: #failed
]

{ #category : 'tests' }
SmallGPTalkChatConnectionTest >> testSignOut [
	connection logoutOnEvent: [ :event | self record: event ].
	self deny: (finished waitTimeoutMilliseconds: 2000).
	self deny: fixture isAuthenticated.
	self assert: (events last at: #type) equals: #signedOut
]
