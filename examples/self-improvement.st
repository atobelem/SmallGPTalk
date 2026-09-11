"Load the Pharo group. Login must be available in Keychain."
| agent provider improvement |
agent := (SmallGPTalkAgent new tools: SmallGPTalkImageTools all; yourself) forSelfImprovement.
provider := SmallGPTalkOpenAIProvider account: SmallGPTalkOpenAIAccount new.
improvement := SmallGPTalkSelfImprovement new
 sessionFactory: [ agent newSession provider: provider; model: 'gpt-5.6-luna'; reasoningEffort: 'medium'; yourself ];
 yourself.
improvement startOnEvent: [ :event | ].
improvement inspect.
"In the inspector, evaluate self cancel to stop. Use self wait to wait for completion."
