Class {
 #name : 'SmallGPTalkImprovementControlsTest',
 #superclass : 'TestCase',
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'model protocol' }
SmallGPTalkImprovementControlsTest >> respondTo: request [ ^ Semaphore new wait ]

{ #category : 'tests' }
SmallGPTalkImprovementControlsTest >> testControlsStartAndStopWithoutWaitingForTheModel [
 | job view |
 job := SmallGPTalkImprovement forSession: (SmallGPTalkSession withModel: self).
 view := SmallGPTalkImprovementControls new.
 [
  view connectTo: job; startImprovement.
  self assert: job state equals: #running.
  self assert: (view statusText includesSubstring: 'running').
  view disconnect.
  self assert: job state equals: #running.
  view connectTo: job; stopImprovement.
  job wait.
  view refresh.
  self assert: (view statusText includesSubstring: 'cancelled')
 ] ensure: [ view disconnect. job stop; wait ]
]
