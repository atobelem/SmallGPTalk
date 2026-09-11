"An evaluation keeps its source and the actual value or failure."
Class {
 #name : 'SmallGPTalkEvaluation',
 #superclass : 'Object',
 #instVars : [ 'source', 'result', 'error', 'state', 'output', 'outputLimit', 'truncated', 'timeLimit' ],
 #category : 'SmallGPTalk-Pharo'
}

{ #category : 'instance creation' }
SmallGPTalkEvaluation class >> source: text [
 ^ self new prepare: text; yourself
]

{ #category : 'initialization' }
SmallGPTalkEvaluation >> prepare: text [
 source := text copy.
 state := #pending.
 output := ''.
 outputLimit := 20000.
 timeLimit := SmallGPTalkTimeLimit seconds: 10.
 truncated := false
]

{ #category : 'execution' }
SmallGPTalkEvaluation >> execute [
 state = #pending ifFalse: [ self error: 'An evaluation can execute only once.' ].
 state := #running.
 [
  [
   timeLimit value: [
   result := OpalCompiler new
    source: source;
    permitUndeclared: false;
    failBlock: [ :notice | self error: notice messageText ];
    evaluate.
   self captureOutput ].
   state := #completed
  ] on: Error , Halt do: [ :failure |
   error := failure messageText copy.
   self storeOutput: error.
   state := #failed ]
 ] ensure: [ state = #running ifTrue: [ state := #cancelled ] ].
 ^ self
]

{ #category : 'accessing' }
SmallGPTalkEvaluation >> source [ ^ source copy ]

{ #category : 'accessing' }
SmallGPTalkEvaluation >> result [ ^ result ]

{ #category : 'accessing' }
SmallGPTalkEvaluation >> error [ ^ error ]

{ #category : 'accessing' }
SmallGPTalkEvaluation >> state [ ^ state ]

{ #category : 'copying' }
SmallGPTalkEvaluation >> postCopy [
 super postCopy.
 source := source copy.
 output := output copy.
 error := error copy
]

{ #category : 'configuration' }
SmallGPTalkEvaluation >> outputLimit: count [
 state = #pending ifFalse: [ self error: 'Set the output limit before execution.' ].
 (count isInteger and: [ count > 0 ]) ifFalse: [ self error: 'The output limit must be a positive integer.' ].
 outputLimit := count
]

{ #category : 'private' }
SmallGPTalkEvaluation >> captureOutput [
 | text |
 text := [ String streamContents: [ :stream |
  stream nextPutAll: result class name; nextPutAll: ': '.
  result printOn: stream ] limitedTo: outputLimit + 1 ]
  on: Error , Halt do: [ :failure | 'Cannot print result: ', failure messageText ].
 self storeOutput: text
]

{ #category : 'private' }
SmallGPTalkEvaluation >> storeOutput: text [
 truncated := text size > outputLimit.
 output := truncated
  ifTrue: [ (text first: outputLimit - 1), '…' ]
  ifFalse: [ text copy ]
]

{ #category : 'accessing' }
SmallGPTalkEvaluation >> output [ ^ output copy ]

{ #category : 'accessing' }
SmallGPTalkEvaluation >> truncated [ ^ truncated ]

{ #category : 'configuration' }
SmallGPTalkEvaluation >> timeoutSeconds: seconds [
 state = #pending ifFalse: [ self error: 'Set the time limit before execution.' ].
 timeLimit := SmallGPTalkTimeLimit seconds: seconds
]
