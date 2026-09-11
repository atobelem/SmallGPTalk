"Keep a request and its outcome after execution stops."
Class {
 #name : 'SmallGPTalkExchange',
 #superclass : 'Object',
 #instVars : [ 'context', 'response', 'error', 'state', 'replies', 'previousCallIds', 'changes', 'modelContext', 'partialText', 'usedModel' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'instance creation' }
SmallGPTalkExchange class >> request: aRequest [
 ^ self new prepare: aRequest; yourself
]

{ #category : 'initialization' }
SmallGPTalkExchange >> prepare: aRequest [
 context := aRequest.
 replies := OrderedCollection new.
 self rememberCallsFrom: context history.
 state := #pending
]

{ #category : 'execution' }
SmallGPTalkExchange >> begin [
 state = #pending ifFalse: [ self error: 'This exchange has already started.' ].
 state := #running
]

{ #category : 'execution' }
SmallGPTalkExchange >> completeWith: anObject [
 self requireRunning.
 response := anObject.
 state := #completed
]

{ #category : 'execution' }
SmallGPTalkExchange >> failWith: description [
 self requireRunning.
 error := description copy.
 state := #failed
]

{ #category : 'private' }
SmallGPTalkExchange >> requireRunning [
 state = #running ifFalse: [ self error: 'This exchange is not running.' ]
]

{ #category : 'accessing' }
SmallGPTalkExchange >> request [ ^ context text ]

{ #category : 'accessing' }
SmallGPTalkExchange >> response [ ^ response ]

{ #category : 'accessing' }
SmallGPTalkExchange >> error [ ^ error ]

{ #category : 'accessing' }
SmallGPTalkExchange >> state [ ^ state ]

{ #category : 'accessing' }
SmallGPTalkExchange >> context [ ^ context ]

{ #category : 'execution' }
SmallGPTalkExchange >> requestCancellation [
 state = #running ifTrue: [ state := #cancelling ]
]

{ #category : 'execution' }
SmallGPTalkExchange >> finishCancellation [
 state = #cancelling ifFalse: [ self error: 'Cancellation was not requested.' ].
 state := #cancelled
]

{ #category : 'accessing' }
SmallGPTalkExchange >> replies [ ^ replies copy ]

{ #category : 'accessing' }
SmallGPTalkExchange >> calls [
 ^ (context following: replies) calls
]

{ #category : 'private' }
SmallGPTalkExchange >> usedCallIds [
 | identifiers |
 identifiers := previousCallIds copy.
 self calls do: [ :call | identifiers add: call id ].
 ^ identifiers
]

{ #category : 'testing' }
SmallGPTalkExchange >> isFinished [
 ^ #(completed failed cancelled) includes: state
]

{ #category : 'copying' }
SmallGPTalkExchange >> copyWithHistory: earlierExchanges [
 self isFinished ifFalse: [ self error: 'Copy only finished exchanges.' ].
 ^ self copy restoreHistory: earlierExchanges; yourself
]

{ #category : 'private' }
SmallGPTalkExchange >> restoreHistory: earlierExchanges [
 | responseIndex originalReplies originalModelContext |
 changes := nil.
 responseIndex := replies findFirst: [ :reply | reply result == response ].
 context := context withHistory: (earlierExchanges last: context history size).
 self rememberCallsFrom: earlierExchanges.
 originalReplies := replies.
 originalModelContext := modelContext.
 replies := replies collect: #copy.
 modelContext := self copyContext: modelContext history: earlierExchanges originalReplies: originalReplies.
 replies withIndexDo: [ :reply :index |
  reply context: (self copyContext: reply context history: earlierExchanges originalReplies: originalReplies).
  (originalReplies at: index) context == originalModelContext ifTrue: [ modelContext := reply context ] ].
 responseIndex > 0 ifTrue: [ response := (replies at: responseIndex) result ].
 error := error copy
]

{ #category : 'private' }
SmallGPTalkExchange >> copyContext: request history: history originalReplies: originalReplies [
 request ifNil: [ ^ nil ].
 ^ (request withHistory: (history last: request history size))
  following: (request replies collect: [ :reply | replies at: (originalReplies identityIndexOf: reply) ])
]

{ #category : 'accessing' }
SmallGPTalkExchange >> contextForCall: call [
 ^ (replies detect: [ :reply |
  reply calls anySatisfy: [ :each | each == call ] ]
  ifNone: [ self error: 'Choose a call from this exchange.' ]) context
]

{ #category : 'initialization' }
SmallGPTalkExchange >> rememberCallsFrom: history [
 previousCallIds := Set new.
 history do: [ :exchange | exchange calls do: [ :call | previousCallIds add: call id ] ]
]

{ #category : 'measurement' }
SmallGPTalkExchange >> characterCount [
 ^ context text size + (context following: replies) replyCharacterCount
]

{ #category : 'execution' }
SmallGPTalkExchange >> useContext: request [
 self requireRunning.
 replies ifNotEmpty: [ self error: 'The model request has already started.' ].
 context := request
]

{ #category : 'observation' }
SmallGPTalkExchange >> reportTo: observers [ changes := observers ]

{ #category : 'private' }
SmallGPTalkExchange >> reportChange [ changes ifNotNil: [ changes notify: self ] ]

{ #category : 'accessing' }
SmallGPTalkExchange >> modelContext [ ^ modelContext ifNil: [ context ] ]

{ #category : 'accessing' }
SmallGPTalkExchange >> partialText [ ^ partialText ifNil: [ '' ] ifNotNil: [ partialText contents ] ]

{ #category : 'measurement' }
SmallGPTalkExchange >> modelUsage [
 ^ (replies reversed detect: [ :reply |
  reply context == self modelContext ]
  ifNone: [ ^ nil ]) usage
]

{ #category : 'measurement' }
SmallGPTalkExchange >> modelUsageFor: model [
 ^ usedModel == model ifTrue: [ self modelUsage ] ifFalse: [ nil ]
]

{ #category : 'recording' }
SmallGPTalkExchange >> recordReply: reply for: request [
 self requireRunning.
 reply validateWithUsedIds: self usedCallIds.
 reply context: request.
 replies add: reply.
 self reportChange
]

{ #category : 'recording' }
SmallGPTalkExchange >> selectRequest: request from: model [
 self requireRunning.
 modelContext := request.
 usedModel := model
]

{ #category : 'recording' }
SmallGPTalkExchange >> cancelPendingCalls [ self calls do: #cancelIfPending ]

{ #category : 'recording - preview' }
SmallGPTalkExchange >> beginPreview [ partialText := String new writeStream ]

{ #category : 'recording - preview' }
SmallGPTalkExchange >> appendPreview: fragment [ partialText nextPutAll: fragment ]

{ #category : 'recording - preview' }
SmallGPTalkExchange >> clearPreview [ partialText := nil ]
