"Open a chat draft with the selected method source."
Class {
	#name : 'SmallGPTalkAskMethodCommand',
	#superclass : 'SycMethodCommand',
	#category : 'SmallGPTalk-Chat',
	#package : 'SmallGPTalk-Chat'
}

{ #category : 'activation' }
SmallGPTalkAskMethodCommand class >> methodMenuActivation [
	<classAnnotation>
	^ CmdContextMenuActivation byRootGroupItemOrder: 90 for: ClyMethod asCalypsoItemContext
]

{ #category : 'accessing' }
SmallGPTalkAskMethodCommand >> defaultMenuItemName [
	^ 'Ask SmallGPTalk'
]

{ #category : 'execution' }
SmallGPTalkAskMethodCommand >> execute [
	methods ifNotEmpty: [ SmallGPTalkChat askAbout: methods first ]
]
