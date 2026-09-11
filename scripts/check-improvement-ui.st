| root |
root := (OSPlatform current environment at: 'SMALLGPTALK_ROOT') asFileReference.
UIManager default defer: [
 [ | session job view |
  session := SmallGPTalkSession withModel: SmallGPTalkImprovementControlsTest new.
  job := SmallGPTalkImprovement forSession: session.
  job verificationSource: '6 factorial'.
  view := SmallGPTalkChat forSession: session.
  view useImprovement: job; open.
  job start.
  [
   (Delay forMilliseconds: 300) wait.
   job stop; wait.
   UIManager default defer: [
    [
     view window isOpen ifFalse: [ Error signal: 'The chat window closed.' ].
     job state = #cancelled ifFalse: [ Error signal: 'Improvement did not stop.' ].
     World imageForm writePNGFileNamed: (root / '.build' / 'improvement-ui.png') fullName.
     Stdio stdout nextPutAll: 'PASS: native improvement controls opened and execution stopped.'; lf.
     Smalltalk snapshot: false andQuit: true
    ] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ] ]
  ] fork
 ] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ] ]
