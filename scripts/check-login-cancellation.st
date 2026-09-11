"Run only in a disposable loaded image. Use test credentials and local callbacks."
| progress watchdog |
progress := 0.
watchdog := [
 (Delay forSeconds: 20) wait.
 Stdio stdout nextPutAll: 'TIMEOUT after iteration '; print: progress; lf.
 Process allInstances do: [ :process |
  process suspendedContext ifNotNil: [ :context |
   | stack |
   stack := context stack.
   (stack anySatisfy: [ :frame | frame method methodClass name beginsWith: 'SmallGPTalk' ]) ifTrue: [
    Stdio stdout nextPutAll: 'PROCESS priority '; print: process priority; lf.
    (stack first: (stack size min: 20)) do: [ :frame | Stdio stdout nextPutAll: frame printString; lf ] ] ] ].
 Smalltalk exit: 1
] forkAt: Processor userInterruptPriority.
[
 1 to: 300 do: [ :index |
  | test |
  progress := index.
  test := SmallGPTalkLoginTest new.
  test setUp.
  [ test testCancellationStopsTokenWorkWithoutCommitting ] ensure: [ test tearDown ].
  ].
 watchdog terminate.
 Stdio stdout nextPutAll: 'PASS: 300 login cancellation cycles.'; lf.
 Smalltalk exit: 0
] on: Error do: [ :error | Stdio stdout nextPutAll: error description; lf. Smalltalk exit: 1 ].
