"Render a small Markdown subset. Keep source text unchanged."
Class {
	#name : 'SmallGPTalkChatText',
	#superclass : 'Object',
	#category : 'SmallGPTalk-Chat',
	#package : 'SmallGPTalk-Chat'
}

{ #category : 'rendering' }
SmallGPTalkChatText >> render: source [
	| input output fenceSize line trimmed count delimiter |
	input := source readStream.
	output := Text new.
	fenceSize := 0.
	[ input atEnd ] whileFalse: [
		line := input nextLine.
		trimmed := line trimBoth.
		count := self leadingBackticksIn: trimmed.
		delimiter := false.
		fenceSize = 0
			ifTrue: [
				(count >= 3 and: [ ((trimmed allButFirst: count) includes: $`) not ]) ifTrue: [
					fenceSize := count. delimiter := true ] ]
			ifFalse: [
				(count >= fenceSize and: [ count = trimmed size ]) ifTrue: [
					fenceSize := 0. delimiter := true ] ].
		delimiter ifFalse: [
			output append: (fenceSize > 0
				ifTrue: [ self code: '    ', line ]
				ifFalse: [ self inline: line ]).
			input atEnd ifFalse: [ output append: String cr ] ] ].
	^ output
]

{ #category : 'private' }
SmallGPTalkChatText >> leadingBackticksIn: source [
	| count |
	count := 0.
	[ count < source size and: [ (source at: count + 1) = $` ] ]
		whileTrue: [ count := count + 1 ].
	^ count
]

{ #category : 'rendering' }
SmallGPTalkChatText >> code: source [
	^ source asText
		addAttribute: (TextFontReference toFont: (LogicalFont
			familyName: 'Menlo'
			fallbackFamilyNames: #('DejaVu Sans Mono' 'Source Code Pro')
			pointSize: StandardFonts defaultFont pointSize));
		addAttribute: (TextBackgroundColor color: Smalltalk ui theme backgroundColor darker);
		yourself
]

{ #category : 'rendering' }
SmallGPTalkChatText >> inline: source [
	| output index marker stop part |
	output := Text new.
	index := 1.
	[ index <= source size ] whileTrue: [
		marker := (source at: index) = $`
			ifTrue: [ source copyFrom: index to: index + (self leadingBackticksIn: (source allButFirst: index - 1)) - 1 ]
			ifFalse: [ ((source copyFrom: index to: (index + 1 min: source size)) = '**')
				ifTrue: [ '**' ] ifFalse: [ nil ] ].
		stop := marker ifNil: [ 0 ] ifNotNil: [
			marker first = $`
				ifTrue: [ self closingBackticks: marker in: source startingAt: index + marker size ]
				ifFalse: [ source findString: marker startingAt: index + marker size ] ].
		stop = 0
			ifTrue: [
				part := marker ifNil: [ (source at: index) asString ].
				output append: part. index := index + part size ]
			ifFalse: [
				part := source copyFrom: index + marker size to: stop - 1.
				output append: (marker first = $`
					ifTrue: [ self code: part ]
					ifFalse: [ part asText addAttribute: TextEmphasis bold; yourself ]).
				index := stop + marker size ] ].
	^ output
]

{ #category : 'private' }
SmallGPTalkChatText >> closingBackticks: marker in: source startingAt: start [
	| index count |
	index := start.
	[ index <= source size ] whileTrue: [
		index := source findString: marker startingAt: index.
		index = 0 ifTrue: [ ^ 0 ].
		count := self leadingBackticksIn: (source allButFirst: index - 1).
		count = marker size ifTrue: [ ^ index ].
		index := index + count ].
	^ 0
]
