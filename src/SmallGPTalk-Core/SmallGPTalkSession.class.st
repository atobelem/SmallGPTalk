"Coordinate requests to a model and retain their exchanges."
Class {
 #name : 'SmallGPTalkSession',
 #superclass : 'Object',
 #instVars : [ 'model', 'agent', 'exchanges', 'activeRun', 'lock', 'tools', 'maxTurns', 'requestLimit', 'context', 'observers', 'changes' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'instance creation' }
SmallGPTalkSession class >> withModel: aModel [
 ^ self new useModel: aModel; yourself
]

{ #category : 'initialization' }
SmallGPTalkSession >> initialize [
 super initialize.
 exchanges := OrderedCollection new.
 context := SmallGPTalkContext new.
 observers := SmallGPTalkObservers new.
 changes := SmallGPTalkObservers new.
 tools := #().
 maxTurns := 20.
 requestLimit := SmallGPTalkTimeLimit seconds: 120.
 lock := Semaphore forMutualExclusion
]

{ #category : 'initialization' }
SmallGPTalkSession >> useModel: aModel [
 lock critical: [
  activeRun ifNotNil: [ self error: 'Wait for the active request to finish.' ].
  model := aModel ]
]

{ #category : 'accessing' }
SmallGPTalkSession >> model [ ^ model ]

{ #category : 'initialization' }
SmallGPTalkSession >> useAgent: anAgent [
 agent := anAgent
]

{ #category : 'sending' }
SmallGPTalkSession >> send: request [
 ^ lock critical: [
  | exchange run |
  activeRun ifNotNil: [ self error: 'Wait for the active request to finish.' ].
  exchange := SmallGPTalkExchange request: ((context requestFor: request history: exchanges agent: agent) withTools: tools).
  exchange rememberCallsFrom: exchanges.
  exchange reportTo: changes.
  run := SmallGPTalkRun on: exchange.
  exchanges add: exchange.
  activeRun := run.
  run start: [
   changes notify: exchange.
   self prepareContextFor: exchange during: run.
   (self workFor: exchange during: run) value ] whenFinished: [ self release: run ].
  run ]
]

{ #category : 'private' }
SmallGPTalkSession >> release: run [
 lock critical: [ activeRun == run ifTrue: [ activeRun := nil ] ].
 changes notify: run exchange.
 observers notify: run
]

{ #category : 'accessing' }
SmallGPTalkSession >> conversation [
 ^ lock critical: [ exchanges copy ]
]

{ #category : 'accessing' }
SmallGPTalkSession >> agent [ ^ agent ]

{ #category : 'configuration' }
SmallGPTalkSession >> tools: supplied [
 lock critical: [
  activeRun ifNotNil: [ self error: 'Wait for the active request to finish.' ].
  tools := supplied asArray copy ]
]

{ #category : 'configuration' }
SmallGPTalkSession >> maxTurns: count [
 lock critical: [
  activeRun ifNotNil: [ self error: 'Wait for the active request to finish.' ].
  (count isInteger and: [ count > 0 ]) ifFalse: [ self error: 'The model request limit must be a positive integer.' ].
  maxTurns := count ]
]

{ #category : 'accessing' }
SmallGPTalkSession >> maxTurns [ ^ maxTurns ]

{ #category : 'copying' }
SmallGPTalkSession >> forkAt: point [
 ^ lock critical: [
  | index history |
  index := exchanges identityIndexOf: point.
  index = 0 ifTrue: [ self error: 'Choose an exchange from this session.' ].
  point isFinished ifFalse: [ self error: 'Choose a finished exchange.' ].
  history := OrderedCollection new.
  (exchanges first: index) do: [ :exchange |
   history add: (exchange copyWithHistory: history) ].
  (self class withModel: model)
   useAgent: agent; tools: (tools collect: #copy); maxTurns: maxTurns; requestTimeoutSeconds: requestLimit seconds;
   restore: history; useContext: context forFork; yourself ]
]

{ #category : 'private' }
SmallGPTalkSession >> restore: history [
 exchanges := history copy
]

{ #category : 'configuration' }
SmallGPTalkSession >> requestTimeoutSeconds: seconds [
 lock critical: [
  activeRun ifNotNil: [ self error: 'Wait for the active request to finish.' ].
  requestLimit := SmallGPTalkTimeLimit seconds: seconds ]
]

{ #category : 'accessing' }
SmallGPTalkSession >> requestTimeoutSeconds [ ^ requestLimit seconds ]

{ #category : 'private' }
SmallGPTalkSession >> workFor: exchange during: run [
 ^ tools inject: [ exchange answerUsing: model tools: tools limit: maxTurns requestLimit: requestLimit contextPolicy: context during: run ]
  into: [ :work :tool | [ tool during: work ] ]
]

{ #category : 'accessing' }
SmallGPTalkSession >> context [ ^ context ]

{ #category : 'compaction' }
SmallGPTalkSession >> compact [
 ^ lock critical: [
  | request exchange run count |
  activeRun ifNotNil: [ self error: 'Wait for the active request to finish.' ].
  exchanges ifEmpty: [ self error: 'There is no history to compact.' ].
  count := exchanges size.
  request := context summaryRequestFrom: exchanges.
  exchange := SmallGPTalkExchange request: request.
  run := SmallGPTalkRun on: exchange.
  run whenSucceeded: [ :reply | context absorb: reply through: count ].
  activeRun := run.
  run start: [
   changes notify: exchange.
   requestLimit value: [ model respondTo: request ] startWhen: [ :start | run whileRunningDo: start ]
  ] whenFinished: [ self release: run ].
  run ]
]

{ #category : 'private' }
SmallGPTalkSession >> prepareContextFor: exchange during: run [
 | history request reply |
 (context needsCompactionFor: exchange context model: model) ifFalse: [ ^ self ].
 history := exchanges allButLast.
 request := context summaryRequestFrom: history.
 reply := requestLimit value: [ model respondTo: request ] startWhen: [ :start | run whileRunningDo: start ].
 run whileRunningDo: [
  context absorb: reply through: history size.
  exchange useContext: ((context requestFor: exchange request history: history agent: agent) withTools: tools) ]
]

{ #category : 'initialization' }
SmallGPTalkSession >> useContext: aContext [ context := aContext ]

{ #category : 'observation' }
SmallGPTalkSession >> whenFinished: aBlock [ ^ observers add: aBlock ]

{ #category : 'observation' }
SmallGPTalkSession >> removeObserver: observer [
 observers remove: observer.
 changes remove: observer
]

{ #category : 'observation' }
SmallGPTalkSession >> observerErrors [ ^ observers errors , changes errors ]

{ #category : 'execution' }
SmallGPTalkSession >> cancel [
 | run |
 run := lock critical: [ activeRun ].
 run ifNotNil: [ run cancel ]
]

{ #category : 'observation' }
SmallGPTalkSession >> whenChanged: aBlock [ ^ changes add: aBlock ]

{ #category : 'measurement' }
SmallGPTalkSession >> estimateFor: text [
 ^ lock critical: [
  (activeRun notNil or: [ (model respondsTo: #estimateFor:) not ]) ifTrue: [ ^ nil ].
  model estimateFor: ((context requestFor: text history: exchanges agent: agent) withTools: tools) ]
]
