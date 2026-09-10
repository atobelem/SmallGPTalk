Class {
	#name : 'BaselineOfSmallGPTalk',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfSmallGPTalk',
	#package : 'BaselineOfSmallGPTalk'
}

{ #category : 'baselines' }
BaselineOfSmallGPTalk >> baseline: spec [
	<baseline>
	spec for: #common do: [
		spec
			package: 'SmallGPTalk-Core';
			package: 'SmallGPTalk-OpenAI' with: [ spec requires: #('SmallGPTalk-Core') ];
			package: 'SmallGPTalk-Pharo' with: [ spec requires: #('SmallGPTalk-Core') ];
			package: 'SmallGPTalk-Chat' with: [ spec requires: #('SmallGPTalk-OpenAI' 'SmallGPTalk-Pharo') ];
			package: 'SmallGPTalk-Tests' with: [
				spec requires: #('SmallGPTalk-Core' 'SmallGPTalk-OpenAI' 'SmallGPTalk-Pharo' 'SmallGPTalk-Chat') ];
			group: 'Core' with: #('SmallGPTalk-Core');
			group: 'OpenAI' with: #('SmallGPTalk-OpenAI');
			group: 'Pharo' with: #('SmallGPTalk-Pharo');
			group: 'Chat' with: #('SmallGPTalk-Chat');
			group: 'default' with: #('SmallGPTalk-Core' 'SmallGPTalk-OpenAI' 'SmallGPTalk-Pharo');
			group: 'Tests' with: #('SmallGPTalk-Tests') ]
]
