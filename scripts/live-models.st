| account provider |
account := SmallGPTalkOpenAIAccount new.
account isAuthenticated ifFalse: [ Error signal: 'Complete account login first.' ].
Stdio stdout nextPutAll: 'Stored account login is available in this process.'; lf; flush.
provider := SmallGPTalkOpenAIProvider account: account.
Smalltalk os environment at: 'SMALLGPTALK_CATALOG_CLIENT_VERSION' ifPresent: [ :version |
	provider clientVersion: version ].
provider models do: [ :model |
	Stdio stdout nextPutAll: model; lf; flush ].
Smalltalk exit: 0.
