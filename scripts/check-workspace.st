| root output fixture session run chat |
root := (OSPlatform current environment at: 'SMALLGPTALK_ROOT') asFileReference.
output := (OSPlatform current environment at: 'SMALLGPTALK_CHECK_DIR'
 ifAbsent: [ (root / '.build' / ('native-', UUID new asString)) fullName ]) asFileReference.
output ensureCreateDirectory.
fixture := (Object << #SmallGPTalkNativeWorkspaceFixture)
 package: 'SmallGPTalk-Native-Check'; install.
fixture compile: 'answer ^ 1' classified: 'example'.
session := SmallGPTalkSession withModel: SmallGPTalkWorkspaceTest new.
session tools: { SmallGPTalkEvaluate new }.
UIManager default defer: [
 [
  chat := SmallGPTalkChat forSession: session.
  chat open.
  chat followAgent: true.
  run := session send: 'SmallGPTalkNativeWorkspaceFixture compile: ''answer ^ 42'' classified: ''example''.
pharo browse: (SmallGPTalkNativeWorkspaceFixture >> #answer).
pharo inspect: (OrderedCollection with: SmallGPTalkNativeWorkspaceFixture new answer)'.
  [
   run wait.
   (Delay forMilliseconds: 1000) wait.
   UIManager default defer: [
    [ | operation method browser inspector view |
     run state = #completed ifFalse: [ Error signal: run error ].
     fixture new answer = 42 ifFalse: [ Error signal: 'The method was not changed.' ].
     operation := run exchange calls first operation.
     operation interactions size = 2 ifFalse: [ Error signal: 'The interactions are missing.' ].
     method := fixture >> #answer.
     browser := (Smalltalk tools toolNamed: #browser) allInstances
      detect: [ :each | each window notNil and: [ each isMethodSelected: method ] ]
      ifNone: [ Error signal: 'No browser selected the changed method.' ].
     inspector := (Smalltalk tools toolNamed: #inspector) allInstances
      detect: [ :each | each window notNil and: [ each model notNil and: [ each model inspectedObject == operation result ] ] ]
      ifNone: [ Error signal: 'No inspector opened the real result.' ].
     chat interactionErrors ifNotEmpty: [ Error signal: chat interactionErrors first ].
     World imageForm writePNGFileNamed: (output / 'workspace-inspector.png') fullName.
     chat followAgent: false.
     view := SmallGPTalkEvaluations forExchange: run exchange.
     view open.
     view selectedInteraction target == method ifFalse: [ Error signal: 'The method link was not retained.' ].
     view selectedInteraction evaluation == operation ifFalse: [ Error signal: 'The evaluation link was lost.' ].
     World imageForm writePNGFileNamed: (output / 'workspace-interactions.png') fullName.
     browser window activate.
     World imageForm writePNGFileNamed: (output / 'workspace-browser.png') fullName.
     Stdio stdout nextPutAll: 'PASS: native follow, changed method, real inspector, and retained interactions.'; lf.
     Smalltalk exit: 0
    ] on: Error do: [ :error | Stdio stdout nextPutAll: error description; lf. Smalltalk exit: 1 ] ]
  ] fork
 ] on: Error do: [ :error | Stdio stdout nextPutAll: error description; lf. Smalltalk exit: 1 ] ]
