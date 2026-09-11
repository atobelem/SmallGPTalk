Class {
 #name : 'SmallGPTalkTranscriptTest',
 #superclass : 'TestCase',
 #instVars : [ 'view', 'pane' ],
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'running' }
SmallGPTalkTranscriptTest >> setUp [
 super setUp.
 view := SmallGPTalkTranscript new.
 view build.
 view adapter widget extent: 400 @ 150; fullBounds.
 pane := view adapter widget scrollPane
]

{ #category : 'fixtures' }
SmallGPTalkTranscriptTest >> lines: count [
 ^ String streamContents: [ :stream |
  1 to: count do: [ :index | stream nextPutAll: 'Line ', index asString; cr ] ]
]

{ #category : 'tests' }
SmallGPTalkTranscriptTest >> testFollowsGrowthAtTheBottom [
 view show: (self lines: 50) for: #first.
 self assert: pane vLeftoverScrollRange > 0.
 self assert: (pane vLeftoverScrollRange - pane offset y) abs <= 1.
 view show: (self lines: 100) for: #first.
 self assert: (pane vLeftoverScrollRange - pane offset y) abs <= 1
]

{ #category : 'tests' }
SmallGPTalkTranscriptTest >> testPreservesReadingPositionAndResumesAtBottom [
 | position |
 view show: (self lines: 50) for: #first.
 pane vScrollbarValue: 0.3; updateScrollbars.
 position := pane offset.
 view show: (self lines: 100) for: #first.
 self assert: pane offset equals: position.
 pane scrollToEndOfText.
 view show: (self lines: 120) for: #first.
 self assert: (pane vLeftoverScrollRange - pane offset y) abs <= 1
]

{ #category : 'tests' }
SmallGPTalkTranscriptTest >> testNewSelectionStartsAtBottom [
 view show: (self lines: 50) for: #first.
 pane scrollToBeginningOfText.
 view show: (self lines: 60) for: #second.
 self assert: (pane vLeftoverScrollRange - pane offset y) abs <= 1
]

{ #category : 'tests' }
SmallGPTalkTranscriptTest >> testShortTextStartsFollowingWhenItGrows [
 view show: 'Short.' for: #first.
 view show: (self lines: 60) for: #first.
 self assert: (pane vLeftoverScrollRange - pane offset y) abs <= 1
]
