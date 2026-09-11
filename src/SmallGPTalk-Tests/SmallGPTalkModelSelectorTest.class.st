Class {
 #name : 'SmallGPTalkModelSelectorTest',
 #superclass : 'TestCase',
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkModelSelectorTest >> testSelectionUsesTheModelEffortsAndRequiresApply [
 | selector descriptions chosen |
 descriptions := (STONJSON fromString: '[{"slug":"one","supported_reasoning_levels":[{"effort":"low"},{"effort":"high"}]},{"slug":"two","supported_reasoning_levels":[{"effort":"low"}]}]')
  collect: [ :record | SmallGPTalkOpenAIModelDescription from: record ].
 selector := (Smalltalk globals at: #SmallGPTalkModelSelector) new.
 selector models: descriptions; onChoose: [ :identifier :effort | chosen := { identifier. effort } ].
 selector selectModel: 'one' effort: 'high'.
 self assert: selector availableEfforts equals: #('low' 'high').
 self assert: chosen isNil.
 selector applySelection.
 self assert: chosen equals: #('one' 'high').
 selector selectModel: 'two' effort: 'low'.
 self assert: selector availableEfforts equals: #('low').
 selector applySelection.
 self assert: chosen equals: #('two' 'low')
]
