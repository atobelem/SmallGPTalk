"Serialize selected conversation records without reading live evaluation values."
Class {
 #name : 'SmallGPTalkOpenAIRequest',
 #superclass : 'Object',
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'encoding' }
SmallGPTalkOpenAIRequest >> encode: request model: model effort: effort [
 (model isString and: [ model trimBoth notEmpty ]) ifFalse: [ self error: 'Select an explicit model identifier.' ].
 (effort isString and: [ effort notEmpty ]) ifFalse: [ self error: 'Select a reasoning effort.' ].
 ^ Dictionary new
  at: 'model' put: model;
  at: 'store' put: false;
  at: 'stream' put: true;
  at: 'instructions' put: request instructions;
  at: 'include' put: #('reasoning.encrypted_content');
  at: 'reasoning' put: (Dictionary new at: 'effort' put: effort; yourself);
  at: 'input' put: (self inputFor: request);
  at: 'tools' put: (request isCompaction ifTrue: [ #() ] ifFalse: [ request tools collect: [ :tool | self describe: tool ] ]);
  yourself
]

{ #category : 'private' }
SmallGPTalkOpenAIRequest >> inputFor: request [
 | input |
 input := OrderedCollection new.
 request summaryIsContinuation ifFalse: [
  request summary ifNotNil: [ :text | input add: (self message: text role: 'developer') ] ].
 request history do: [ :exchange |
  input add: (self message: exchange request role: 'user').
  exchange replies do: [ :reply | self append: reply to: input ] ].
 input add: (self message: request text role: 'user').
 request summaryIsContinuation ifTrue: [
  request summary ifNotNil: [ :text | input add: (self message: text role: 'assistant') ] ].
 request replies do: [ :reply | self append: reply to: input ].
 ^ input asArray
]

{ #category : 'private' }
SmallGPTalkOpenAIRequest >> message: text role: role [
 ^ Dictionary new at: 'role' put: role; at: 'content' put: text; yourself
]

{ #category : 'private' }
SmallGPTalkOpenAIRequest >> append: reply to: input [
 reply providerData
  ifNotNil: [ :data | input addAll: (data at: 'output') ]
  ifNil: [
   reply continuationText ifNotEmpty: [ :text | input add: (self message: text role: 'assistant') ].
   reply calls do: [ :call | input add: (Dictionary new
    at: 'type' put: 'function_call'; at: 'call_id' put: call id;
    at: 'name' put: call name; at: 'arguments' put: (STONJSON toString: call arguments); yourself) ] ].
 reply calls do: [ :call |
  (#(pending running) includes: call state) ifTrue: [ self error: 'Wait for the tool call to finish.' ].
  input add: (Dictionary new at: 'type' put: 'function_call_output';
   at: 'call_id' put: call id; at: 'output' put: (self outputFor: call); yourself) ]
]

{ #category : 'private' }
SmallGPTalkOpenAIRequest >> outputFor: call [
 call state = #cancelled ifTrue: [ ^ 'The tool call was cancelled.' ].
 ^ call operation ifNil: [ call error ifNil: [ 'The tool call has no output.' ] ]
  ifNotNil: [ :operation | operation output ]
]

{ #category : 'private' }
SmallGPTalkOpenAIRequest >> describe: tool [
 ^ Dictionary new at: 'type' put: 'function'; at: 'name' put: tool name;
  at: 'description' put: tool description; at: 'parameters' put: tool parameters;
  at: 'strict' put: true; yourself
]
