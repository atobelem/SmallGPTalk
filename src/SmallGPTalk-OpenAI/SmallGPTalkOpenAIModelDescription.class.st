"Describe one model and its allowed effort levels from the account catalog."
Class {
 #name : 'SmallGPTalkOpenAIModelDescription',
 #superclass : 'Object',
 #instVars : [ 'identifier', 'efforts', 'contextWindow' ],
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'instance creation' }
SmallGPTalkOpenAIModelDescription class >> from: record [
 ^ self new read: record; yourself
]

{ #category : 'initialization' }
SmallGPTalkOpenAIModelDescription >> read: record [
 | levels |
 contextWindow := record at: 'context_window' ifAbsent: [ nil ].
 (contextWindow isNil or: [ contextWindow isInteger and: [ contextWindow > 0 ] ])
  ifFalse: [ self error: 'The model context window is invalid.' ].
 identifier := record at: 'slug' ifAbsent: [ nil ].
 (identifier isString and: [ identifier notEmpty ]) ifFalse: [ self error: 'The catalog model has no identifier.' ].
 levels := record at: 'supported_reasoning_levels' ifAbsent: [ #() ].
 levels isArray ifFalse: [ self error: 'The catalog effort list is invalid.' ].
 efforts := levels collect: [ :level |
  | effort |
  level isDictionary ifFalse: [ self error: 'The catalog effort is invalid.' ].
  effort := level at: 'effort' ifAbsent: [ nil ].
  (effort isString and: [ effort notEmpty ]) ifFalse: [ self error: 'The catalog effort is invalid.' ].
  effort copy ].
 identifier := identifier copy
]

{ #category : 'accessing' }
SmallGPTalkOpenAIModelDescription >> identifier [ ^ identifier copy ]

{ #category : 'accessing' }
SmallGPTalkOpenAIModelDescription >> contextWindow [ ^ contextWindow ]

{ #category : 'accessing' }
SmallGPTalkOpenAIModelDescription >> efforts [ ^ efforts collect: #copy ]

{ #category : 'validation' }
SmallGPTalkOpenAIModelDescription >> requireEffort: level [
 (efforts includes: level) ifFalse: [ self error: 'The model does not support this effort.' ]
]
