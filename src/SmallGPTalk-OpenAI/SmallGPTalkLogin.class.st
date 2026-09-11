"Compose callback, token exchange, and supervised work for one login."
Class {
 #name : 'SmallGPTalkLogin',
 #superclass : 'Object',
 #instVars : [ 'callback', 'server', 'tokens', 'commit', 'run', 'limit', 'state', 'error' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'instance creation' }
SmallGPTalkLogin class >> callback: receiver server: listener tokens: exchange onSuccess: aBlock [
 ^ self new callback: receiver server: listener tokens: exchange onSuccess: aBlock; yourself
]

{ #category : 'initialization' }
SmallGPTalkLogin >> callback: receiver server: listener tokens: exchange onSuccess: aBlock [
 callback := receiver.
 server := listener.
 tokens := exchange.
 commit := aBlock.
 state := #pending.
 limit := SmallGPTalkTimeLimit seconds: 900
]

{ #category : 'configuration' }
SmallGPTalkLogin >> timeoutSeconds: seconds [
 state = #pending ifFalse: [ self error: 'The login has already started.' ].
 limit := SmallGPTalkTimeLimit seconds: seconds
]

{ #category : 'execution' }
SmallGPTalkLogin >> start [
 state = #pending ifFalse: [ self error: 'The login has already started.' ].
 [ server start ] on: Error do: [ :failure |
  self failWith: failure messageText.
  commit := nil.
  [ server stop ] ensure: [ callback cancel ].
  ^ self ].
 run := SmallGPTalkRun on: self.
 run whenSucceeded: commit.
 commit := nil.
 run start: [
  limit value: [
   | form |
   form := callback awaitForm.
   [ tokens exchange: form ] ensure: [ form removeAll ] ]
 ] whenFinished: [ server stop. callback cancel ].
 ^ self
]

{ #category : 'waiting' }
SmallGPTalkLogin >> wait [ run ifNotNil: [ run wait ]. ^ self ]

{ #category : 'execution' }
SmallGPTalkLogin >> cancel [ run ifNotNil: [ run cancel ]. ^ self ]

{ #category : 'accessing' }
SmallGPTalkLogin >> authorizationUrl [
 state = #failed ifTrue: [ self error: error ].
 ^ callback authorizationUrl
]

{ #category : 'accessing' }
SmallGPTalkLogin >> state [ ^ state ]

{ #category : 'accessing' }
SmallGPTalkLogin >> error [ ^ error ]

{ #category : 'outcome protocol' }
SmallGPTalkLogin >> begin [ state := #running ]

{ #category : 'outcome protocol' }
SmallGPTalkLogin >> completeWith: ignored [ state := #completed ]

{ #category : 'outcome protocol' }
SmallGPTalkLogin >> failWith: text [ error := text copy. state := #failed ]

{ #category : 'outcome protocol' }
SmallGPTalkLogin >> requestCancellation [ state = #running ifTrue: [ state := #cancelling ] ]

{ #category : 'outcome protocol' }
SmallGPTalkLogin >> finishCancellation [ state := #cancelled ]

{ #category : 'outcome protocol' }
SmallGPTalkLogin >> response [ ^ nil ]
