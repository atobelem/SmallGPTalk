Class {
 #name : 'SmallGPTalkRefreshQueueTest',
 #superclass : 'TestCase',
 #category : 'SmallGPTalk-Tests'
}

{ #category : 'tests' }
SmallGPTalkRefreshQueueTest >> testBurstQueuesOneRefreshWithTheLatestValue [
 | queue scheduled seen |
 scheduled := OrderedCollection new. seen := OrderedCollection new.
 queue := SmallGPTalkRefreshQueue schedule: [ :work | scheduled add: work ]
  deliver: [ :value | seen add: value ].
 1 to: 1000 do: [ :index | queue request: index ].
 self assert: scheduled size equals: 1.
 self assert: seen isEmpty.
 scheduled removeFirst value.
 self assert: seen asArray equals: #(1000).
 queue request: 1001.
 self assert: scheduled size equals: 1.
 scheduled removeFirst value.
 self assert: seen asArray equals: #(1000 1001)
]

{ #category : 'tests' }
SmallGPTalkRefreshQueueTest >> testStopDiscardsQueuedAndLaterNotifications [
 | queue scheduled seen |
 scheduled := OrderedCollection new. seen := OrderedCollection new.
 queue := SmallGPTalkRefreshQueue schedule: [ :work | scheduled add: work ]
  deliver: [ :value | seen add: value ].
 queue request: 'Old'; stop; request: 'Late'.
 self assert: scheduled size equals: 1.
 scheduled removeFirst value.
 self assert: seen isEmpty
]

{ #category : 'tests' }
SmallGPTalkRefreshQueueTest >> testAnUpdateDuringDeliveryQueuesAnotherRefresh [
 | queue scheduled seen |
 scheduled := OrderedCollection new. seen := OrderedCollection new.
 queue := SmallGPTalkRefreshQueue schedule: [ :work | scheduled add: work ]
  deliver: [ :value | seen add: value. value = 1 ifTrue: [ queue request: 2 ] ].
 queue request: 1.
 scheduled removeFirst value.
 self assert: scheduled size equals: 1.
 scheduled removeFirst value.
 self assert: seen asArray equals: #(1 2)
]
