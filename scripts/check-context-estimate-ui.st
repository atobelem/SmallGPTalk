| root |
root := (OSPlatform current environment at: 'SMALLGPTALK_ROOT') asFileReference.
UIManager default defer: [
 [
  [ | fixture model session run |
   fixture := SmallGPTalkContextEstimateTest new.
   fixture setUp.
   model := SmallGPTalkOpenAIModel model: 'fixture' effort: 'low' account: fixture transport: fixture.
   model contextWindow: 10000.
   session := SmallGPTalkSession withModel: model.
   run := session send: 'First'. run wait.
   run state = #completed ifFalse: [ Error signal: run error ].
   UIManager default defer: [
    [ | view |
     view := SmallGPTalkChat forSession: session.
     view open; messageText: (String new: 1000 withAll: $x).
     (view estimateText includesSubstring: 'estimate') ifFalse: [ Error signal: 'The estimate label is missing.' ].
     (view contextText includesSubstring: '2000') ifFalse: [ Error signal: 'The measured value changed.' ].
     [ (Delay forMilliseconds: 300) wait.
      UIManager default defer: [
       World imageForm writePNGFileNamed: (root / '.build' / 'context-estimate-ui.png') fullName.
       Stdio stdout nextPutAll: 'PASS: native draft estimate and measured context are separate.'; lf.
       Smalltalk snapshot: false andQuit: true ] ] fork
    ] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ] ]
  ] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
 ] fork ]
