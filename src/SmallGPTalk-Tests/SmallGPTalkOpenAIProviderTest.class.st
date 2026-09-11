Class {
 #name : 'SmallGPTalkOpenAIProviderTest',
 #superclass : 'TestCase',
 #instVars : [ 'catalog', 'sent' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkOpenAIProviderTest >> setUp [
 super setUp.
 catalog := STONJSON fromString: '{"models":[{"slug":"gpt-5.6-luna","visibility":"list","supported_reasoning_levels":[{"effort":"low"},{"effort":"high"}]},{"slug":"hidden-model","visibility":"hide","supported_reasoning_levels":[{"effort":"low"}]}]}'
]

{ #category : 'account protocol' }
SmallGPTalkOpenAIProviderTest >> withHeadersDo: aBlock [ ^ aBlock value: Dictionary new ]

{ #category : 'transport protocol' }
SmallGPTalkOpenAIProviderTest >> getJSONWithHeaders: headers [ ^ catalog deepCopy ]

{ #category : 'transport protocol' }
SmallGPTalkOpenAIProviderTest >> post: body headers: headers [
 sent := body.
 ^ SmallGPTalkReply text: 'Done.' calls: #()
]

{ #category : 'fixtures' }
SmallGPTalkOpenAIProviderTest >> provider [
 ^ (Smalltalk globals at: #SmallGPTalkOpenAIProvider) account: self catalog: self responses: self
]

{ #category : 'tests' }
SmallGPTalkOpenAIProviderTest >> testCatalogExposesVisibleModelsAndTheirEfforts [
 | provider description |
 provider := self provider.
 self assert: provider models size equals: 1.
 description := provider models first.
 self assert: description identifier equals: 'gpt-5.6-luna'.
 self assert: description efforts equals: #('low' 'high').
 self should: [ provider model: 'missing-model' effort: 'low' ] raise: Error.
 self should: [ provider model: 'gpt-5.6-luna' effort: 'unknown' ] raise: Error.
 self assert: sent isNil
]

{ #category : 'tests' }
SmallGPTalkOpenAIProviderTest >> testDefaultModelUsesVerifiedIdentifierAndEffort [
 | provider request |
 provider := self provider.
 request := SmallGPTalkRequest text: 'Hello' history: #() agent: nil.
 provider defaultModel respondTo: request.
 self assert: (sent at: 'model') equals: 'gpt-5.6-luna'.
 self assert: ((sent at: 'reasoning') at: 'effort') equals: 'low'.
 (provider model: 'gpt-5.6-luna' effort: 'high') respondTo: request.
 self assert: ((sent at: 'reasoning') at: 'effort') equals: 'high'
]

{ #category : 'tests' }
SmallGPTalkOpenAIProviderTest >> testUnavailableDefaultDoesNotSelectAnotherModel [
 | provider |
 ((catalog at: 'models') first) at: 'slug' put: 'another-model'.
 provider := self provider.
 self should: [ provider defaultModel ] raise: Error.
 self assert: sent isNil
]

{ #category : 'tests' }
SmallGPTalkOpenAIProviderTest >> testInvalidRefreshPreservesTheLastValidCatalog [
 | provider original |
 provider := self provider.
 original := provider models first.
 (catalog at: 'models') first at: 'supported_reasoning_levels' put: 'invalid'.
 self should: [ provider refreshModels ] raise: Error.
 self assert: provider models first identicalTo: original
]

{ #category : 'tests - UI' }
SmallGPTalkOpenAIProviderTest >> testChatSelectionChangesFutureRequestsAndKeepsHistory [
 | provider session chat run original |
 provider := self provider.
 session := SmallGPTalkSession withModel: provider defaultModel.
 run := session send: 'First'. run wait.
 original := run exchange.
 chat := SmallGPTalkChat forSession: session provider: provider.
 [
  chat modelSelector selectModel: 'gpt-5.6-luna' effort: 'high'; applySelection.
  self assert: session model effort equals: 'high'.
  run := session send: 'Next'. run wait.
  self assert: run state equals: #completed.
  self assert: ((sent at: 'reasoning') at: 'effort') equals: 'high'.
  self assert: session conversation first identicalTo: original.
  self assert: session conversation size equals: 2
 ] ensure: [ chat disconnect ]
]

{ #category : 'tests - UI' }
SmallGPTalkOpenAIProviderTest >> testReconnectClearsThePreviousModelSelection [
 | provider chat session model |
 provider := self provider.
 chat := SmallGPTalkChat
  forSession: (SmallGPTalkSession withModel: provider defaultModel)
  provider: provider.
 model := Object new.
 session := SmallGPTalkSession withModel: model.
 [
  chat modelSelector selectModel: 'gpt-5.6-luna' effort: 'high'.
  chat connectTo: session.
  self assert: chat modelSelector availableEfforts isEmpty.
  chat modelSelector applySelection.
  self assert: session model identicalTo: model
 ] ensure: [ chat disconnect ]
]

{ #category : 'tests' }
SmallGPTalkOpenAIProviderTest >> testCatalogSuppliesTheModelContextWindow [
 | provider |
 (catalog at: 'models') first at: 'context_window' put: 272000.
 provider := self provider.
 self assert: provider models first contextWindow equals: 272000.
 self assert: provider defaultModel contextWindow equals: 272000
]
