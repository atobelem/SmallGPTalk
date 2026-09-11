| root |
root := (OSPlatform current environment at: 'SMALLGPTALK_ROOT') asFileReference.
(root / '.build' / 'native-chat' / 'result.txt') ensureDelete.
UIManager default defer: [
 [
 | fixture provider session first second run compaction |
 fixture := SmallGPTalkOpenAIProviderTest new.
 fixture setUp.
 provider := fixture provider.
 session := (SmallGPTalkAgent named: 'Ada') newSessionWith: provider defaultModel.
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
   (root / '.build' / 'native-chat' / 'result.txt') writeStreamDo: [ :stream | stream nextPutAll: 'PASS: native views share the session; closing one preserves the other; compaction status is visible.' ].
   [ (Delay forMilliseconds: 800) wait.
    UIManager default defer: [
     World imageForm writePNGFileNamed: (root / '.build' / 'native-chat' / 'window.png') fullName.
     Smalltalk snapshot: false andQuit: true ] ] fork
  ] on: Error do: [ :error |
   (root / '.build' / 'native-chat' / 'result.txt') writeStreamDo: [ :stream | stream nextPutAll: error description ].
   Smalltalk exit: 1 ] ]
 ] fork
 ] on: Error do: [ :error |
  (root / '.build' / 'native-chat' / 'result.txt') writeStreamDo: [ :stream | stream nextPutAll: error description ].
  Smalltalk exit: 1 ] ]
