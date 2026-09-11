Class {
 #name : 'SmallGPTalkObservationTest',
 #superclass : 'TestCase',
 #instVars : [ 'modelAction' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'model protocol' }
SmallGPTalkObservationTest >> respondTo: request [ ^ modelAction value: request ]

{ #category : 'tests' }
SmallGPTalkObservationTest >> testObserversReceiveTheFinishedRunAndCanReadHistory [
 | session run seen states |
 modelAction := [ :request | 'Done.' ].
 session := SmallGPTalkSession withModel: self.
 seen := OrderedCollection new.
 states := OrderedCollection new.
 session whenFinished: [ :finished |
  seen add: finished.
  states add: finished state.
  self assert: session conversation last identicalTo: finished exchange ].
 run := session send: 'Hello'. run wait.
 self assert: seen asArray equals: { run }.
 self assert: states asArray equals: #(completed).
 self assert: session observerErrors isEmpty
]

{ #category : 'tests' }
SmallGPTalkObservationTest >> testRemovingOneObserverDoesNotStopTheRunOrAnotherObserver [
 | session run entered release first second observer |
 entered := Semaphore new.
 release := Semaphore new.
 modelAction := [ :request | entered signal. release wait. 'Done.' ].
 session := SmallGPTalkSession withModel: self.
 first := OrderedCollection new.
 second := OrderedCollection new.
 observer := session whenFinished: [ :finished | first add: finished ].
 session whenFinished: [ :finished | second add: finished ].
 run := session send: 'Hello'.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  session removeObserver: observer.
  self assert: run state equals: #running.
  release signal.
  run wait.
  self assert: first isEmpty.
  self assert: second asArray equals: { run }.
  self assert: run result equals: 'Done.'
 ] ensure: [ release signal. run cancel; wait ]
]

{ #category : 'tests' }
SmallGPTalkObservationTest >> testObserverFailureDoesNotRepeatWorkOrHideOtherObservers [
 | session run calls seen |
 calls := 0.
 modelAction := [ :request | calls := calls + 1. 'Done.' ].
 session := SmallGPTalkSession withModel: self.
 seen := OrderedCollection new.
 session whenFinished: [ :finished | self error: 'Observer failed.' ].
 session whenFinished: [ :finished | seen add: finished ].
 run := session send: 'Hello'. run wait.
 self assert: run state equals: #completed.
 self assert: calls equals: 1.
 self assert: seen asArray equals: { run }.
 self assert: session observerErrors asArray equals: #('Observer failed.')
]

{ #category : 'tests' }
SmallGPTalkObservationTest >> testFailureAndCancellationEachNotifyOnceAfterTheFinalState [
 | session run states entered |
 session := SmallGPTalkSession withModel: self.
 states := OrderedCollection new.
 session whenFinished: [ :finished | states add: finished state ].
 modelAction := [ :request | self error: 'Model failed.' ].
 run := session send: 'Fail'. run wait.
 self assert: states asArray equals: #(failed).
 entered := Semaphore new.
 modelAction := [ :request | entered signal. Semaphore new wait ].
 run := session send: 'Cancel'.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  run cancel; wait.
  self assert: states asArray equals: #(failed cancelled)
 ] ensure: [ run cancel; wait ].
 self assert: states size equals: 2
]

{ #category : 'tests' }
SmallGPTalkObservationTest >> testForkDoesNotCopyTheSourceObservers [
 | session run fork seen |
 modelAction := [ :request | 'Done.' ].
 session := SmallGPTalkSession withModel: self.
 seen := OrderedCollection new.
 session whenFinished: [ :finished | seen add: finished ].
 run := session send: 'First'. run wait.
 fork := session forkAt: run exchange.
 run := fork send: 'Next'. run wait.
 self assert: seen size equals: 1.
 self assert: run state equals: #completed
]

{ #category : 'tests - text' }
SmallGPTalkObservationTest >> testTextPreviewIsVisibleBeforeCommitAndClearedAfterCompletion [
 | session run seen entered release request |
 entered := Semaphore new.
 release := Semaphore new.
 modelAction := [ :input |
  request := input.
  input receiveText: 'Hel'; receiveText: 'lo'.
  entered signal. release wait.
  SmallGPTalkReply text: 'Hello' calls: #() ].
 session := SmallGPTalkSession withModel: self.
 seen := OrderedCollection new.
 session whenChanged: [ :exchange | seen add: exchange partialText ].
 run := session send: 'Hello'.
 [
  self deny: (entered waitTimeoutMilliseconds: 1000).
  self assert: run exchange replies isEmpty.
  self assert: run exchange partialText equals: 'Hello'.
  self assert: (seen includes: 'Hel').
  self assert: (seen includes: 'Hello').
  self assert: ((SmallGPTalkMessageText forExchange: run exchange) asString includesSubstring: 'Assistant (in progress)').
  release signal. run wait.
  self assert: run result text equals: 'Hello'.
  self assert: run exchange partialText isEmpty.
  request receiveText: 'Late text'.
  self assert: run exchange partialText isEmpty.
  self assert: session observerErrors isEmpty
 ] ensure: [ release signal. run cancel; wait ]
]

{ #category : 'tests - text' }
SmallGPTalkObservationTest >> testCancelFromATextObserverDiscardsTheIncompleteResponse [
 | session run request |
 modelAction := [ :input |
  request := input.
  input receiveText: 'Partial'.
  Semaphore new wait ].
 session := SmallGPTalkSession withModel: self.
 session whenChanged: [ :exchange | exchange partialText ifNotEmpty: [ session cancel ] ].
 run := session send: 'Cancel while streaming'.
 [
  run wait.
  self assert: run state equals: #cancelled.
  self assert: run exchange replies isEmpty.
  self assert: run exchange calls isEmpty.
  self assert: run exchange partialText isEmpty.
  request receiveText: 'Late'.
  self assert: run exchange partialText isEmpty
 ] ensure: [ run cancel; wait ]
]

{ #category : 'tests - text' }
SmallGPTalkObservationTest >> testStreamFailureClearsPreviewAndObserverErrorsDoNotStopDelivery [
 | session run seen |
 modelAction := [ :input |
  input receiveText: 'Partial'.
  self error: 'The stream failed.' ].
 session := SmallGPTalkSession withModel: self.
 seen := OrderedCollection new.
 session whenChanged: [ :exchange |
  exchange partialText ifNotEmpty: [ self error: 'Preview observer failed.' ] ].
 session whenChanged: [ :exchange | seen add: exchange partialText ].
 run := session send: 'Fail while streaming'. run wait.
 self assert: run state equals: #failed.
 self assert: run error equals: 'The stream failed.'.
 self assert: run exchange replies isEmpty.
 self assert: run exchange partialText isEmpty.
 self assert: (seen includes: 'Partial').
 self assert: session observerErrors asArray equals: #('Preview observer failed.')
]
