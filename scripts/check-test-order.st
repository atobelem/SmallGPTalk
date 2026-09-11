"Run only in a disposable loaded image. Do not load or use account credentials."
| iteration lastProgress watchdog tests |
iteration := 0.
lastProgress := Time microsecondClockValue.
tests := (Smalltalk globals allClasses select: [ :each |
 each package name = 'SmallGPTalk-Tests' and: [ each inheritsFrom: TestCase ] ])
 flatCollect: [ :each | each suite tests ].
watchdog := [
 [
  (Delay forSeconds: 1) wait.
  Time microsecondClockValue - lastProgress > 10000000 ifTrue: [
   Stdio stdout nextPutAll: 'STALLED in iteration '; print: iteration; lf.
   Process allInstances do: [ :process |
    process suspendedContext ifNotNil: [ :context |
     | stack |
     stack := context stack.
     (stack anySatisfy: [ :frame | frame method methodClass name beginsWith: 'SmallGPTalk' ]) ifTrue: [
      Stdio stdout nextPutAll: 'Process priority: '; print: process priority; lf.
      (stack first: (stack size min: 30)) do: [ :frame |
       Stdio stdout nextPutAll: frame printString; lf.
       (frame receiver isKindOf: SmallGPTalkRun) ifTrue: [
        Stdio stdout nextPutAll: 'Run state: '; print: frame receiver state; lf ] ] ] ] ].
   Smalltalk exit: 1 ]
 ] repeat
] forkAt: Processor userInterruptPriority.
[
 1 to: 30 do: [ :index |
  | suite result |
  iteration := index.
  suite := TestSuite named: 'Order check'.
  (tests shuffledBy: (Random seed: 515275062 + index)) do: [ :test | suite addTest: test copy ].
  result := suite run.
  (result failures isEmpty and: [ result errors isEmpty ]) ifFalse: [
   Stdio stdout nextPutAll: 'FAILED iteration '; print: index; lf.
   result failures do: [ :test | Stdio stdout nextPutAll: test printString; lf ].
   result errors do: [ :test | Stdio stdout nextPutAll: test printString; lf ].
   Smalltalk exit: 1 ].
  lastProgress := Time microsecondClockValue.
  Stdio stdout nextPutAll: 'PASS iteration '; print: index; nextPutAll: ', tests: '; print: tests size; lf ].
 watchdog terminate.
 Smalltalk exit: 0
] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
