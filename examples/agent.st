"Complete login first. Run this example in a development image."

account := SmallGPTalkOpenAIAccount new.
provider := SmallGPTalkOpenAIProvider account: account.
provider models.

"Select a model from the account catalog. This model passed the release check."
session := SmallGPTalkSession new
	provider: provider;
	model: 'gpt-5.6-luna';
	tools: SmallGPTalkImageTools all;
	yourself.

run := session
	send: 'Use evaluate to inspect the source of SmallGPTalkSession. Explain send:onEvent: in two short sentences.'
	onEvent: [ :event |
		(event at: #type) = #text ifTrue: [
			Transcript show: (event at: #text) ] ].

"The call above returns immediately. Inspect the run, or wait for completion."
run wait.
run state.
run result.

"Continue the same conversation."
session send: 'What does cancel do?' onEvent: [ :event | ].
