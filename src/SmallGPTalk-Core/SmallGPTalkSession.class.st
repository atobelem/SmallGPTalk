"Own model configuration, committed conversation, tools, and one active run."
Class {
	#name : #SmallGPTalkSession,
	#superclass : #Object,
	#instVars : [ 'agent', 'provider', 'model', 'reasoningEffort', 'conversation', 'context', 'instructions', 'tools', 'maxTurns', 'requestTimeoutSeconds', 'toolOutputLimit', 'activeRun', 'lock' ],
	#category : #'SmallGPTalk-Core'
}

{ #category : #'initialization' }
SmallGPTalkSession >> initialize [
	super initialize.
	conversation := SmallGPTalkConversation new.
	context := SmallGPTalkContext forSession: self.
	agent := SmallGPTalkAgent new.
	instructions := agent instructions.
	tools := agent newTools.
	reasoningEffort := 'medium'.
	maxTurns := 20.
	requestTimeoutSeconds := 120.
	toolOutputLimit := 20000.
	lock := Semaphore forMutualExclusion
]

{ #category : #'running' }
SmallGPTalkSession >> send: aString onEvent: aBlock [
	^ self startRun: (SmallGPTalkRun new input: aString; yourself) onEvent: aBlock
]

{ #category : 'running' }
SmallGPTalkSession >> compactOnEvent: aBlock [
	^ self startRun: SmallGPTalkCompactionRun new onEvent: aBlock
]

{ #category : 'private' }
SmallGPTalkSession >> startRun: run onEvent: aBlock [
	run session: self; observer: aBlock.
	lock critical: [
		activeRun ifNotNil: [ self error: 'This session has an active run.' ].
		self validateConfiguration.
		run reserveResources.
		activeRun := run ].
	[ run start ] on: Error do: [ :exception |
		self releaseRun: run.
		run releaseResources.
		exception pass ].
	^ run
]

{ #category : #'private' }
SmallGPTalkSession >> validateConfiguration [
	provider ifNil: [ self error: 'Set a model provider.' ].
	(model isString and: [ model isNotEmpty ]) ifFalse: [ self error: 'Set an explicit model identifier.' ].
	(maxTurns isInteger and: [ maxTurns > 0 ]) ifFalse: [ self error: 'The turn limit must be a positive integer.' ].
	(requestTimeoutSeconds isNumber and: [ requestTimeoutSeconds > 0 ]) ifFalse: [ self error: 'The request timeout must be positive.' ].
	(toolOutputLimit isInteger and: [ toolOutputLimit > 0 ]) ifFalse: [ self error: 'The tool output limit must be a positive integer.' ].
	(tools collect: #name) asSet size = tools size ifFalse: [ self error: 'Tool names must be unique.' ]
]

{ #category : #'private' }
SmallGPTalkSession >> releaseRun: aRun [
	lock critical: [ activeRun == aRun ifTrue: [ activeRun := nil ] ]
]

{ #category : #'private' }
SmallGPTalkSession >> addMessage: aMessage [
	conversation addMessage: aMessage
]

{ #category : #'accessing' }
SmallGPTalkSession >> messages [
	^ conversation messages
]

{ #category : #'accessing' }
SmallGPTalkSession >> activeRun [
	^ activeRun
]

{ #category : #'accessing' }
SmallGPTalkSession >> provider [
	^ provider
]

{ #category : #'accessing' }
SmallGPTalkSession >> provider: anObject [
	lock critical: [
		activeRun ifNotNil: [ self error: 'Do not change a session during a run.' ].
		provider := anObject ]
]

{ #category : #'accessing' }
SmallGPTalkSession >> model [
	^ model
]

{ #category : #'accessing' }
SmallGPTalkSession >> model: anObject [
	lock critical: [
		activeRun ifNotNil: [ self error: 'Do not change a session during a run.' ].
		model := anObject ]
]

{ #category : #'accessing' }
SmallGPTalkSession >> instructions [
	^ instructions
]

{ #category : #'accessing' }
SmallGPTalkSession >> instructions: anObject [
	lock critical: [
		activeRun ifNotNil: [ self error: 'Do not change a session during a run.' ].
		instructions := anObject ]
]

{ #category : #'accessing' }
SmallGPTalkSession >> tools [
	^ tools copy
]

{ #category : #'accessing' }
SmallGPTalkSession >> tools: anObject [
	lock critical: [
		activeRun ifNotNil: [ self error: 'Do not change a session during a run.' ].
		tools := anObject asArray copy ]
]

{ #category : #'accessing' }
SmallGPTalkSession >> maxTurns [
	^ maxTurns
]

{ #category : #'accessing' }
SmallGPTalkSession >> maxTurns: anObject [
	lock critical: [
		activeRun ifNotNil: [ self error: 'Do not change a session during a run.' ].
		maxTurns := anObject ]
]

{ #category : #'accessing' }
SmallGPTalkSession >> requestTimeoutSeconds [
	^ requestTimeoutSeconds
]

{ #category : #'accessing' }
SmallGPTalkSession >> requestTimeoutSeconds: anObject [
	lock critical: [
		activeRun ifNotNil: [ self error: 'Do not change a session during a run.' ].
		requestTimeoutSeconds := anObject ]
]

{ #category : #'accessing' }
SmallGPTalkSession >> toolOutputLimit [
	^ toolOutputLimit
]

{ #category : #'accessing' }
SmallGPTalkSession >> toolOutputLimit: anObject [
	lock critical: [
		activeRun ifNotNil: [ self error: 'Do not change a session during a run.' ].
		toolOutputLimit := anObject ]
]

{ #category : #'accessing' }
SmallGPTalkSession >> agent [
	^ agent
]

{ #category : #'accessing' }
SmallGPTalkSession >> agent: anAgent [
	| newInstructions newTools |
	lock critical: [
		(activeRun isNotNil or: [ conversation isEmpty not ]) ifTrue: [
			self error: 'Set the agent before the conversation starts.' ].
		newInstructions := anAgent instructions.
		newTools := anAgent newTools.
		agent := anAgent.
		instructions := newInstructions.
		tools := newTools ]
]

{ #category : #'accessing' }
SmallGPTalkSession >> reasoningEffort [
	^ reasoningEffort
]

{ #category : #'accessing' }
SmallGPTalkSession >> reasoningEffort: aString [
	lock critical: [
		activeRun ifNotNil: [ self error: 'Do not change a session during a run.' ].
		(aString isString and: [ aString isNotEmpty ])
			ifFalse: [ self error: 'Select a valid reasoning effort.' ].
		reasoningEffort := aString ]
]

{ #category : 'accessing' }
SmallGPTalkSession >> conversation [
	^ conversation
]

{ #category : 'accessing' }
SmallGPTalkSession >> context [ ^ context ]
