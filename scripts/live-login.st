| account login |
account := SmallGPTalkOpenAIAccount new.
login := account beginLogin.
Stdio stdout
	nextPutAll: 'Open this login URL in your browser:'; lf;
	nextPutAll: login authorizationUrl; lf;
	flush.
login wait.
Stdio stdout nextPutAll: 'Login state: '; nextPutAll: login state asString; lf; flush.
login state = #completed ifFalse: [
	login error ifNotNil: [ Stdio stderr nextPutAll: login error messageText; lf; flush ].
	Smalltalk exit: 1 ].
Stdio stdout nextPutAll: 'Account credentials are stored in macOS Keychain.'; lf; flush.
Smalltalk exit: 0.
