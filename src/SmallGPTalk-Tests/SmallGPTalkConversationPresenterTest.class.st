Class {
	#name : 'SmallGPTalkConversationPresenterTest',
	#superclass : 'TestCase',
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkConversationPresenterTest >> testSelectionKeepsMessageIdentity [
	| view first second |
	view := SmallGPTalkConversationPresenter new.
	first := SmallGPTalkMessage user: 'Hello'.
	second := SmallGPTalkMessage assistant: 'World'.
	view addObject: first title: 'You' source: first text markdown: false.
	view addObject: second title: 'Assistant' source: second text markdown: true.
	self assert: (view entryAt: 1) object identicalTo: first.
	self assert: (view entryAt: view text size) object identicalTo: second
]

{ #category : 'tests' }
SmallGPTalkConversationPresenterTest >> testDraftBindsToCommittedMessage [
	| view message |
	view := SmallGPTalkConversationPresenter new.
	view appendAssistant: 'A `frag'; appendAssistant: 'ment`'.
	message := SmallGPTalkMessage assistant: 'A `fragment`'.
	view bindCurrentMessage: message.
	self assert: view entries size equals: 1.
	self assert: view entries first object identicalTo: message.
	self assert: (view text asString includesSubstring: 'A fragment').
	self assert: message text equals: 'A `fragment`'
]

{ #category : 'tests' }
SmallGPTalkConversationPresenterTest >> testFinalMessageWithoutTextEventsKeepsEvaluation [
	| view result message |
	view := SmallGPTalkConversationPresenter new.
	result := SmallGPTalkToolResult text: '42'.
	view addObject: result title: 'Evaluation' source: 'Done' markdown: false.
	message := SmallGPTalkMessage assistant: 'The result is 42.'.
	view bindCurrentMessage: message.
	self assert: view entries first object identicalTo: result.
	self assert: view entries last object identicalTo: message
]

{ #category : 'tests' }
SmallGPTalkConversationPresenterTest >> testBrowseResolvesObjectsWithoutEvaluation [
	| view |
	view := SmallGPTalkConversationPresenter new.
	self assert: (view browseTargetFor: 'SmallGPTalkSession') identicalTo: SmallGPTalkSession.
	self assert: (view browseTargetFor: 'SmallGPTalkSession >> #messages') identicalTo: SmallGPTalkSession >> #messages.
	self assert: (view browseTargetFor: 'SmallGPTalkMessage class >> user:') identicalTo: SmallGPTalkMessage class >> #user:.
	self assert: (view browseTargetFor: 'Smalltalk exit: 0') isNil
]

{ #category : 'tests' }
SmallGPTalkConversationPresenterTest >> testCloseReleasesDisplayObjects [
	| view |
	view := SmallGPTalkConversationPresenter new.
	view addObject: Object new title: 'Object' source: 'A result' markdown: false.
	view close.
	self assert: view entries isEmpty.
	self assert: view text isEmpty
]

{ #category : 'tests' }
SmallGPTalkConversationPresenterTest >> testMenuCanInspectFailedEvaluation [
	| view failure |
	view := SmallGPTalkConversationPresenter new.
	failure := SmallGPTalkToolResult error: 'Evaluation failed.'.
	view addObject: failure title: 'Error' source: failure text markdown: false.
	view selectionInterval: (1 to: 1).
	self assert: view selectedEntry object identicalTo: failure.
	self assert: view objectMenu isNotNil
]

{ #category : 'tests' }
SmallGPTalkConversationPresenterTest >> testMultipleCallsDoNotRepeatMessageOrReplaceResults [
	| view response result |
	view := SmallGPTalkConversationPresenter new.
	response := SmallGPTalkMessage assistant: 'Two calls'.
	result := SmallGPTalkToolResult text: 'First result'.
	view bindCurrentMessage: response.
	view addObject: result title: 'Evaluation' source: result text markdown: false.
	view bindCurrentMessage: response.
	self assert: view entries size equals: 2.
	self assert: view entries last object identicalTo: result
]

{ #category : 'tests' }
SmallGPTalkConversationPresenterTest >> testNewTextPreservesSelectionUntilReleased [
	| view selected before |
	view := SmallGPTalkConversationPresenter new.
	view appendAssistant: 'First fragment'.
	view selectionInterval: (1 to: 5).
	selected := view selectedText.
	before := view text asString.
	view appendAssistant: ' and more text'.
	self assert: view selectedText equals: selected.
	self assert: view text asString equals: before.
	view selectionInterval: (1 to: 0).
	view refresh.
	self assert: (view text asString includesSubstring: 'and more text').
	self assert: view selectionInterval isEmpty
]
