| output root |
root := (OSPlatform current environment at: 'SMALLGPTALK_ROOT') asFileReference.
output := (OSPlatform current environment at: 'SMALLGPTALK_CHECK_DIR'
 ifAbsent: [ (root / '.build' / ('native-', UUID new asString)) fullName ]) asFileReference.
output ensureCreateDirectory.
Stdio stdout nextPutAll: 'Output: '; nextPutAll: output fullName; lf.
(output / 'result.txt') ensureDelete.
UIManager default defer: [
 [
 | fixture provider session first second run compaction |
 fixture := SmallGPTalkOpenAIProviderTest new.
 fixture setUp.
 provider := fixture provider.
 session := (SmallGPTalkAgent named: 'Ada') newSessionWith: provider defaultModel.
 session agent instructions: 'Use the image documentation. Inspect your own classes.'.
 first := SmallGPTalkChat forSession: session provider: provider.
 second := SmallGPTalkChat forSession: session provider: provider.
 first open.
 second open.
 second modelSelector selectModel: 'gpt-5.6-luna' effort: 'high'; applySelection.
 (session model effort = 'high') ifFalse: [ Error signal: 'The model selection was not applied.' ].
 first window close.
 run := session send: 'Check this expression: `6 factorial`.

```smalltalk
| number |
number := 6.
number factorial. "720"
```'.
 [
 run wait.
 compaction := session compact.
 compaction wait.
 UIManager default defer: [
  [
   second refresh.
   (second selectedExchange == run exchange) ifFalse: [ Error signal: 'The view lost its exchange.' ].
   second window isOpen ifFalse: [ Error signal: 'The second window closed.' ].
   (run state = #completed) ifFalse: [ Error signal: 'The run did not complete.' ].
   (compaction state = #completed) ifFalse: [ Error signal: 'Compaction did not complete.' ].
   (second statusText = 'Compaction completed.') ifFalse: [ Error signal: 'The view did not show the compaction result.' ].
   (output / 'result.txt') writeStreamDo: [ :stream | stream nextPutAll: 'PASS: native views share the session; closing one preserves the other; compaction status is visible.' ].
   [ (Delay forMilliseconds: 800) wait.
    UIManager default defer: [
     [ | promptView |
     World imageForm writePNGFileNamed: (output / 'window.png') fullName.
     promptView := second openSystemPrompt.
     promptView text asString = session agent instructions ifFalse: [ Error signal: 'The system prompt is incorrect.' ].
     promptView text: 'Changed in the prompt editor.'.
     session agent instructions = 'Changed in the prompt editor.' ifTrue: [ Error signal: 'The draft was applied before Save.' ].
     promptView save.
     session agent instructions = promptView text ifFalse: [ Error signal: 'The prompt was not saved.' ].
     World imageForm writePNGFileNamed: (output / 'system-prompt.png') fullName.
     Stdio stdout nextPutAll: 'PASS: native system prompt draft and save.'; lf.
     Smalltalk snapshot: false andQuit: true
     ] on: Error do: [ :error | Stdio stdout nextPutAll: error description; lf. Smalltalk exit: 1 ] ] ] fork
  ] on: Error do: [ :error |
   (output / 'result.txt') writeStreamDo: [ :stream | stream nextPutAll: error description ].
   Smalltalk exit: 1 ] ]
 ] fork
 ] on: Error do: [ :error |
  (output / 'result.txt') writeStreamDo: [ :stream | stream nextPutAll: error description ].
  Smalltalk exit: 1 ] ]
