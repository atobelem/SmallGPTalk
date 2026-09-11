"A selectable view of live conversation objects. Rendering does not execute code."
Class {
	#name : 'SmallGPTalkConversationPresenter',
	#superclass : 'SpTextPresenter',
	#instVars : [ 'entries', 'currentEntry', 'contextObjects', 'closed', 'assistantName', 'refreshPending' ],
	#category : 'SmallGPTalk-Chat',
	#package : 'SmallGPTalk-Chat'
}

{ #category : 'initialization' }
SmallGPTalkConversationPresenter >> initialize [
	super initialize.
	entries := OrderedCollection new.
	contextObjects := [ #() ].
	closed := false.
	refreshPending := false.
	self whenSelectionChangedDo: [ :newSelection |
		(refreshPending and: [ newSelection isEmpty ]) ifTrue: [
			UIManager default defer: [ closed ifFalse: [ self refresh ] ] ] ].
	assistantName := 'SmallGPTalk'.
	self beNotEditable; beWrapWord;
		placeholder: 'Your conversation appears here. Select text or a message and use the context menu.';
		contextMenu: [ self objectMenu ]
]

{ #category : 'accessing' }
SmallGPTalkConversationPresenter >> entries [ ^ entries copy ]

{ #category : 'accessing' }
SmallGPTalkConversationPresenter >> contextObjects: aBlock [ contextObjects := aBlock ]

{ #category : 'display' }
SmallGPTalkConversationPresenter >> addObject: anObject title: title source: source markdown: markdown [
	currentEntry := SmallGPTalkChatEntry new
		object: anObject; title: title; source: source; markdown: markdown; yourself.
	entries add: currentEntry.
	self refresh.
	^ currentEntry
]

{ #category : 'display' }
SmallGPTalkConversationPresenter >> append: source [
	currentEntry ifNil: [ self addObject: nil title: '' source: '' markdown: false ].
	currentEntry source: currentEntry source, source.
	self refresh
]

{ #category : 'display' }
SmallGPTalkConversationPresenter >> appendAssistant: fragment [
	self hasAssistantEntry ifFalse: [
		self addObject: (SmallGPTalkMessage assistant: '') title: assistantName source: '' markdown: true ].
	currentEntry markdown: true.
	self append: fragment.
	currentEntry object text: currentEntry source
]

{ #category : 'display' }
SmallGPTalkConversationPresenter >> bindCurrentMessage: aMessage [
	aMessage ifNil: [ ^ self ].
	(entries anySatisfy: [ :entry | entry object == aMessage ]) ifTrue: [ ^ self ].
	self hasAssistantEntry ifFalse: [
		self addObject: aMessage title: assistantName source: aMessage text markdown: true.
		^ self ].
	currentEntry object: aMessage; source: aMessage text.
	self refresh
]

{ #category : 'display' }
SmallGPTalkConversationPresenter >> refresh [
	| rendered first |
	self selectionInterval ifNotEmpty: [ refreshPending := true. ^ self ].
	refreshPending := false.
	rendered := Text new.
	entries do: [ :entry |
		rendered ifNotEmpty: [ rendered append: String cr, String cr ].
		first := rendered size + 1.
		rendered append: entry rendered.
		entry rangeFrom: first to: rendered size ].
	self text: rendered.
	self selectionInterval: (rendered size + 1 to: rendered size).
	self scrollToLatest
]

{ #category : 'display' }
SmallGPTalkConversationPresenter >> scrollToLatest [
	UIManager default defer: [
		(closed not and: [ self selectionInterval isEmpty ]) ifTrue: [ self withAdapterDo: [ :textAdapter | textAdapter widget scrollToEndOfText ] ] ]
]

{ #category : 'display' }
SmallGPTalkConversationPresenter >> clear [
	refreshPending := false.
	entries removeAll.
	currentEntry := nil.
	self text: ''.
	self selectionInterval: (1 to: 0)
]

{ #category : 'actions' }
SmallGPTalkConversationPresenter >> close [
	closed := true.
	self clear.
	contextObjects := [ #() ]
]

{ #category : 'selection' }
SmallGPTalkConversationPresenter >> entryAt: index [
	^ entries detect: [ :entry | entry includesPosition: index ] ifNone: [ nil ]
]

{ #category : 'selection' }
SmallGPTalkConversationPresenter >> selectedEntry [
	^ self entryAt: self selectionInterval first
]

{ #category : 'actions' }
SmallGPTalkConversationPresenter >> objectMenu [
	| menu entry selected target |
	menu := SpMenuPresenter new.
	entry := self selectedEntry.
	selected := self selectedText.
	target := self browseTargetFor: selected.
	menu addGroup: [ :group |
		entry ifNotNil: [ self addActionsForEntry: entry to: group ].
		selected ifNotEmpty: [
			group addItem: [ :item | item name: 'Copy text'; action: [ Clipboard clipboardText: selected ] ].
			group addItem: [ :item | item name: 'Open selection in Playground'; action: [ self openCode: selected ] ] ].
		target ifNotNil: [ group addItem: [ :item | item name: 'Browse selection'; action: [ target browse ] ] ] ].
	menu addGroup: [ :group |
		contextObjects value do: [ :association |
			association value ifNotNil: [ :object |
				group addItem: [ :item | item name: 'Inspect ', association key; action: [ object inspect ] ] ] ] ].
	^ menu
]

{ #category : 'actions' }
SmallGPTalkConversationPresenter >> openCode: source [
	^ StPlaygroundPresenter openContents: source
]

{ #category : 'actions' }
SmallGPTalkConversationPresenter >> browse: object [
	((object isKindOf: Behavior) or: [ object isKindOf: CompiledMethod ])
		ifTrue: [ object browse ] ifFalse: [ object class browse ]
]

{ #category : 'selection' }
SmallGPTalkConversationPresenter >> browseTargetFor: source [
	| name split selector classSide class |
	name := source trimBoth.
	name isEmpty ifTrue: [ ^ nil ].
	split := name findString: '>>'.
	selector := split = 0 ifTrue: [ nil ] ifFalse: [ (name allButFirst: split + 1) trimBoth ].
	split > 0 ifTrue: [ name := (name first: split - 1) trimBoth ].
	classSide := name endsWith: ' class'.
	classSide ifTrue: [ name := name allButLast: 6 ].
	class := Smalltalk globals at: name asSymbol ifAbsent: [ ^ nil ].
	(class isKindOf: Behavior) ifFalse: [ ^ nil ].
	classSide ifTrue: [ class := class class ].
	selector ifNil: [ ^ class ].
	(selector beginsWith: '#') ifTrue: [ selector := selector allButFirst ].
	^ class lookupSelector: selector asSymbol
]

{ #category : 'testing' }
SmallGPTalkConversationPresenter >> hasAssistantEntry [
	^ currentEntry isNotNil and: [
		(currentEntry object isKindOf: SmallGPTalkMessage) and: [ currentEntry object role = #assistant ] ]
]

{ #category : 'accessing' }
SmallGPTalkConversationPresenter >> assistantName: aString [ assistantName := aString ]

{ #category : 'private - menus' }
SmallGPTalkConversationPresenter >> addActionsForEntry: entry to: group [
	entry object ifNotNil: [ :object |
		group addItem: [ :item | item name: 'Inspect object'; action: [ object inspect ] ].
		(object isKindOf: SmallGPTalkEvaluationResult) ifTrue: [
			self addActionsForEvaluation: object to: group ] ].
	group addItem: [ :item | item name: 'Inspect display entry'; action: [ entry inspect ] ]
]

{ #category : 'private - menus' }
SmallGPTalkConversationPresenter >> addActionsForEvaluation: result to: group [
	group addItem: [ :item | item name: 'Inspect value'; action: [ result value inspect ] ].
	group addItem: [ :item | item name: 'Browse result'; action: [ self browse: result value ] ].
	group addItem: [ :item | item name: 'Open expression in Playground'; action: [ self openCode: result expression ] ]
]
