"Check the real default SUnit verification without an account or model request."
[
 | job evaluation report result |
 job := SmallGPTalkImprovement new.
 evaluation := (SmallGPTalkEvaluation source: job defaultVerificationSource)
  timeoutSeconds: 60; execute.
 evaluation state = #completed ifFalse: [ Error signal: evaluation error ].
 report := evaluation result.
 result := report at: 'result'.
 (result failures isEmpty and: [ result errors isEmpty ])
  ifFalse: [ Error signal: evaluation output ].
 Stdio stdout nextPutAll: 'PASS: independent verification ran SUnit. '; nextPutAll: result printString; lf.
 Smalltalk exit: 0
] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
