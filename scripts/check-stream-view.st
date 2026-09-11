"Run in a disposable native image. Keep the model blocked while checking the view."
| root entered release fixture session chat run |
root := (OSPlatform current environment at: 'SMALLGPTALK_ROOT') asFileReference.
entered := Semaphore new.
release := Semaphore new.
fixture := SmallGPTalkObservationTest new.
fixture instVarNamed: 'modelAction' put: [ :request |
 request receiveText: 'Hello from the stream'.
 entered signal. release wait.
 SmallGPTalkReply text: 'Hello from the stream' calls: #() ].
session := SmallGPTalkSession withModel: fixture.
UIManager default defer: [
 [
  chat := SmallGPTalkChat forSession: session.
  chat open.
  run := session send: 'Show text before completion'.
  [
   [
    (entered waitTimeoutMilliseconds: 2000) ifTrue: [ Error signal: 'No preview arrived.' ].
    UIManager default defer: [
     [
      (((chat instVarNamed: 'details') text asString) includesSubstring: 'Assistant (in progress)')
       ifFalse: [ Error signal: 'The native view did not show the preview.' ].
      run exchange replies ifNotEmpty: [ Error signal: 'The preview was committed too soon.' ].
      World imageForm writePNGFileNamed: (root / '.build' / 'native-stream.png') fullName.
      release signal
     ] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ] ].
    run wait.
    UIManager default defer: [
     [
      (((chat instVarNamed: 'details') text asString) includesSubstring: 'Assistant (in progress)')
       ifTrue: [ Error signal: 'The view kept the completed preview.' ].
      run state = #completed ifFalse: [ Error signal: 'The stream run did not complete.' ].
      Stdio stdout nextPutAll: 'PASS: native preview before commit and final response after completion.'; lf.
      Smalltalk exit: 0
     ] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ] ]
   ] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
  ] fork
 ] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ] ]
