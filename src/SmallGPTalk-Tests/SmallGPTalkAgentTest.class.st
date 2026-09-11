Class {
	#name : 'SmallGPTalkAgentTest',
	#superclass : 'TestCase',
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkAgentTest >> testAgentStartsIndependentSessions [
	| agent first second |
	agent := SmallGPTalkAgent new tools: SmallGPTalkImageTools all; yourself.
	first := agent newSession.
	second := agent newSession.
	self assert: first agent identicalTo: agent.
	self assert: second agent identicalTo: agent.
	first addMessage: (SmallGPTalkMessage user: 'First conversation').
	first model: 'first-model'; reasoningEffort: 'high'.
	self assert: second messages isEmpty.
	self assert: second model isNil.
	self assert: second reasoningEffort equals: 'medium'.
	self deny: first tools first identicalTo: second tools first.
	first tools first timeoutSeconds: 30.
	self assert: second tools first timeoutSeconds equals: 10
]

{ #category : 'tests' }
SmallGPTalkAgentTest >> testAgentChangesApplyOnlyToNewSessions [
	| agent first second |
	agent := SmallGPTalkAgent new instructions: 'Initial instructions.'; tools: SmallGPTalkImageTools all; yourself.
	first := agent newSession.
	agent instructions: 'New instructions.'; tools: #().
	second := agent newSession.
	self assert: first instructions equals: 'Initial instructions.'.
	self assert: first tools size equals: 1.
	self assert: second instructions equals: 'New instructions.'.
	self assert: second tools isEmpty.
	first instructions: 'Session override.'.
	self assert: agent instructions equals: 'New instructions.'
]

{ #category : 'tests' }
SmallGPTalkAgentTest >> testCannotReplaceAgentAfterConversationStarts [
	| session |
	session := SmallGPTalkAgent new newSession.
	session addMessage: (SmallGPTalkMessage user: 'Hello.').
	self should: [ session agent: SmallGPTalkAgent new ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkAgentTest >> testNewChatReusesAgentDefinition [
	| chat other |
	chat := SmallGPTalkChat new.
	other := chat createChat.
	self assert: other agent identicalTo: chat agent.
	self assert: (chat agent tools collect: #name) equals: #('evaluate')
]

{ #category : 'tests' }
SmallGPTalkAgentTest >> testSessionToolsStartWithoutPreviousExecutionState [
	| prototype agent session |
	prototype := SmallGPTalkCoreTestTool new.
	prototype execute: Dictionary new context: nil.
	agent := SmallGPTalkAgent new tools: { prototype }; yourself.
	session := agent newSession.
	self assert: prototype executionCount equals: 1.
	self assert: session tools first executionCount equals: 0
]

{ #category : 'tests' }
SmallGPTalkAgentTest >> testFailedAgentConfigurationPreservesSession [
	| original replacement session |
	original := SmallGPTalkAgent new instructions: 'Original.'; tools: SmallGPTalkImageTools all; yourself.
	session := original newSession.
	replacement := SmallGPTalkAgent new instructions: 'Replacement.'; tools: { SmallGPTalkTool new }; yourself.
	self should: [ session agent: replacement ] raise: Error.
	self assert: session agent identicalTo: original.
	self assert: session instructions equals: 'Original.'.
	self assert: (session tools collect: #name) equals: #('evaluate')
]
