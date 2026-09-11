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
 ^ (role asText addAttribute: TextEmphasis bold; yourself), String cr asText,
  (self from: source), (String cr, String cr) asText
]

{ #category : 'rendering' }
SmallGPTalkMessageText class >> forExchange: exchange [
 | text |
 text := self message: exchange request role: 'You'.
 exchange replies do: [ :reply |
  (reply isKindOf: SmallGPTalkReply)
   ifTrue: [ text := text, (self message: reply text role: 'Assistant') ]
   ifFalse: [ reply isString ifTrue: [ text := text, (self message: reply role: 'Assistant') ] ] ].
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
