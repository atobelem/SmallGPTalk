"Complete login first. The run uses no image tools."

session := SmallGPTalkSession new
	provider: (SmallGPTalkOpenAIProvider account: SmallGPTalkOpenAIAccount new);
	model: 'gpt-5.6-luna';
	yourself.
run := session
	send: 'Explain message dispatch in Smalltalk in detail.'
	onEvent: [ :event | ].
run cancel.
run wait.
run state.

"Cancellation does not undo changes from tools that already completed."
