| root session run |
root := (OSPlatform current environment at: 'SMALLGPTALK_ROOT') asFileReference.
session := SmallGPTalkSession withModel: SmallGPTalkEvaluationsTest new.
session tools: { SmallGPTalkEvaluate new }.
run := session send: 'Compute'.
[
 run wait.
 UIManager default defer: [
  [
   | view |
   run state = #completed ifFalse: [ Error signal: run error ].
   view := SmallGPTalkEvaluations forExchange: run exchange.
   view open.
   view sourceText = '6 factorial' ifFalse: [ Error signal: 'The source is missing.' ].
   (view outputText includesSubstring: '720') ifFalse: [ Error signal: 'The output is missing.' ].
   view selectedCall result = 720 ifFalse: [ Error signal: 'The result is not retained.' ].
   view selectedContext == run exchange context ifFalse: [ Error signal: 'The call context is incorrect.' ].
   [
    (Delay forMilliseconds: 800) wait.
    UIManager default defer: [
     [
      World imageForm writePNGFileNamed: (root / '.build' / 'native-evaluations.png') fullName.
      Stdio stdout nextPutAll: 'PASS: native evaluation source, output, value, and context.'; lf.
      Smalltalk exit: 0
     ] on: Error do: [ :error | Stdio stdout nextPutAll: error description; lf. Smalltalk exit: 1 ] ]
   ] fork
  ] on: Error do: [ :error | Stdio stdout nextPutAll: error description; lf. Smalltalk exit: 1 ] ]
] fork.
