Class {
 #name : 'SmallGPTalkChatTest',
 #superclass : 'TestCase',
 #instVars : [ 'modelAction' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'model protocol' }
SmallGPTalkChatTest >> respondTo: request [ ^ modelAction value: request ]

{ #category : 'tests' }
SmallGPTalkChatTest >> testTwoViewsKeepTheSameSessionAndRealExchanges [
 | session first second run |
 modelAction := [ :request | 'Done.' ].
 session := SmallGPTalkSession withModel: self.
 first := SmallGPTalkChat forSession: session.
 second := SmallGPTalkChat forSession: session.
 [
  run := session send: 'Hello'. run wait.
  first refresh. second refresh.
  self assert: first session identicalTo: session.
  self assert: second session identicalTo: session.
  self assert: first selectedExchange identicalTo: run exchange.
  self assert: second selectedExchange identicalTo: run exchange.
  self assert: first contextText equals: 'Context: 0% of character limit'
 ] ensure: [ first disconnect. second disconnect ]
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testDisconnectDoesNotStopTheSession [
 | session chat run entered release |
 entered := Semaphore new.
 release := Semaphore new.
 modelAction := [ :request | entered signal. release wait. 'Done.' ].
 session := SmallGPTalkSession withModel: self.
 chat := SmallGPTalkChat forSession: session.
 run := session send: 'Hello'.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  chat disconnect.
  self assert: run state equals: #running.
  release signal.
  run wait.
  self assert: run result equals: 'Done.'.
  self assert: session conversation size equals: 1
 ] ensure: [ release signal. chat disconnect. run cancel; wait ]
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testAnotherViewCanCancelTheSharedRun [
 | session first second run entered |
 entered := Semaphore new.
 modelAction := [ :request | entered signal. Semaphore new wait ].
 session := SmallGPTalkSession withModel: self.
 first := SmallGPTalkChat forSession: session.
 second := SmallGPTalkChat forSession: session.
 run := session send: 'Wait'.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  second cancelRun.
  run wait.
  self assert: run state equals: #cancelled.
  self assert: session conversation first identicalTo: run exchange.
  second cancelRun
 ] ensure: [ run cancel; wait. first disconnect. second disconnect ]
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testRefreshKeepsAnEarlierSelectionAndFollowsTheLatestOtherwise [
 | session chat run first |
 modelAction := [ :request | 'Done.' ].
 session := SmallGPTalkSession withModel: self.
 chat := SmallGPTalkChat forSession: session.
 [
  run := session send: 'First'. run wait. chat refresh.
  first := run exchange.
  run := session send: 'Second'. run wait. chat refresh.
  self assert: chat selectedExchange identicalTo: run exchange.
  chat selectExchange: first.
  run := session send: 'Third'. run wait. chat refresh.
  self assert: chat selectedExchange identicalTo: first.
  chat selectExchange: run exchange.
  run := session send: 'Fourth'. run wait. chat refresh.
  self assert: chat selectedExchange identicalTo: run exchange
 ] ensure: [ chat disconnect ]
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testUsageMatchesTheSelectedModelContext [
 | session chat run first |
 modelAction := [ :request | String new: 500 withAll: $x ].
 session := SmallGPTalkSession withModel: self.
 session context autoCompactLimit: 1000.
 chat := SmallGPTalkChat forSession: session.
 [
  run := session send: '1234567890'. run wait. chat refresh.
  first := run exchange.
  self assert: chat contextText equals: 'Context: 1% of character limit'.
  run := session send: 'next'. run wait. chat refresh.
  self assert: chat contextText equals: 'Context: 51% of character limit'.
  chat selectExchange: first.
  self assert: chat contextText equals: 'Context: 1% of character limit'
 ] ensure: [ chat disconnect ]
]

{ #category : 'tests - commands' }
SmallGPTalkChatTest >> testCompactCommandKeepsHistoryAndDoesNotSendAUserMessage [
 | session chat run original done completed request |
 modelAction := [ :input | 'First answer.' ].
 session := SmallGPTalkSession withModel: self.
 run := session send: 'Remember this'. run wait.
 original := run exchange.
 chat := SmallGPTalkChat forSession: session.
 done := Semaphore new.
 session whenFinished: [ :result | completed := result. done signal ].
 modelAction := [ :input | request := input. 'The first answer is retained.' ].
 [
  (chat presenterAt: #input) text: ' /compact '.
  chat sendMessage.
  self deny: (done waitTimeoutMilliseconds: 2000).
  self assert: completed state equals: #completed.
  self assert: request isCompaction.
  self assert: session conversation size equals: 1.
  self assert: session conversation first identicalTo: original.
  self assert: session context summary equals: 'The first answer is retained.'.
  self assert: (chat presenterAt: #input) text isEmpty
 ] ensure: [ session cancel. chat disconnect ]
]

{ #category : 'tests - commands' }
SmallGPTalkChatTest >> testCompactCommandWithoutHistoryKeepsTheInputAndShowsTheError [
 | session chat |
 modelAction := [ :input | 'This must not be sent.' ].
 session := SmallGPTalkSession withModel: self.
 chat := SmallGPTalkChat forSession: session.
 [
  (chat presenterAt: #input) text: '/compact'.
  chat sendMessage.
  self assert: session conversation isEmpty.
  self assert: (chat presenterAt: #input) text equals: '/compact'.
  self assert: chat statusText equals: 'There is no history to compact.'
 ] ensure: [ session cancel. chat disconnect ]
]

{ #category : 'tests - commands' }
SmallGPTalkChatTest >> testFailedCompactionNotificationShowsItsErrorWithoutChangingSelection [
 | session chat run original |
 modelAction := [ :request | 'First answer.' ].
 session := SmallGPTalkSession withModel: self.
 run := session send: 'Remember this'. run wait.
 original := run exchange.
 chat := SmallGPTalkChat forSession: session.
 [
  modelAction := [ :request | self error: 'Summary request failed.' ].
  run := session compact. run wait.
  chat refreshFor: run exchange.
  self assert: chat statusText equals: 'Compaction failed: Summary request failed.'.
  self assert: chat selectedExchange identicalTo: original.
  self assert: session conversation size equals: 1
 ] ensure: [ chat disconnect ]
]

{ #category : 'tests - connection' }
SmallGPTalkChatTest >> testOldNotificationCannotChangeAReconnectedView [
 | first second chat run oldObserver oldOutcome latest |
 modelAction := [ :request | 'Done.' ].
 first := SmallGPTalkSession withModel: self.
 run := first send: 'First session'. run wait.
 chat := SmallGPTalkChat forSession: first.
 [
  "Keep the old subscription to deliver a stale queued notification."
  oldObserver := chat instVarNamed: 'observer'.
  run := first compact. run wait.
  oldOutcome := run exchange.
  chat refreshFor: oldOutcome.
  second := SmallGPTalkSession withModel: self.
  run := second send: 'Second session'. run wait.
  latest := run exchange.
  chat connectTo: second.
  chat refreshFor: oldOutcome from: oldObserver.
  self assert: chat session identicalTo: second.
  self assert: chat selectedExchange identicalTo: latest.
  self assert: chat statusText isEmpty
 ] ensure: [ chat disconnect ]
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testUsageShowsTokensForTheSelectedRequest [
 | session chat run reply usage |
 usage := SmallGPTalkContextUsage inputTokens: 68000 capacity: 272000.
 reply := SmallGPTalkReply text: 'Done.' calls: #().
 reply usage: usage.
 modelAction := [ :request | reply ].
 session := SmallGPTalkSession withModel: self.
 chat := SmallGPTalkChat forSession: session.
 [
  run := session send: 'Hello'. run wait.
  chat refresh.
  self assert: chat contextText equals: 'Context: 25% (68000 / 272000 input tokens)'.
  self assert: run exchange modelUsage identicalTo: usage.
  self assert: (session forkAt: run exchange) conversation last modelUsage identicalTo: usage
 ] ensure: [ chat disconnect ]
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testRefreshPreservesTranscriptReadingPosition [
 | session chat transcript pane position |
 modelAction := [ :request | String streamContents: [ :stream |
  1 to: 100 do: [ :index | stream nextPutAll: 'Line ', index asString; cr ] ] ].
 session := SmallGPTalkSession withModel: self.
 (session send: 'Hello') wait.
 chat := SmallGPTalkChat forSession: session.
 [
  chat build.
  transcript := chat presenterAt: #details.
  transcript adapter widget extent: 400 @ 150; fullBounds.
  pane := transcript adapter widget scrollPane.
  pane vScrollbarValue: 0.3; updateScrollbars.
  position := pane offset.
  self assert: position y > 0.
  chat refresh.
  self assert: pane offset equals: position
 ] ensure: [ chat disconnect ]
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testSystemPromptUsesTheCurrentSessionAgent [
 | agent session chat |
 agent := SmallGPTalkAgent named: 'Ada'.
 agent instructions: 'First instructions.'.
 session := agent newSessionWith: self.
 chat := SmallGPTalkChat forSession: session.
 [
  self assert: chat systemPrompt equals: agent instructions.
  agent instructions: 'Changed instructions.'.
  self assert: chat systemPrompt equals: 'Changed instructions.'.
  chat connectTo: (SmallGPTalkSession withModel: self).
  self assert: chat systemPrompt equals: ''
 ] ensure: [ chat disconnect ]
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testPromptDraftChangesTheAgentOnlyWhenSaved [
 | agent session editor run |
 modelAction := [ :request | request instructions ].
 agent := SmallGPTalkAgent named: 'Ada'.
 agent instructions: 'Original instructions.'.
 session := agent newSessionWith: self.
 run := session send: 'First'. run wait.
 editor := SmallGPTalkPromptEditor forSession: session.
 self assert: editor text equals: agent instructions.
 editor text: 'New instructions.'.
 self assert: agent instructions equals: 'Original instructions.'.
 editor save.
 self assert: agent instructions equals: 'New instructions.'.
 self assert: run exchange context instructions equals: 'Original instructions.'.
 run := session send: 'Second'. run wait.
 self assert: run result equals: 'New instructions.'.
 editor text: ''. editor save.
 self assert: agent instructions equals: ''
]

{ #category : 'tests' }
SmallGPTalkChatTest >> testSavingAPromptCreatesAnAgentOnlyWhenNeeded [
 | session editor |
 session := SmallGPTalkSession withModel: self.
 editor := SmallGPTalkPromptEditor forSession: session.
 editor text: 'Use the image.'.
 self assert: session agent isNil.
 editor save.
 self assert: session agent instructions equals: 'Use the image.'
]
