"Repeat local transport tests. This check does not use OpenAI or Keychain."
| suite result total |
suite := SmallGPTalkProviderNetworkTest suite.
total := 0.
20 timesRepeat: [
	result := suite run.
	result hasPassed ifFalse: [ Error signal: result printString ].
	total := total + result runCount ].
Stdio stdout nextPutAll: 'Local transport checks passed: '; print: total; lf; flush.
Smalltalk exit: 0.
