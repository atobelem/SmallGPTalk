| account provider model fixtureClass testClass testSource session run calls successfulCalls secondRun packageName |
model := Smalltalk os environment at: 'SMALLGPTALK_MODEL' ifAbsent: [
	Error signal: 'Set SMALLGPTALK_MODEL to an account model identifier.' ].
packageName := 'SmallGPTalk-LiveAcceptance'.
(Smalltalk packageOrganizer hasPackage: packageName) ifTrue: [
	Error signal: 'Use a clean image for the live acceptance check.' ].
account := SmallGPTalkOpenAIAccount new.
account isAuthenticated ifFalse: [ Error signal: 'Complete account login first.' ].
provider := SmallGPTalkOpenAIProvider account: account.
(provider models includes: model) ifFalse: [ Error signal: 'The selected model is not in the account catalog.' ].
[
	fixtureClass := Smalltalk classInstaller make: [ :builder |
		builder name: #SmallGPTalkAcceptanceCalculator; superclass: Object; package: packageName ].
	fixtureClass compile: 'add: firstNumber to: secondNumber ^ firstNumber - secondNumber' classified: 'arithmetic'.
	testClass := Smalltalk classInstaller make: [ :builder |
		builder name: #SmallGPTalkAcceptanceCalculatorTest; superclass: TestCase; package: packageName ].
	testClass compile: 'testAddition
		self assert: (SmallGPTalkAcceptanceCalculator new add: 6 to: 7) equals: 13' classified: 'tests'.
	testClass class addInstVarNamed: 'runCount'.
	testClass class compile: 'recordRun runCount := self runCount + 1' classified: 'tests'.
	testClass class compile: 'runCount ^ runCount ifNil: [ 0 ]' classified: 'tests'.
	testClass compile: 'testAddition
		self class recordRun.
		self assert: (SmallGPTalkAcceptanceCalculator new add: 6 to: 7) equals: 13' classified: 'tests'.
	testSource := (testClass >> #testAddition) sourceCode.
	calls := OrderedCollection new.
	successfulCalls := OrderedCollection new.
	session := SmallGPTalkSession new
		provider: provider;
		model: model;
		tools: SmallGPTalkImageTools all;
		instructions: 'You are a Smalltalk agent in Pharo 13. Use the supplied tools. Read code before changes. Use simplified English.';
		yourself.
	run := session send: 'Use evaluate with Smalltalk reflection to inspect SmallGPTalkAcceptanceCalculator and SmallGPTalkAcceptanceCalculatorTest in package SmallGPTalk-LiveAcceptance. Use evaluate to compile a repair of add:to:. Do not change any tests. Use evaluate to run SmallGPTalkAcceptanceCalculatorTest suite run and return its result. Work only on this fixture. Report the result.' onEvent: [ :event |
		(event at: #type) = #toolStarted ifTrue: [
			calls add: (event at: #call) name.
			Stdio stdout nextPutAll: 'Tool: '; nextPutAll: (event at: #call) name; lf; flush ].
		((event at: #type) = #toolResult and: [ (event at: #result) isError not ]) ifTrue: [
			successfulCalls add: (event at: #call) name ].
		(event at: #type) = #text ifTrue: [
			Stdio stdout nextPutAll: (event at: #text); flush ] ].
	run wait.
	Stdio stdout lf; nextPutAll: 'Repair run: '; nextPutAll: run state asString; lf; flush.
	run state = #completed ifFalse: [ Error signal: run error messageText ].
	(successfulCalls includes: 'evaluate') ifFalse: [ Error signal: 'Evaluate did not complete successfully.' ].
	(calls allSatisfy: [ :name | name = 'evaluate' ]) ifFalse: [ Error signal: 'An unexpected tool was used.' ].
	testClass runCount > 0 ifFalse: [ Error signal: 'The agent did not run the fixture test.' ].
	((fixtureClass new add: 4 to: 8) = 12 and: [
		(fixtureClass new add: -2 to: 3) = 1 and: [
			(fixtureClass new add: 0 to: 7) = 7 ] ]) ifFalse: [ Error signal: 'The independent addition checks failed.' ].
	(testClass >> #testAddition) sourceCode = testSource ifFalse: [ Error signal: 'The fixture test source changed.' ].
	testClass suite run hasPassed ifFalse: [ Error signal: 'The fixture tests failed.' ].
	secondRun := session send: 'What did you change? Answer in one short sentence. Do not use tools.' onEvent: [ :event | ].
	secondRun wait.
	secondRun state = #completed ifFalse: [ Error signal: secondRun error messageText ].
	secondRun result text isEmpty ifTrue: [ Error signal: 'The second reply is empty.' ].
	Stdio stdout nextPutAll: 'Second reply: '; nextPutAll: secondRun result text; lf; flush.
	account refreshCredentials.
	((SmallGPTalkOpenAIProvider account: SmallGPTalkOpenAIAccount new) models includes: model) ifFalse: [
		Error signal: 'The renewed credentials did not restore model access.' ].
	Stdio stdout nextPutAll: 'Token renewal passed.'; lf; flush.
	account logout.
	account isAuthenticated ifTrue: [ Error signal: 'Sign-out did not remove the credential record.' ].
	Stdio stdout nextPutAll: 'LIVE ACCEPTANCE PASSED. The SmallGPTalk account is signed out.'; lf; flush
] ensure: [
	(Smalltalk packageOrganizer hasPackage: packageName) ifTrue: [
		Smalltalk packageOrganizer removePackage: packageName ] ].
Smalltalk exit: 0.
