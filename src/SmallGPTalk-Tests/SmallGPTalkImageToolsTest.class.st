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

{ #category : 'tests' }
SmallGPTalkImageToolsTest >> testEvaluationRetainsLocalObjectOutsideJSON [
	| result decoded |
	result := self execute: SmallGPTalkEvaluateTool new arguments: (Dictionary new
		at: 'source' put: fixtureClass name asString; yourself).
	self assert: result value identicalTo: fixtureClass.
	self assert: result expression equals: fixtureClass name asString.
	decoded := STONJSON fromString: result text.
	self assert: decoded size equals: 3.
	self deny: (decoded includesKey: 'localValue').
	self deny: (decoded includesKey: 'localExpression')
]

{ #category : 'tests' }
SmallGPTalkImageToolsTest >> testNilIsAnInspectableEvaluationResult [
	| result |
	result := self execute: SmallGPTalkEvaluateTool new arguments: (Dictionary new at: 'source' put: 'nil'; yourself).
	self assert: (result isKindOf: SmallGPTalkEvaluationResult).
	self assert: result value isNil
]

{ #category : 'tests - evaluate' }
SmallGPTalkImageToolsTest >> testReadsAndCompilesThroughEvaluate [
	| result |
	result := self execute: SmallGPTalkEvaluateTool new arguments: (Dictionary new
		at: 'source' put: '(' , fixtureClass name , ' >> #smallGPTalkFixtureValue) sourceCode'; yourself).
	self assert: (result value includesSubstring: '^ 7').
	self execute: SmallGPTalkEvaluateTool new arguments: (Dictionary new
		at: 'source' put: fixtureClass name , ' compile: ''smallGPTalkFixtureValue ^ 23'' classified: ''accessing'''; yourself).
	self assert: (fixtureClass new perform: #smallGPTalkFixtureValue) equals: 23
]

{ #category : 'tests - evaluate' }
SmallGPTalkImageToolsTest >> testCompileErrorThroughEvaluatePreservesMethod [
	self should: [ self execute: SmallGPTalkEvaluateTool new arguments: (Dictionary new
		at: 'source' put: fixtureClass name , ' compile: ''smallGPTalkFixtureValue ^ [ ] ]'' classified: ''accessing'''; yourself) ] raise: Error.
	self assert: (fixtureClass new perform: #smallGPTalkFixtureValue) equals: 7
]

{ #category : 'tests - evaluate' }
SmallGPTalkImageToolsTest >> testRunsSUnitThroughEvaluate [
	| result |
	result := self execute: SmallGPTalkEvaluateTool new arguments: (Dictionary new
		at: 'source' put: '| result | TestExecutionEnvironment new beActiveDuring: [ result := ', fixtureTestClass name, ' suite run ]. result'; yourself).
	self assert: result value runCount equals: 3.
	self assert: result value skipped size equals: 1.
	self assert: result value failures size equals: 1.
	self assert: result value errors size equals: 1
]

{ #category : 'tests' }
SmallGPTalkImageToolsTest >> testEvaluationKeepsItsExecutionContext [
	| session result |
	session := SmallGPTalkSession new model: 'fixture-model'; reasoningEffort: 'high'; yourself.
	session addMessage: (SmallGPTalkMessage user: 'Evaluate the fixture.').
	run session: session.
	result := self execute: SmallGPTalkEvaluateTool new arguments: (Dictionary new at: 'source' put: '6 * 7'; yourself).
	self assert: result expression equals: '6 * 7'.
	self assert: result value equals: 42.
	self assert: (result context at: #model) equals: 'fixture-model'.
	self assert: (result context at: #reasoningEffort) equals: 'high'.
	self assert: (result context at: #run) identicalTo: run.
	self assert: (result context at: #messages) first identicalTo: session messages first.
	self assert: ((STONJSON fromString: result text) at: 'value') equals: '42'
]
