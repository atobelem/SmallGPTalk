Class {
	#name : 'SmallGPTalkCoreToolValidationTest',
	#superclass : 'TestCase',
	#instVars : [
		'tool'
	],
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkCoreToolValidationTest >> setUp [
	super setUp.
	tool := SmallGPTalkCoreValidationTool new.
	tool schema: (Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new
			at: 'name' put: (Dictionary new at: 'type' put: 'string'; yourself);
			yourself);
		at: 'required' put: #('name');
		at: 'additionalProperties' put: false;
		yourself)
]

{ #category : 'private' }
SmallGPTalkCoreToolValidationTest >> useValueSchema: schema [
	tool schema: (Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new at: 'value' put: schema; yourself);
		at: 'required' put: #('value');
		yourself)
]

{ #category : 'tests' }
SmallGPTalkCoreToolValidationTest >> testAcceptsValidArguments [
	| arguments |
	arguments := Dictionary new at: 'name' put: 'Example'; yourself.
	self assert: (tool validateArguments: arguments) identicalTo: arguments
]

{ #category : 'tests' }
SmallGPTalkCoreToolValidationTest >> testAcceptsAndRejectsScalarTypes [
	#('integer' 'number' 'boolean' 'null')
		with: { 3. 1.5. true. nil }
		do: [ :type :value |
			self useValueSchema: (Dictionary new at: 'type' put: type; yourself).
			self assertValidArguments: (Dictionary new at: 'value' put: value; yourself).
			self should: [ tool validateArguments: (Dictionary new at: 'value' put: 'invalid'; yourself) ] raise: Error ]
]

{ #category : 'tests' }
SmallGPTalkCoreToolValidationTest >> testAcceptsNullableType [
	self useValueSchema: (Dictionary new at: 'type' put: #('string' 'null'); yourself).
	self assertValidArguments: (Dictionary new at: 'value' put: nil; yourself).
	self assertValidArguments: (Dictionary new at: 'value' put: 'text'; yourself).
	self should: [ tool validateArguments: (Dictionary new at: 'value' put: 5; yourself) ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkCoreToolValidationTest >> testRejectsEnumValue [
	self useValueSchema: (Dictionary new
		at: 'type' put: 'string';
		at: 'enum' put: #('instance' 'class');
		yourself).
	self assertValidArguments: (Dictionary new at: 'value' put: 'class'; yourself).
	self should: [ tool validateArguments: (Dictionary new at: 'value' put: 'package'; yourself) ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkCoreToolValidationTest >> testRejectsMissingRequiredArgument [
	self should: [ tool validateArguments: Dictionary new ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkCoreToolValidationTest >> testRejectsNonObjectArguments [
	self should: [ tool validateArguments: #('name' 'Example') ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkCoreToolValidationTest >> testRejectsUnknownArgument [
	self should: [ tool validateArguments: (Dictionary new
		at: 'name' put: 'Example';
		at: 'extra' put: 3;
		yourself) ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkCoreToolValidationTest >> testRejectsWrongArgumentType [
	self should: [ tool validateArguments: (Dictionary new at: 'name' put: 3; yourself) ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkCoreToolValidationTest >> testValidatesAdditionalPropertySchema [
	tool schema: (Dictionary new
		at: 'type' put: 'object';
		at: 'additionalProperties' put: (Dictionary new at: 'type' put: 'integer'; yourself);
		yourself).
	self assertValidArguments: (Dictionary new at: 'count' put: 3; yourself).
	self should: [ tool validateArguments: (Dictionary new at: 'count' put: 'three'; yourself) ] raise: Error
]

{ #category : 'tests' }
SmallGPTalkCoreToolValidationTest >> testValidatesNestedArrayItems [
	| itemSchema |
	itemSchema := Dictionary new
		at: 'type' put: 'object';
		at: 'properties' put: (Dictionary new
			at: 'count' put: (Dictionary new at: 'type' put: 'integer'; yourself);
			yourself);
		at: 'required' put: #('count');
		yourself.
	self useValueSchema: (Dictionary new
		at: 'type' put: 'array';
		at: 'items' put: itemSchema;
		yourself).
	self assertValidArguments: (Dictionary new
		at: 'value' put: { Dictionary new at: 'count' put: 3; yourself };
		yourself).
	self should: [ tool validateArguments: (Dictionary new
		at: 'value' put: { Dictionary new at: 'count' put: 'three'; yourself };
		yourself) ] raise: Error.
	self should: [ tool validateArguments: (Dictionary new at: 'value' put: 'text'; yourself) ] raise: Error
]

{ #category : 'private' }
SmallGPTalkCoreToolValidationTest >> assertValidArguments: arguments [
	self assert: (tool validateArguments: arguments) identicalTo: arguments
]
