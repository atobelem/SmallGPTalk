Class {
 #name : 'SmallGPTalkImprovementTest',
 #superclass : 'TestCase',
 #instVars : [ 'improvement', 'modelAction' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkImprovementTest >> tearDown [
 improvement ifNotNil: [ improvement stop; wait ].
 super tearDown
]

{ #category : 'model protocol' }
SmallGPTalkImprovementTest >> respondTo: request [ ^ modelAction value: request ]

{ #category : 'private' }
SmallGPTalkImprovementTest >> prepare [
 modelAction := [ :request | 'Done.' ].
 improvement := SmallGPTalkImprovement forSession: (SmallGPTalkSession withModel: self).
 improvement intervalSeconds: 0.001; verificationSource: '6 factorial'
]

{ #category : 'private' }
SmallGPTalkImprovementTest >> await: condition [
 | deadline |
 deadline := Time millisecondClockValue + 2000.
 [ condition value not and: [ Time millisecondClockValue < deadline ] ]
  whileTrue: [ (Delay forMilliseconds: 1) wait ].
 self assert: condition value
]

{ #category : 'tests' }
SmallGPTalkImprovementTest >> testRepeatsVerifiedCyclesUntilStopped [
 self prepare.
 improvement whenChanged: [ :job |
  job cycles size = 3 ifTrue: [ job stop ] ].
 improvement start.
 self await: [ improvement state = #cancelled ].
 improvement wait.
 self assert: improvement cycles size equals: 3.
 improvement cycles do: [ :cycle |
  self assert: cycle run state equals: #completed.
  self assert: cycle verification result equals: 720 ].
 self assert: improvement session conversation size equals: 3
]

{ #category : 'tests' }
SmallGPTalkImprovementTest >> testStopCancelsActiveModelAndPreventsVerification [
 | entered finished |
 self prepare.
 entered := false. finished := false.
 modelAction := [ :request |
  [ entered := true. Semaphore new wait ] ensure: [ finished := true ] ].
 improvement start.
 self await: [ entered ].
 improvement stop; wait.
 self assert: finished.
 self assert: improvement cycles size equals: 1.
 self assert: improvement cycles first run state equals: #cancelled.
 self assert: improvement cycles first verification isNil
]

{ #category : 'tests' }
SmallGPTalkImprovementTest >> testFailureIsRetainedAndSentToNextCycle [
 | requests |
 self prepare.
 requests := OrderedCollection new.
 modelAction := [ :request |
  requests add: request.
  requests size = 1 ifTrue: [ self error: 'Fixture request failed.' ].
  'Recovered.' ].
 improvement whenChanged: [ :job | job cycles size = 2 ifTrue: [ job stop ] ].
 improvement start.
 self await: [ improvement state = #cancelled ].
 improvement wait.
 self assert: requests size equals: 2.
 self assert: (requests last text includesSubstring: 'Fixture request failed.').
 self assert: improvement cycles first verification result equals: 720
]

{ #category : 'tests' }
SmallGPTalkImprovementTest >> testStopTerminatesVerification [
 self prepare.
 improvement verificationSource: '[ true ] whileTrue'.
 improvement start.
 self await: [ improvement cycles notEmpty and: [
  improvement cycles first verification notNil and: [
   improvement cycles first verification state = #running ] ] ].
 improvement stop; wait.
 self assert: improvement cycles first verification state equals: #cancelled.
 self assert: improvement cycles size equals: 1
]

{ #category : 'tests' }
SmallGPTalkImprovementTest >> testDuplicateStartIsRejectedAndIdleStopIsSafe [
 self prepare.
 improvement stop; wait.
 self assert: improvement state equals: #idle.
 modelAction := [ :request | Semaphore new wait ].
 improvement start.
 self should: [ improvement start ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkImprovementTest >> testVerificationFailureAndObserverErrorDoNotStopCycles [
 | requests |
 self prepare.
 requests := OrderedCollection new.
 modelAction := [ :request | requests add: request. 'Done.' ].
 improvement verificationSource: 'Error signal: ''Fixture verification failed.'''.
 improvement whenChanged: [ :job | self error: 'Fixture observer failed.' ].
 improvement whenChanged: [ :job | job cycles size = 2 ifTrue: [ job stop ] ].
 improvement start.
 self await: [ improvement state = #cancelled ].
 improvement wait.
 self assert: (requests last text includesSubstring: 'Fixture verification failed.').
 self assert: improvement cycles first verification state equals: #failed.
 self assert: improvement observerErrors notEmpty
]

{ #category : 'tests' }
SmallGPTalkImprovementTest >> testStopDuringIntervalDoesNotStartAnotherCycle [
 | checked |
 self prepare.
 checked := false.
 improvement intervalSeconds: 30.
 improvement whenChanged: [ :job | checked := true ].
 improvement start.
 self await: [ checked ].
 improvement stop; wait.
 self assert: improvement cycles size equals: 1.
 self assert: improvement cycles first verification state equals: #completed
]

{ #category : 'tests' }
SmallGPTalkImprovementTest >> testRestartKeepsPreviousCyclesAndVerification [
 | target |
 self prepare.
 target := 1.
 improvement whenChanged: [ :job | job cycles size = target ifTrue: [ job stop ] ].
 improvement start.
 self await: [ improvement state = #cancelled ].
 improvement wait.
 target := 2.
 improvement start.
 self await: [ improvement state = #cancelled ].
 improvement wait.
 self assert: improvement cycles size equals: 2.
 self assert: improvement session conversation size equals: 2
]

{ #category : 'tests' }
SmallGPTalkImprovementTest >> testVerificationTimeoutIsRetained [
 self prepare.
 improvement verificationSource: '[ true ] whileTrue'; verificationTimeoutSeconds: 0.03.
 improvement whenChanged: [ :job | job stop ].
 improvement start.
 self await: [ improvement state = #cancelled ].
 improvement wait.
 self assert: improvement cycles first verification state ~= #running.
 self assert: ((improvement cycles first report) includesSubstring: 'time limit')
]

{ #category : 'tests' }
SmallGPTalkImprovementTest >> testToolRepairsFixtureAndIndependentCheckSeesTheChange [
 | fixture count call baseline |
 fixture := (TestCase << #SmallGPTalkImprovementFixture) package: 'SmallGPTalk-Fixtures'; install.
 [
  fixture compile: 'answer ^ 1' classified: 'testing'.
  fixture compile: 'testAnswer self assert: self answer equals: 2' classified: 'tests'.
  DefaultExecutionEnvironment beActiveDuring: [ baseline := fixture suite run ].
  self assert: baseline failures size equals: 1.
  self prepare.
  improvement session tools: { SmallGPTalkEvaluate new }.
  improvement verificationSource: 'SmallGPTalkImprovementFixture suite run'.
  count := 0.
  call := SmallGPTalkCall id: 'repair' name: 'evaluate' arguments:
   (Dictionary new at: 'source' put: 'SmallGPTalkImprovementFixture compile: ''answer ^ 2'' classified: ''testing'''; yourself).
  modelAction := [ :request |
   count := count + 1.
   count = 1 ifTrue: [ SmallGPTalkReply text: '' calls: { call } ] ifFalse: [ 'Repaired.' ] ].
  improvement whenChanged: [ :job | job stop ].
  improvement start.
  self await: [ improvement state = #cancelled ].
  improvement wait.
  self assert: call state equals: #completed.
  self assert: fixture new answer equals: 2.
  self assert: improvement cycles first verification result failures isEmpty.
  self assert: improvement cycles first verification result errors isEmpty
 ] ensure: [
  improvement ifNotNil: [ improvement stop; wait ].
  fixture removeFromSystem ]
]
