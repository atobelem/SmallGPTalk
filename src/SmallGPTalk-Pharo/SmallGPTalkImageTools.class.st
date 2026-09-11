"Create the default collection of image tools for a session."
Class {
	#name : 'SmallGPTalkImageTools',
	#superclass : 'Object',
	#category : 'SmallGPTalk-Pharo',
	#package : 'SmallGPTalk-Pharo'
}

{ #category : 'accessing' }
SmallGPTalkImageTools class >> all [
	^ { SmallGPTalkEvaluateTool new }
]
