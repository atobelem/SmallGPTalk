| session run history results compacted check probe |
check := [ :condition :message | condition ifFalse: [ Error signal: message ] ].
probe := #SmallGPTalkCompactionProbe.
(Smalltalk globals includesKey: probe) ifTrue: [ Error signal: 'The compaction fixture already exists.' ].
Smalltalk globals at: probe put: 0.
[
 session := SmallGPTalkSession new
  provider: (SmallGPTalkOpenAIProvider account: SmallGPTalkOpenAIAccount new);
  model: 'gpt-5.6-luna'; reasoningEffort: 'medium';
  tools: SmallGPTalkImageTools all; yourself.
 session context autoCompactLimit: nil.
 results := OrderedCollection new.
 run := session send: 'Remember the marker ORCHID-739 for later. Use evaluate exactly once for this expression: Smalltalk globals at: #SmallGPTalkCompactionProbe put: ((Smalltalk globals at: #SmallGPTalkCompactionProbe) + 1). Do not run any other code. Report the result.'
  onEvent: [ :event | (event at: #type) = #toolResult ifTrue: [ results add: (event at: #result) ] ].
 run wait.
 check value: (run state = #completed) value: (run error ifNil: [ 'Initial request failed.' ] ifNotNil: [ run error messageText ]).
 check value: (results size = 1 and: [ (Smalltalk globals at: probe) = 1 ]) value: 'The fixture must execute once.' .
 Stdio stdout nextPutAll: 'Initial evaluation passed.'; lf; flush.
 history := session messages.
 run := session compactOnEvent: [ :event | ].
 run wait.
 check value: (run state = #completed) value: (run error ifNil: [ 'Manual compaction failed.' ] ifNotNil: [ run error messageText ]).
 check value: (session messages = history) value: 'Compaction changed the history.'.
 check value: (session context messages size = 1) value: 'The summary must replace the active history.'.
 Stdio stdout nextPutAll: 'Manual compaction passed.'; lf; flush.
 run := session send: 'What marker did I ask you to remember? Reply with only the marker. Do not execute tools.' onEvent: [ :event | ].
 run wait.
 check value: (run state = #completed and: [ run result text includesSubstring: 'ORCHID-739' ]) value: 'Continuation lost the marker.'.
 check value: ((Smalltalk globals at: probe) = 1) value: 'Continuation repeated the mutation.'.
 Stdio stdout nextPutAll: 'Continuation passed without a repeated mutation.'; lf; flush.
 compacted := 0.
 session context autoCompactLimit: 1.
 run := session send: 'Repeat the marker from earlier. Do not execute tools.' onEvent: [ :event |
  (event at: #type) = #compacted ifTrue: [ compacted := compacted + 1 ] ].
 run wait.
 check value: (run state = #completed and: [ run result text includesSubstring: 'ORCHID-739' ]) value: 'Automatic compaction lost the marker.'.
 check value: (compacted = 1 and: [ (Smalltalk globals at: probe) = 1 ]) value: 'Automatic compaction must preserve completed work.'.
 Stdio stdout nextPutAll: 'Automatic compaction passed with gpt-5.6-luna and medium effort.'; lf; flush
] ensure: [
 run ifNotNil: [ run cancel; wait ].
 Smalltalk globals removeKey: probe ifAbsent: [ ] ].
Smalltalk exit: 0.
