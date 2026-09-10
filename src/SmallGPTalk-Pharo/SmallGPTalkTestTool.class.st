Class {
	#name : 'SmallGPTalkTestTool',
	#superclass : 'SmallGPTalkImageTool',
	#category : 'SmallGPTalk-Pharo',
	#package : 'SmallGPTalk-Pharo'
}

{ #category : 'initialization' }
SmallGPTalkTestTool >> initialize [
	super initialize.
	timeoutSeconds := 60
]

{ #category : 'accessing' }
SmallGPTalkTestTool >> name [
	^ 'test'
]

{ #category : 'accessing' }
SmallGPTalkTestTool >> description [
	^ 'Run SUnit for one package or an explicit list of test class names. Supply package or classes. Return result counts and failed test identifiers. The time limit applies to the complete selection.'
]

{ #category : 'accessing' }
SmallGPTalkTestTool >> inputSchema [
	^ self schema: (Dictionary new
		at: 'package' put: self stringSchema;
		at: 'classes' put: (Dictionary new at: 'type' put: 'array'; at: 'items' put: self stringSchema; yourself);
		yourself) required: #()
]

{ #category : 'private' }
SmallGPTalkTestTool >> testClassesFor: arguments [
	| classes package |
	(arguments includesKey: 'classes') = (arguments includesKey: 'package') ifTrue: [
		self error: 'Supply either package or classes.' ].
	(arguments includesKey: 'classes')
		ifTrue: [
			(arguments at: 'classes') isEmpty ifTrue: [ self error: 'Supply at least one test class.' ].
			classes := (arguments at: 'classes') collect: [ :name | self classNamed: name ].
			classes do: [ :class |
				((class inheritsFrom: TestCase) and: [ class isAbstract not ]) ifFalse: [
					self error: 'The class is not a concrete test class: ' , class name , '.' ] ] ]
		ifFalse: [
			package := Smalltalk packageOrganizer packageNamed: (arguments at: 'package') ifAbsent: [
				self error: 'The test package does not exist.' ].
			classes := package definedClasses select: [ :class |
				(class inheritsFrom: TestCase) and: [ class isAbstract not ] ] ].
	classes isEmpty ifTrue: [ self error: 'The selection contains no test classes.' ].
	^ classes asSet asArray sorted: [ :a :b | a name <= b name ]
]

{ #category : 'private' }
SmallGPTalkTestTool >> performTool: arguments context: aRun [
	| classes suite result details |
	classes := self testClassesFor: arguments.
	suite := TestSuite new.
	classes do: [ :class |
		aRun checkCancellation.
		suite addTest: class suite ].
	TestExecutionEnvironment new beActiveDuring: [ result := suite run ].
	details := OrderedCollection new.
	self addDetails: result failures outcome: 'failure' to: details.
	self addDetails: result errors outcome: 'error' to: details.
	self addDetails: result skipped outcome: 'skipped' to: details.
	^ Dictionary new
		at: 'run' put: result runCount + result skippedCount;
		at: 'passed' put: result passedCount;
		at: 'failures' put: result failureCount;
		at: 'errors' put: result errorCount;
		at: 'skipped' put: result skippedCount;
		at: 'details' put: details asArray;
		yourself
]

{ #category : 'private' }
SmallGPTalkTestTool >> addDetails: tests outcome: outcome to: details [
	tests do: [ :test |
		details add: (Dictionary new
			at: 'class' put: test class name asString;
			at: 'selector' put: test selector asString;
			at: 'outcome' put: outcome;
			yourself) ]
]
