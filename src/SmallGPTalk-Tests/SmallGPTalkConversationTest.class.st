Class {
	#name : 'SmallGPTalkConversationTest',
	#superclass : 'TestCase',
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkConversationTest >> testSessionSharesMessageObjectsButProtectsCollection [
	| session message snapshot |
	session := SmallGPTalkSession new.
	message := SmallGPTalkMessage user: 'Hello'.
	session addMessage: message.
	snapshot := session conversation messages.
	self assert: snapshot first identicalTo: message.
	snapshot removeAll.
	self assert: session messages first identicalTo: message
]

{ #category : 'tests' }
SmallGPTalkConversationTest >> testCallAndResultLookup [
	| conversation call response result |
	conversation := SmallGPTalkConversation new.
	call := SmallGPTalkToolCall new id: 'call-1'; name: 'evaluate'; yourself.
	response := SmallGPTalkMessage assistant: ''.
	response toolCalls: { call }.
	result := SmallGPTalkMessage toolResult: (SmallGPTalkToolResult text: '42') for: call.
	conversation addMessage: response; addMessage: result.
	self assert: (conversation messageWithCallId: 'call-1') identicalTo: response.
	self assert: (conversation resultWithCallId: 'call-1') identicalTo: result.
	self assert: (conversation messageWithCallId: 'missing') isNil
]

{ #category : 'tests' }
SmallGPTalkConversationTest >> testDuplicateCallIdsLeaveHistoryUnchanged [
	| conversation response duplicate |
	conversation := SmallGPTalkConversation new.
	response := SmallGPTalkMessage assistant: 'First'.
	response toolCalls: { SmallGPTalkToolCall id: 'same' name: 'evaluate' arguments: Dictionary new }.
	conversation addMessage: response.
	duplicate := response copy text: 'Second'; yourself.
	self should: [ conversation addMessage: duplicate ] raise: Error.
	self assert: conversation messages size equals: 1.
	self assert: (conversation messageWithCallId: 'same') identicalTo: response
]
