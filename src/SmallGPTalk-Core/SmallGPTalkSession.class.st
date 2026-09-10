Class {
	#name : #SmallGPTalkSession,
	#superclass : #Object,
	#instVars : [ 'provider', 'model', 'messages', 'instructions', 'tools', 'maxTurns', 'requestTimeoutSeconds', 'toolOutputLimit', 'activeRun', 'lock' ],
	#category : #'SmallGPTalk-Core'
}

{ #category : #'initialization' }
SmallGPTalkSession >> initialize [
	super initialize.
	messages := OrderedCollection new.
	instructions := self class defaultInstructions.
	tools := #().
	maxTurns := 20.
	requestTimeoutSeconds := 120.
	toolOutputLimit := 20000.
	lock := Semaphore forMutualExclusion
]

{ #category : #'running' }
SmallGPTalkSession >> send: aString onEvent: aBlock [
	| run |
	run := SmallGPTalkRun new session: self; input: aString; observer: aBlock; yourself.
	lock critical: [
		activeRun ifNotNil: [ self error: 'This session has an active run.' ].
		self validateConfiguration.
		run reserveImage.
		activeRun := run ].
	[ run start ] on: Error do: [ :exception |
		self releaseRun: run.
		run releaseImage.
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
	messages add: aMessage
]

{ #category : #'accessing' }
SmallGPTalkSession >> messages [
	^ messages copy
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

{ #category : #'defaults' }
SmallGPTalkSession class >> defaultInstructions [
	^ 'You are SmallGPTalk, a Smalltalk assistant in Pharo.
Help the user understand, write, and test Smalltalk code.
Keep answers short and clear. Use the user''s language.
Use only the tools supplied for this session.
When image tools are available, they act on the same Pharo image that runs you.
Inspect relevant code before you change it. Test changes when possible.
Image tools have full image access. Changes remain after cancellation.
Report what you changed, what you tested, and what you could not verify.'
]
