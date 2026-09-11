"Open a chat draft with the selected class definition."
Class {
	#name : 'SmallGPTalkAskClassCommand',
	#superclass : 'CmdCommand',
	#instVars : [ 'selectedClass' ],
	#category : 'SmallGPTalk-Chat',
	#package : 'SmallGPTalk-Chat'
}

{ #category : 'activation' }
SmallGPTalkAskClassCommand class >> classMenuActivation [
	<classAnnotation>
	^ CmdContextMenuActivation byRootGroupItemOrder: 90 for: ClyClass asCalypsoItemContext
]

{ #category : 'accessing' }
SmallGPTalkAskClassCommand >> defaultMenuItemName [
	^ 'Ask SmallGPTalk'
]

{ #category : 'execution' }
SmallGPTalkAskClassCommand >> prepareFullExecutionInContext: context [
	super prepareFullExecutionInContext: context.
	selectedClass := context lastSelectedClass
]

{ #category : 'execution' }
SmallGPTalkAskClassCommand >> execute [
	selectedClass ifNotNil: [ SmallGPTalkChat askAbout: selectedClass ]
]
