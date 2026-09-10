Class {
	#name : 'SmallGPTalkSearchTool',
	#superclass : 'SmallGPTalkImageTool',
	#category : 'SmallGPTalk-Pharo',
	#package : 'SmallGPTalk-Pharo'
}

{ #category : 'accessing' }
SmallGPTalkSearchTool >> name [
	^ 'search'
]

{ #category : 'accessing' }
SmallGPTalkSearchTool >> description [
	^ 'Find package names, class names, and method selectors that contain the query. Search ignores letter case. Results include at most limit entries.'
]

{ #category : 'accessing' }
SmallGPTalkSearchTool >> inputSchema [
	^ self schema: (Dictionary new
		at: 'query' put: self stringSchema;
		at: 'kind' put: (self stringSchema at: 'enum' put: #('all' 'packages' 'classes' 'selectors'); yourself);
		at: 'limit' put: (Dictionary new at: 'type' put: 'integer'; at: 'minimum' put: 1; at: 'maximum' put: 500; yourself);
		yourself) required: #('query')
]

{ #category : 'private' }
SmallGPTalkSearchTool >> performTool: arguments context: aRun [
	| query kind limit matches result |
	query := (arguments at: 'query') asLowercase.
	kind := arguments at: 'kind' ifAbsent: [ 'all' ].
	limit := arguments at: 'limit' ifAbsent: [ 100 ].
	(limit between: 1 and: 500) ifFalse: [ self error: 'The search limit must be between 1 and 500.' ].
	matches := OrderedCollection new.
	result := Dictionary new at: 'truncated' put: false; yourself.
	self matchesContaining: query kind: kind context: aRun do: [ :match |
		matches size = limit ifTrue: [
			^ result at: 'matches' put: matches asArray; at: 'truncated' put: true; yourself ].
		matches add: match ].
	^ result at: 'matches' put: matches asArray; yourself
]

{ #category : 'private' }
SmallGPTalkSearchTool >> matchesContaining: query kind: kind context: aRun do: aBlock [
	(kind = 'all' or: [ kind = 'packages' ]) ifTrue: [
		self packageMatchesContaining: query context: aRun do: aBlock ].
	kind = 'packages' ifTrue: [ ^ self ].
	(Smalltalk allClasses sorted: [ :a :b | a name <= b name ]) do: [ :class |
		aRun checkCancellation.
		((kind = 'all' or: [ kind = 'classes' ]) and: [ class name asLowercase includesSubstring: query ]) ifTrue: [
			aBlock value: (Dictionary new at: 'kind' put: 'class'; at: 'name' put: class name asString; yourself) ].
		(kind = 'all' or: [ kind = 'selectors' ]) ifTrue: [
			self selectorMatchesContaining: query in: class do: aBlock ] ]
]

{ #category : 'private' }
SmallGPTalkSearchTool >> packageMatchesContaining: query context: aRun do: aBlock [
	(Smalltalk packageOrganizer packages sorted: [ :a :b | a name <= b name ]) do: [ :package |
		aRun checkCancellation.
		(package name asLowercase includesSubstring: query) ifTrue: [
			aBlock value: (Dictionary new at: 'kind' put: 'package'; at: 'name' put: package name asString; yourself) ] ]
]

{ #category : 'private' }
SmallGPTalkSearchTool >> selectorMatchesContaining: query in: class do: aBlock [
	{ class. class class } do: [ :behavior |
		behavior selectors sorted do: [ :selector |
			(selector asLowercase includesSubstring: query) ifTrue: [
				aBlock value: (Dictionary new
					at: 'kind' put: 'selector'; at: 'name' put: selector asString;
					at: 'class' put: class name asString;
					at: 'side' put: (behavior isClassSide ifTrue: [ 'class' ] ifFalse: [ 'instance' ]);
					yourself) ] ] ]
]
