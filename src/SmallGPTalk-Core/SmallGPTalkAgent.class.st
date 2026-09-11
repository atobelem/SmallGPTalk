"A reusable agent definition. Each session receives its own configuration."
Class {
	#name : 'SmallGPTalkAgent',
	#superclass : 'Object',
	#instVars : [ 'name', 'instructions', 'tools' ],
	#category : 'SmallGPTalk-Core',
	#package : 'SmallGPTalk-Core'
}

{ #category : 'initialization' }
SmallGPTalkAgent >> initialize [
	super initialize.
	name := 'SmallGPTalk'.
	instructions := self class defaultInstructions.
	tools := #()
]

{ #category : 'accessing' }
SmallGPTalkAgent >> name [
	^ name copy
]

{ #category : 'accessing' }
SmallGPTalkAgent >> name: aString [
	name := aString copy
]

{ #category : 'accessing' }
SmallGPTalkAgent >> instructions [
	^ instructions copy
]

{ #category : 'accessing' }
SmallGPTalkAgent >> instructions: aString [
	instructions := aString copy
]

{ #category : 'accessing' }
SmallGPTalkAgent >> tools [
	^ tools copy
]

{ #category : 'accessing' }
SmallGPTalkAgent >> tools: aCollection [
	tools := aCollection asArray copy
]

{ #category : 'sessions' }
SmallGPTalkAgent >> newTools [
	^ tools collect: #newForSession
]

{ #category : 'sessions' }
SmallGPTalkAgent >> newSession [
	^ SmallGPTalkSession new agent: self; yourself
]

{ #category : #'defaults' }
SmallGPTalkAgent class >> defaultInstructions [
	^ 'You are SmallGPTalk, a Smalltalk assistant in Pharo.
Help the user understand, write, and test Smalltalk code.
Keep answers short and clear. Use the user''s language.
Use only the tools supplied for this session.
When image tools are available, they act on the same Pharo image that runs you.
Inspect relevant code before you change it. Test changes when possible.
Image tools have full image access. Changes remain after cancellation.
Report what you changed, what you tested, and what you could not verify.'
]

{ #category : 'sessions' }
SmallGPTalkAgent >> forSelfImprovement [
	^ self copy
		name: 'SmallGPTalk / Self-improvement';
		instructions: self instructions, String cr, self class selfImprovementInstructions;
		yourself
]

{ #category : 'defaults' }
SmallGPTalkAgent class >> selfImprovementInstructions [
	^ 'Self-improvement mode is active. The user authorizes code changes and tests without further approval.
Improve SmallGPTalk in this Pharo image. Use evaluate to inspect source, critics, and tests.
Choose one small, useful change in each cycle. Apply the change and run relevant SUnit tests.
If a test fails, diagnose and repair the change within the turn limit.
Inspect the current image before each change. Earlier changes can remain after a failed cycle.
Do not repeat a completed change. Use the previous cycle summary to guide inspection.
Keep the agent core small. Preserve Stop, execution limits, and resource locks.
Do not remove tests or suppress critics to claim success.
Do not access credentials, external services, shell commands, or files as part of self-improvement.
Tests that need another image run must be reported as unverified. Do not bypass the image lock.
Report the classes and methods changed, tests run, failures, and a useful next step.
Changes apply to this image. Do not claim that repository files were updated.'
]
