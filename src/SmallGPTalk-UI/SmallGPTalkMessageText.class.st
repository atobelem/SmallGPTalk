"Render local message text. Do not load resources or execute markup."
Class {
 #name : 'SmallGPTalkMessageText',
 #superclass : 'MicrodownVisitor',
 #instVars : [ 'canvas' ],
 #category : 'SmallGPTalk-UI'
}

{ #category : 'rendering' }
SmallGPTalkMessageText class >> from: source [ ^ self new from: source ]

{ #category : 'rendering' }
SmallGPTalkMessageText class >> message: source role: role [
 source trimBoth ifEmpty: [ ^ '' asText ].
 ^ (role asText addAttribute: TextEmphasis bold; yourself), String cr asText,
  (self from: source), (String cr, String cr) asText
]

{ #category : 'rendering' }
SmallGPTalkMessageText class >> forExchange: exchange [
 | text |
 text := self message: exchange request role: 'You'.
 exchange replies do: [ :reply |
  text := text, (self message: reply text role: 'Assistant').
  reply calls do: [ :call | text := text, (self forCall: call) ] ].
 exchange partialText ifNotEmpty: [ :draft |
  text := text, (self message: draft role: 'Assistant (in progress)') ].
 exchange error ifNotNil: [ :error | text := text, error asText ].
 ^ text
]

{ #category : 'rendering' }
SmallGPTalkMessageText >> from: source [
 canvas := MicRichTextCanvas new textStyler: MicTextStyler new; yourself.
 ^ [ self visit: (Microdown parse: source). canvas contents trim ]
  on: Error , Halt do: [ :error | source asText ]
]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitText: node [ canvas << node bodyString asText ]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitParagraph: node [
 super visitParagraph: node.
 canvas newLine; newLine
]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitBold: node [
 canvas includeAttribute: TextEmphasis bold in: [ super visitBold: node ]
]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitItalic: node [
 canvas includeAttribute: TextEmphasis italic in: [ super visitItalic: node ]
]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitHeader: node [
 canvas includeAttribute: TextEmphasis bold in: [ super visitHeader: node ].
 canvas newLine; newLine
]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitCode: node [
 canvas newLineIfNotAlready.
 canvas << (node body asText addAttribute: (TextFontReference toFont: StandardFonts codeFont); yourself).
 canvas newLine; newLine
]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitMonospace: node [
 canvas includeAttribute: (TextFontReference toFont: StandardFonts codeFont)
  in: [ super visitMonospace: node ]
]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitScript: node [ self visitCode: node ]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitPharoEvaluator: node [ self visitCode: node ]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitFigure: node [ self visitAll: node children ]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitInputFile: node [ canvas << '[External document]' asText ]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitMath: node [ canvas << node body asText ]

{ #category : 'visiting' }
SmallGPTalkMessageText >> visitMathInline: node [ canvas << node bodyString asText ]


{ #category : 'rendering' }
SmallGPTalkMessageText class >> forCall: call [
 | text arguments source output |
 text := ('Assistant — ', call name, ' #', call id, ' — ', call state asString) asText
  addAttribute: TextEmphasis bold; yourself.
 arguments := call arguments.
 source := arguments isDictionary ifTrue: [ arguments at: 'source' ifAbsent: [ nil ] ] ifFalse: [ nil ].
 source isString ifFalse: [
  source := [ STONJSON toString: arguments ] on: Error do: [ :error | 'Cannot display arguments.' ] ].
 text := text, String cr asText, (self literal: source role: 'Source').
 output := call operation ifNil: [ call error ] ifNotNil: [ :operation | operation output ].
 output ifNotNil: [
  output ifNotEmpty: [ text := text, (self literal: output role: 'Output') ] ].
 (call operation notNil and: [ (call operation respondsTo: #truncated) and: [ call operation truncated ] ])
  ifTrue: [ text := text, 'Output truncated. Inspect the evaluation for more detail.' asText, String cr asText ].
 ^ text, String cr asText
]

{ #category : 'rendering' }
SmallGPTalkMessageText class >> literal: source role: role [
 ^ (role asText addAttribute: TextEmphasis bold; yourself), String cr asText,
  (source asText addAttribute: (TextFontReference toFont: StandardFonts codeFont); yourself),
  (String cr, String cr) asText
]
