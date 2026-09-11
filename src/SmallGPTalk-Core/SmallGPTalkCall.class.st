"Resolve a tool request to a local operation and retain its outcome."
Class {
 #name : 'SmallGPTalkCall',
 #superclass : 'Object',
 #instVars : [ 'id', 'name', 'arguments', 'operation', 'state', 'error' ],
 #category : 'SmallGPTalk-Core'
}

{ #category : 'instance creation' }
SmallGPTalkCall class >> id: identifier name: toolName arguments: inputs [
 ^ self new prepareId: identifier name: toolName arguments: inputs; yourself
]

{ #category : 'initialization' }
SmallGPTalkCall >> prepareId: identifier name: toolName arguments: inputs [
 id := identifier copy.
 name := toolName copy.
 arguments := inputs deepCopy.
 state := #pending
]

{ #category : 'execution' }
SmallGPTalkCall >> executeWith: tools [
 ^ self executeWith: tools startWhen: [ :start | start value ] onStart: [ ]
]

{ #category : 'execution' }
SmallGPTalkCall >> executeWith: tools startWhen: permission onStart: notification [
 | started |
 state = #pending ifFalse: [ self error: 'A tool call can execute only once.' ].
 started := false.
 [
  permission value: [ state := #running. started := true ].
  started ifFalse: [ self cancelIfPending. ^ self ].
  [
   notification value.
   operation := (tools detect: [ :tool | tool name = name ]
    ifNone: [ self error: 'The requested tool is not available.' ]) prepare: arguments.
   operation execute.
   state := operation state
  ] on: Error , Halt do: [ :failure |
   error := failure messageText copy. state := #failed ]
 ] ensure: [ state = #running ifTrue: [ state := #cancelled ] ]
]

{ #category : 'execution' }
SmallGPTalkCall >> cancelIfPending [
 state = #pending ifTrue: [ state := #cancelled ]
]

{ #category : 'accessing' }
SmallGPTalkCall >> id [ ^ id copy ]

{ #category : 'accessing' }
SmallGPTalkCall >> name [ ^ name copy ]

{ #category : 'accessing' }
SmallGPTalkCall >> arguments [ ^ arguments deepCopy ]

{ #category : 'accessing' }
SmallGPTalkCall >> operation [ ^ operation ]

{ #category : 'accessing' }
SmallGPTalkCall >> state [ ^ state ]

{ #category : 'accessing' }
SmallGPTalkCall >> result [ ^ operation ifNotNil: [ operation result ] ]

{ #category : 'accessing' }
SmallGPTalkCall >> error [
 ^ error ifNil: [ operation ifNotNil: [ operation error ] ]
]

{ #category : 'validation' }
SmallGPTalkCall >> validate [
 (id isString and: [ id isNotEmpty ]) ifFalse: [ self error: 'A tool call needs an identifier.' ].
 (name isString and: [ name isNotEmpty ]) ifFalse: [ self error: 'A tool call needs a tool name.' ].
 state = #pending ifFalse: [ self error: 'A requested call must not have started.' ]
]

{ #category : 'copying' }
SmallGPTalkCall >> postCopy [
 super postCopy.
 id := id copy.
 name := name copy.
 arguments := arguments deepCopy.
 operation := operation copy.
 error := error copy
]

{ #category : 'measurement' }
SmallGPTalkCall >> characterCount [
 | input output |
 input := [ STONJSON toString: arguments ] on: Error do: [ :failure | 'Invalid arguments' ].
 output := operation ifNil: [ self error ifNil: [ '' ] ] ifNotNil: [ operation output ].
 ^ id size + name size + input size + output size
]
