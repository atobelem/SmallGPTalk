"Execute model requests and ordered tools. Leave records in the run's exchange."
Class {
 #name : 'SmallGPTalkTurn',
 #superclass : 'Object',
 #instVars : [ 'run', 'model', 'tools', 'maxTurns', 'requestLimit', 'contextPolicy', 'base', 'covered' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'instance creation' }
SmallGPTalkTurn class >> for: execution model: provider tools: supplied limit: count requestLimit: timeLimit contextPolicy: policy [
 ^ self new configureRun: execution model: provider tools: supplied limit: count
  requestLimit: timeLimit contextPolicy: policy; yourself
]

{ #category : 'initialization' }
SmallGPTalkTurn >> configureRun: execution model: provider tools: supplied limit: count requestLimit: timeLimit contextPolicy: policy [
 run := execution.
 model := provider.
 tools := supplied asArray copy.
 maxTurns := count.
 requestLimit := timeLimit.
 contextPolicy := policy
]

{ #category : 'execution' }
SmallGPTalkTurn >> execute [
 | work |
 work := tools inject: [ self runLoop ] into: [ :inner :tool | [ tool during: inner ] ].
 ^ work value
]

{ #category : 'private' }
SmallGPTalkTurn >> exchange [ ^ run exchange ]

{ #category : 'private' }
SmallGPTalkTurn >> isRunning [ ^ run state = #running ]

{ #category : 'private' }
SmallGPTalkTurn >> runLoop [
 base := self exchange context.
 covered := 0.
 [
  maxTurns timesRepeat: [
   | request reply |
   self isRunning ifFalse: [ ^ nil ].
   request := self nextRequest.
   self isRunning ifFalse: [ ^ nil ].
   reply := self responseTo: request.
   self isRunning ifFalse: [ ^ nil ].
   reply := SmallGPTalkReply from: reply.
   self exchange recordReply: reply for: request.
   reply calls ifEmpty: [ ^ reply result ].
   self executeCalls: reply calls ].
  self error: 'The model request limit was reached.'
 ] ensure: [ self exchange cancelPendingCalls ]
]

{ #category : 'private - context' }
SmallGPTalkTurn >> nextRequest [
 | replies request |
 replies := self exchange replies.
 request := replies ifEmpty: [ base ] ifNotEmpty: [ base following: (replies allButFirst: covered) ].
 (replies notEmpty and: [ contextPolicy needsCompactionFor: request model: model ])
  ifTrue: [ ^ self compact: request ].
 ^ request
]

{ #category : 'private - context' }
SmallGPTalkTurn >> compact: request [
 | summary |
 self exchange selectRequest: request forCompaction from: model.
 summary := self request: self exchange modelContext.
 self isRunning ifFalse: [ ^ nil ].
 base := contextPolicy request: request summarizedBy: summary.
 covered := self exchange replies size - 1.
 ^ base following: { self exchange replies last }
]

{ #category : 'private - model' }
SmallGPTalkTurn >> request: request [
 ^ requestLimit value: [ model respondTo: request ]
  startWhen: [ :start | run whileRunningDo: start ]
]

{ #category : 'private - model' }
SmallGPTalkTurn >> responseTo: request [
 self exchange selectRequest: request from: model; beginPreview.
 request whenText: [ :fragment |
  | accepted |
  accepted := false.
  run whileRunningDo: [ self exchange appendPreview: fragment. accepted := true ].
  accepted ifTrue: [ self exchange reportChange ] ].
 ^ [ self request: request ]
  ensure: [ request whenText: nil. self exchange clearPreview ]
]

{ #category : 'private - tools' }
SmallGPTalkTurn >> executeCalls: calls [
 calls do: [ :call |
  self isRunning ifFalse: [ ^ self ].
  call executeWith: tools startWhen: [ :start | run whileRunningDo: start ] onStart: [
   self exchange reportChange.
   self isRunning ifFalse: [ ^ self ] ].
  self exchange reportChange ]
]
