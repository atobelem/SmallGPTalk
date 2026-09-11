"Keep the reader's position when the conversation changes. Uses the Morphic text pane."
Class {
 #name : 'SmallGPTalkTranscript',
 #superclass : 'SpTextPresenter',
 #instVars : [ 'exchange' ],
 #category : 'SmallGPTalk-UI'
}

{ #category : 'updating' }
SmallGPTalkTranscript >> show: text for: anExchange [
 | changed pane position follow |
 changed := exchange ~~ anExchange.
 exchange := anExchange.
 adapter ifNil: [ self text: text. ^ self ].
 pane := adapter widget scrollPane.
 position := pane offset.
 follow := changed or: [ pane vLeftoverScrollRange - position y <= 1 ].
 self text: text.
 follow
  ifTrue: [ pane scrollToEndOfText ]
  ifFalse: [ pane scrollBy: pane offset - position ]
]
