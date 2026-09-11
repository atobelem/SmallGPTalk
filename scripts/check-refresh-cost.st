"Measure rendering work for a burst without a live provider or UI window."
[
 | exchange fragment start immediate coalesced scheduled queue renders |
 fragment := 'Some text for the reply. '.
 exchange := SmallGPTalkExchange request: (SmallGPTalkRequest text: 'Explain' history: #() agent: nil).
 exchange begin; beginPreview.
 start := Time millisecondClockValue.
 1 to: 1000 do: [ :index |
  exchange appendPreview: fragment.
  SmallGPTalkMessageText forExchange: exchange ].
 immediate := Time millisecondClockValue - start.
 exchange clearPreview; beginPreview.
 scheduled := OrderedCollection new.
 renders := 0.
 queue := SmallGPTalkRefreshQueue schedule: [ :work | scheduled add: work ]
  deliver: [ :record | SmallGPTalkMessageText forExchange: record. renders := renders + 1 ].
 start := Time millisecondClockValue.
 1 to: 1000 do: [ :index | exchange appendPreview: fragment. queue request: exchange ].
 scheduled size = 1 ifFalse: [ Error signal: 'The burst queued more than one refresh.' ].
 scheduled removeFirst value.
 coalesced := Time millisecondClockValue - start.
 renders = 1 ifFalse: [ Error signal: 'The burst rendered more than once.' ].
 exchange partialText size = (1000 * fragment size) ifFalse: [ Error signal: 'The queue lost text.' ].
 Stdio stdout nextPutAll: 'Immediate renders: 1000. Queued renders: 1. Text characters: ';
  print: exchange partialText size; nextPutAll: '. Immediate ms: '; print: immediate;
  nextPutAll: '. Queued ms: '; print: coalesced; lf.
 Smalltalk exit: 0
] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
