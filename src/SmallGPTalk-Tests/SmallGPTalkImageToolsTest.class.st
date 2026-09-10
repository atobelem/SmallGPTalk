Class {
	#name : 'SmallGPTalkImageToolsTest',
	#superclass : 'TestCase',
	#instVars : [
		'fixtureClass',
		'fixtureTestClass',
		'run'
	],
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkImageToolsTest >> setUp [
	super setUp.
	run := SmallGPTalkRun new.
	fixtureClass := Smalltalk classInstaller make: [ :builder |
		builder
			name: #SmallGPTalkImageFixture;
			superclass: Object;
			package: self fixturePackageName ].
	fixtureClass comment: 'This class is a test fixture.'.
	fixtureClass compile: 'smallGPTalkFixtureValue ^ 7' classified: 'accessing'.
	fixtureClass class compile: 'smallGPTalkFixtureValue ^ 11' classified: 'accessing'.
	fixtureTestClass := Smalltalk classInstaller make: [ :builder |
		builder
			name: #SmallGPTalkImageFixtureTest;
			superclass: TestCase;
			package: self fixturePackageName ].
	fixtureTestClass compile: 'testPass self assert: 1 equals: 1' classified: 'tests'.
	fixtureTestClass compile: 'testFailure self assert: false' classified: 'tests'.
	fixtureTestClass compile: 'testError self error: ''Fixture error.''' classified: 'tests'.
	fixtureTestClass compile: 'testSkip self skip: ''Fixture skip.''' classified: 'tests'
]

{ #category : 'running' }
SmallGPTalkImageToolsTest >> tearDown [
	[ self packageOrganizer removePackage: self fixturePackageName ]
		ensure: [ super tearDown ]
]

{ #category : 'private' }
SmallGPTalkImageToolsTest >> fixturePackageName [
	^ 'SmallGPTalk-ImageTool-Fixtures'
]

{ #category : 'private' }
SmallGPTalkImageToolsTest >> execute: tool arguments: arguments [
	^ tool execute: arguments context: run
]

{ #category : 'private' }
SmallGPTalkImageToolsTest >> jsonFrom: result [
	self deny: result isError.
	self deny: result truncated.
	^ STONJSON fromString: result text
]

{ #category : 'private' }
SmallGPTalkImageToolsTest >> assertTestCounts: summary [
	self assert: (summary at: 'run') equals: 4.
	self assert: (summary at: 'passed') equals: 1.
	self assert: (summary at: 'failures') equals: 1.
	self assert: (summary at: 'errors') equals: 1.
	self assert: (summary at: 'skipped') equals: 1.
	#('testFailure' 'testError' 'testSkip') do: [ :selector |
		self assert: ((summary at: 'details') anySatisfy: [ :detail |
			(detail at: 'class') = fixtureTestClass name and: [
				(detail at: 'selector') = selector ] ]) ]
]

{ #category : 'tests - search' }
SmallGPTalkImageToolsTest >> testFindsPackagesClassesAndSelectors [
	{
		{ 'packages'. self fixturePackageName }.
		{ 'classes'. fixtureClass name }.
		{ 'selectors'. 'smallGPTalkFixtureValue' }
	} do: [ :selection |
		| result |
		result := self execute: SmallGPTalkSearchTool new arguments: (Dictionary new
			at: 'kind' put: selection first;
			at: 'query' put: selection second;
			yourself).
		self deny: result isError.
		self assert: (result text includesSubstring: selection second) ]
]

{ #category : 'tests - search' }
SmallGPTalkImageToolsTest >> testRejectsInvalidSearchLimits [
	#(0 501) do: [ :limit |
		self should: [
			self execute: SmallGPTalkSearchTool new arguments: (Dictionary new
				at: 'query' put: 'SmallGPTalk';
				at: 'limit' put: limit;
				yourself)
		] raise: Error ]
]

{ #category : 'tests - read' }
SmallGPTalkImageToolsTest >> testReadsClassDefinitionAndComment [
	| summary |
	summary := self jsonFrom: (self execute: SmallGPTalkReadTool new arguments: (Dictionary new
		at: 'class' put: fixtureClass name;
		yourself)).
	self assert: (summary at: 'class') equals: fixtureClass name.
	self assert: ((summary at: 'definition') includesSubstring: fixtureClass name).
	self assert: (summary at: 'comment') equals: fixtureClass comment
]

{ #category : 'tests - read' }
SmallGPTalkImageToolsTest >> testReadsInstanceAndClassMethods [
	#('instance' 'class') with: #('7' '11') do: [ :side :value |
		| summary |
		summary := self jsonFrom: (self execute: SmallGPTalkReadTool new arguments: (Dictionary new
			at: 'class' put: fixtureClass name;
			at: 'selector' put: 'smallGPTalkFixtureValue';
			at: 'side' put: side;
			yourself)).
		self assert: (summary at: 'side') equals: side.
		self assert: (summary at: 'selector') equals: 'smallGPTalkFixtureValue'.
		self assert: (summary at: 'protocol') equals: 'accessing'.
		self assert: ((summary at: 'source') includesSubstring: '^ ' , value) ]
]

{ #category : 'tests - read' }
SmallGPTalkImageToolsTest >> testRejectsMissingClassAndMethod [
	self should: [
		self execute: SmallGPTalkReadTool new arguments: (Dictionary new
			at: 'class' put: 'SmallGPTalkImageFixtureDoesNotExist';
			yourself)
	] raise: Error.
	self should: [
		self execute: SmallGPTalkReadTool new arguments: (Dictionary new
			at: 'class' put: fixtureClass name;
			at: 'selector' put: 'smallGPTalkMissingMethod';
			yourself)
	] raise: Error
]

{ #category : 'tests - compile' }
SmallGPTalkImageToolsTest >> testReplacesInstanceMethod [
	| summary |
	summary := self jsonFrom: (self execute: SmallGPTalkCompileTool new arguments: (Dictionary new
		at: 'class' put: fixtureClass name;
		at: 'source' put: 'smallGPTalkFixtureValue ^ 23';
		at: 'protocol' put: 'fixture changes';
		yourself)).
	self assert: (summary at: 'selector') equals: 'smallGPTalkFixtureValue'.
	self assert: (summary at: 'side') equals: 'instance'.
	self assert: (summary at: 'protocol') equals: 'fixture changes'.
	self assert: (fixtureClass new perform: #smallGPTalkFixtureValue) equals: 23.
	self assert: (fixtureClass perform: #smallGPTalkFixtureValue) equals: 11
]

{ #category : 'tests - compile' }
SmallGPTalkImageToolsTest >> testAddsClassMethod [
	| summary |
	summary := self jsonFrom: (self execute: SmallGPTalkCompileTool new arguments: (Dictionary new
		at: 'class' put: fixtureClass name;
		at: 'side' put: 'class';
		at: 'source' put: 'smallGPTalkAddedValue ^ 31';
		at: 'protocol' put: 'fixture changes';
		yourself)).
	self assert: (summary at: 'selector') equals: 'smallGPTalkAddedValue'.
	self assert: (summary at: 'side') equals: 'class'.
	self assert: (fixtureClass perform: #smallGPTalkAddedValue) equals: 31.
	self deny: (fixtureClass includesSelector: #smallGPTalkAddedValue)
]

{ #category : 'tests - compile' }
SmallGPTalkImageToolsTest >> testCompileFailurePreservesExistingMethod [
	self should: [
		self execute: SmallGPTalkCompileTool new arguments: (Dictionary new
			at: 'class' put: fixtureClass name;
			at: 'source' put: 'smallGPTalkFixtureValue ^ [ ] ]';
			at: 'protocol' put: 'fixture changes';
			yourself)
	] raise: Error.
	self assert: (fixtureClass new perform: #smallGPTalkFixtureValue) equals: 7
]

{ #category : 'tests - evaluate' }
SmallGPTalkImageToolsTest >> testEvaluatesExpressionInCurrentImage [
	| summary |
	summary := self jsonFrom: (self execute: SmallGPTalkEvaluateTool new arguments: (Dictionary new
		at: 'source' put: fixtureClass name , ' new smallGPTalkFixtureValue + 5';
		yourself)).
	self assert: (summary at: 'class') equals: 'SmallInteger'.
	self assert: (summary at: 'value') equals: '12'.
	self deny: (summary at: 'truncated')
]

{ #category : 'tests - evaluate' }
SmallGPTalkImageToolsTest >> testReportsEvaluationSyntaxAndRuntimeErrors [
	#('1 + ]' 'Error signal: ''Fixture error.''') do: [ :source |
		self should: [
			self execute: SmallGPTalkEvaluateTool new arguments: (Dictionary new
				at: 'source' put: source;
				yourself)
		] raise: Error ]
]

{ #category : 'tests - evaluate' }
SmallGPTalkImageToolsTest >> testStopsAnEvaluationAtItsTimeLimit [
	self should: [
		self execute: (SmallGPTalkEvaluateTool new timeoutSeconds: 0.05; yourself) arguments: (Dictionary new
			at: 'source' put: '[ true ] whileTrue';
			yourself)
	] raise: SmallGPTalkTimeout
]

{ #category : 'tests - evaluate' }
SmallGPTalkImageToolsTest >> testCancellationStopsAnActiveEvaluation [
	| started stopped finished failure process source |
	started := Semaphore new.
	stopped := Semaphore new.
	finished := Semaphore new.
	fixtureClass addClassVarNamed: 'StartSignal'.
	fixtureClass addClassVarNamed: 'StopSignal'.
	fixtureClass classPool at: #StartSignal put: started.
	fixtureClass classPool at: #StopSignal put: stopped.
	source := '[ (' , fixtureClass name , ' classPool at: #StartSignal) signal. ',
		'[ true ] whileTrue ] ensure: [ (' , fixtureClass name ,
		' classPool at: #StopSignal) signal ]'.
	process := [
		[ [ self execute: SmallGPTalkEvaluateTool new arguments: (Dictionary new
			at: 'source' put: source;
			yourself) ]
			on: Error
			do: [ :exception | failure := exception ] ]
			ensure: [ finished signal ]
	] fork.
	[
		self deny: (started waitTimeoutMilliseconds: 2000).
		run cancel.
		self deny: (finished waitTimeoutMilliseconds: 2000).
		self assert: failure class equals: SmallGPTalkCancelled.
		self deny: (stopped waitTimeoutMilliseconds: 2000)
	] ensure: [
		run cancel.
		process isTerminated ifFalse: [ process terminate ] ]
]

{ #category : 'tests - limits' }
SmallGPTalkImageToolsTest >> testBoundsToolOutput [
	| result |
	result := self execute: (SmallGPTalkEvaluateTool new outputLimit: 100; yourself) arguments: (Dictionary new
		at: 'source' put: 'String new: 1000 withAll: $a';
		yourself).
	self assert: result truncated.
	self assert: result text size <= 100
]

{ #category : 'tests - test' }
SmallGPTalkImageToolsTest >> testRunsSelectedTestClasses [
	| summary |
	summary := self jsonFrom: (self execute: SmallGPTalkTestTool new arguments: (Dictionary new
		at: 'classes' put: { fixtureTestClass name };
		yourself)).
	self assertTestCounts: summary
]

{ #category : 'tests - test' }
SmallGPTalkImageToolsTest >> testRunsTestsInSelectedPackage [
	| summary |
	summary := self jsonFrom: (self execute: SmallGPTalkTestTool new arguments: (Dictionary new
		at: 'package' put: self fixturePackageName;
		yourself)).
	self assertTestCounts: summary
]

{ #category : 'tests - test' }
SmallGPTalkImageToolsTest >> testRejectsEmptyAndAmbiguousTestSelections [
	{
		Dictionary new.
		(Dictionary new at: 'classes' put: #(); yourself).
		(Dictionary new at: 'package' put: ''; yourself).
		(Dictionary new
			at: 'package' put: self fixturePackageName;
			at: 'classes' put: { fixtureTestClass name };
			yourself)
	} do: [ :arguments |
		self should: [ self execute: SmallGPTalkTestTool new arguments: arguments ] raise: Error ]
]

{ #category : 'tests - test' }
SmallGPTalkImageToolsTest >> testRejectsAClassThatIsNotATestCase [
	self should: [
		self execute: SmallGPTalkTestTool new arguments: (Dictionary new
			at: 'classes' put: { fixtureClass name };
			yourself)
	] raise: Error
]
