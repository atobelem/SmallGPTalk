"A detachable view of a session. The session owns all execution and history."
Class {
 #name : 'SmallGPTalkChat',
 #superclass : 'SpPresenter',
 #instVars : [ 'session', 'observer', 'exchanges', 'details', 'input', 'send', 'inspect', 'inspectContext', 'inspectCalls', 'compact', 'fork', 'usage', 'status', 'cancel', 'provider', 'modelSelector', 'improvementControls', 'nextUsage', 'refreshingHistory' ],
 #category : 'SmallGPTalk-UI'
}

{ #category : 'instance creation' }
SmallGPTalkChat class >> forSession: session [
 ^ self new connectTo: session; yourself
]

{ #category : 'instance creation' }
SmallGPTalkChat class >> forSession: session provider: provider [
 ^ (self forSession: session) useProvider: provider; yourself
]

{ #category : 'configuration' }
SmallGPTalkChat >> useProvider: aProvider [
 provider := aProvider.
 modelSelector := self instantiate: SmallGPTalkModelSelector.
 modelSelector models: provider models; onChoose: [ :identifier :effort |
  self performAction: [
   session useModel: (provider model: identifier effort: effort).
   self showNextEstimate ] ].
 self selectCurrentModel
]

{ #category : 'private' }
SmallGPTalkChat >> selectCurrentModel [
 modelSelector ifNil: [ ^ self ].
 ((session model respondsTo: #identifier) and: [ session model respondsTo: #effort ]) ifTrue: [
  modelSelector selectModel: session model identifier effort: session model effort ]
 ifFalse: [ modelSelector selectModel: nil effort: nil ]
]

{ #category : 'accessing' }
SmallGPTalkChat >> modelSelector [ ^ modelSelector ]

{ #category : 'initialization' }
SmallGPTalkChat >> initializePresenters [
 exchanges := self newList.
 exchanges display: [ :exchange | (exchange request contractTo: 60), ' — ', exchange state asString ].
 exchanges whenSelectionChangedDo: [ refreshingHistory == true ifFalse: [ self showSelection ] ].
 details := (self instantiate: SmallGPTalkTranscript) beNotEditable.
 input := self newText.
 cancel := self newButton label: 'Cancel'; action: [ self cancelRun ]; yourself.
 send := self newButton label: 'Send'; action: [ self sendMessage ]; yourself.
 inspect := self newButton label: 'Inspect exchange'; action: [ self selectedExchange ifNotNil: #inspect ]; yourself.
 inspectContext := self newButton label: 'Inspect context'; action: [ self selectedExchange ifNotNil: [ :exchange | exchange modelContext inspect ] ]; yourself.
 inspectCalls := self newButton label: 'Inspect evaluations'; action: [ self selectedExchange ifNotNil: [ :exchange | (SmallGPTalkEvaluations forExchange: exchange) open ] ]; yourself.
 compact := self newButton label: 'Compact'; action: [ self performAction: [ session compact. self refresh ] ]; yourself.
 fork := self newButton label: 'Fork from here'; action: [ self performAction: [
  self selectedExchange ifNotNil: [ :exchange | self openForkAt: exchange ] ] ]; yourself.
 usage := self newLabel.
 status := self newLabel.
 nextUsage := self newLabel.
 input whenTextChangedDo: [ self showNextEstimate ]
]

{ #category : 'layout' }
SmallGPTalkChat >> defaultLayout [
 | layout |
 layout := SpBoxLayout newVertical spacing: 8; borderWidth: 8.
 modelSelector ifNotNil: [ layout add: modelSelector height: 30 ].
 improvementControls ifNotNil: [ layout add: improvementControls height: 60 ].
 ^ layout add: (SpBoxLayout newHorizontal spacing: 12;
  add: self historyLayout width: 210;
  add: self conversationLayout;
  yourself); yourself
]

{ #category : 'layout' }
SmallGPTalkChat >> historyLayout [
 ^ SpBoxLayout newVertical spacing: 6;
  add: (self newLabel label: 'History') expand: false;
  add: exchanges;
  add: (self newLabel label: 'Selected exchange') expand: false;
  add: inspect height: 28;
  add: inspectContext height: 28;
  add: inspectCalls height: 28;
  add: fork height: 28;
  yourself
]

{ #category : 'layout' }
SmallGPTalkChat >> conversationLayout [
 ^ SpBoxLayout newVertical spacing: 6;
  add: (self newLabel label: 'Conversation') expand: false;
  add: details;
  add: (SpBoxLayout newHorizontal spacing: 8;
   add: (SpBoxLayout newVertical add: usage; add: nextUsage; yourself);
   add: compact width: 90;
   yourself) height: 44;
  add: (self newLabel label: 'Your message') expand: false;
  add: input height: 110;
  add: (SpBoxLayout newHorizontal spacing: 6;
   add: status; add: cancel width: 90; add: send width: 90; yourself) height: 30;
  yourself
]

{ #category : 'initialization' }
SmallGPTalkChat >> initializeWindow: window [
 super initializeWindow: window.
 window title: 'SmallGPTalk'; initialExtent: 940 @ 700;
  whenClosedDo: [ self disconnect ]
]

{ #category : 'connection' }
SmallGPTalkChat >> connectTo: aSession [
 | subscription |
 self disconnect.
 improvementControls := nil.
 session := aSession.
 subscription := session whenChanged: [ :exchange |
  self application defer: [ self refreshFor: exchange from: subscription ] ].
 observer := subscription.
 exchanges items: #().
 status label: ''.
 self selectCurrentModel.
 self refresh
]

{ #category : 'actions' }
SmallGPTalkChat >> openForkAt: exchange [
 | view |
 view := self class forSession: (session forkAt: exchange).
 provider ifNotNil: [ view useProvider: provider ].
 view open
]

{ #category : 'updating' }
SmallGPTalkChat >> refreshFor: exchange from: subscription [
 (subscription notNil and: [ observer == subscription ]) ifTrue: [
  self refreshFor: exchange ]
]

{ #category : 'connection' }
SmallGPTalkChat >> disconnect [
 observer ifNotNil: [ session removeObserver: observer. observer := nil ].
 improvementControls ifNotNil: [ improvementControls disconnect ]
]

{ #category : 'accessing' }
SmallGPTalkChat >> session [ ^ session ]

{ #category : 'accessing' }
SmallGPTalkChat >> selectedExchange [ ^ exchanges selectedItem ]

{ #category : 'accessing' }
SmallGPTalkChat >> contextText [ ^ usage label ]

{ #category : 'accessing' }
SmallGPTalkChat >> statusText [ ^ status label ]

{ #category : 'updating' }
SmallGPTalkChat >> refreshFor: exchange [
 self refresh.
 exchange context isCompaction ifTrue: [
  status label: 'Compaction ', exchange state asString,
   (exchange error ifNil: [ '.' ] ifNotNil: [ :error | ': ', error ]) ]
]

{ #category : 'updating' }
SmallGPTalkChat >> refresh [
 | history selected follow |
 session ifNil: [ ^ self ].
 selected := self selectedExchange.
 follow := selected isNil or: [ exchanges items notEmpty and: [ selected == exchanges items last ] ].
 history := session conversation.
 refreshingHistory := true.
 [
  exchanges items: history.
  history ifNotEmpty: [
   follow ifTrue: [ exchanges selectIndex: history size scrollToSelection: true ]
    ifFalse: [ self selectExchange: selected ] ]
 ] ensure: [ refreshingHistory := false ].
 self showSelection
]

{ #category : 'updating' }
SmallGPTalkChat >> showSelection [
 | exchange |
 exchange := self selectedExchange.
 self showContextUsage.
 self showNextEstimate.
 exchange ifNil: [ details show: '' for: nil. ^ self ].
 details show: (SmallGPTalkMessageText forExchange: exchange) for: exchange
]

{ #category : 'updating' }
SmallGPTalkChat >> showContextUsage [
 | exchange percentage measured |
 exchange := self selectedExchange.
 exchange ifNil: [ usage label: 'Context: no request selected'. ^ self ].
 measured := exchange modelUsage.
 measured ifNotNil: [
  usage label: 'Context: ', measured percentage asString, '% (', measured inputTokens asString,
   ' / ', measured capacity asString, ' input tokens)'.
  ^ self ].
 percentage := session context usageFor: exchange modelContext.
 usage label: (percentage ifNil: [ 'Context: no character limit' ]
  ifNotNil: [ 'Context: ', percentage asString, '% of character limit' ])
]

{ #category : 'actions' }
SmallGPTalkChat >> sendMessage [
 input text trimBoth ifEmpty: [ ^ self ].
 self performAction: [
  input text trimBoth = '/compact'
   ifTrue: [ session compact ]
   ifFalse: [ session send: input text ].
  input text: ''.
  self refresh ]
]

{ #category : 'private' }
SmallGPTalkChat >> performAction: aBlock [
 [ aBlock value. status label: '' ]
  on: Error , Halt do: [ :error | status label: error messageText ]
]

{ #category : 'actions' }
SmallGPTalkChat >> cancelRun [
 self performAction: [ session cancel. self refresh ]
]

{ #category : 'selection' }
SmallGPTalkChat >> selectExchange: exchange [
 | index |
 index := exchanges items identityIndexOf: exchange.
 index > 0 ifTrue: [ exchanges selectIndex: index scrollToSelection: true ]
]

{ #category : 'configuration' }
SmallGPTalkChat >> useImprovement: improvement [
 improvement session == session ifFalse: [ self error: 'Use improvement for this chat session.' ].
 improvementControls ifNotNil: [ improvementControls disconnect ].
 improvementControls := self instantiate: SmallGPTalkImprovementControls.
 improvementControls connectTo: improvement
]

{ #category : 'updating' }
SmallGPTalkChat >> showNextEstimate [
 | estimate |
 session ifNil: [ ^ self ].
 [
  estimate := session estimateFor: input text.
  nextUsage label: (estimate ifNil: [ 'Next request estimate: unavailable' ]
   ifNotNil: [ 'Next request estimate: ', estimate percentage asString, '% (~',
    estimate inputTokens asString, ' / ', estimate capacity asString, ' input tokens)' ])
 ] on: Error do: [ :error | nextUsage label: 'Next request estimate: unavailable' ]
]

{ #category : 'accessing' }
SmallGPTalkChat >> estimateText [ ^ nextUsage label ]

{ #category : 'configuration' }
SmallGPTalkChat >> messageText: text [ input text: text ]
