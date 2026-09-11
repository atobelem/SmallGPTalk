"Build a question draft from a class or compiled method."
Class {
	#name : 'SmallGPTalkCodeContext',
	#superclass : 'Object',
	#category : 'SmallGPTalk-Chat',
	#package : 'SmallGPTalk-Chat'
}

{ #category : 'accessing' }
SmallGPTalkCodeContext class >> textFor: codeObject [
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Question: '; cr; cr; nextPutAll: 'Code context:'; cr.
		(codeObject isKindOf: CompiledMethod)
			ifTrue: [
				stream nextPutAll: codeObject methodClass name; nextPutAll: ' >> '; nextPutAll: codeObject selector; cr;
					nextPutAll: codeObject sourceCode ]
			ifFalse: [
				stream nextPutAll: codeObject definitionString; cr;
					nextPutAll: codeObject instanceSide comment asString ] ]
]
