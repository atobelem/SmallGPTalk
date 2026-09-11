"Supply account and model catalog behavior for connection tests."
Class {
	#name : 'SmallGPTalkConnectionFixture',
	#superclass : 'Object',
	#instVars : [ 'authenticated', 'catalogBlock', 'gate', 'cancelled', 'requests' ],
	#category : 'SmallGPTalk-Tests',
	#package : 'SmallGPTalk-Tests'
}

{ #category : 'initialization' }
SmallGPTalkConnectionFixture >> initialize [
	super initialize.
	authenticated := true.
	cancelled := false.
	requests := 0.
	gate := Semaphore new.
	catalogBlock := [ #() ]
]

{ #category : 'account' }
SmallGPTalkConnectionFixture >> isAuthenticated [ ^ authenticated ]

{ #category : 'account' }
SmallGPTalkConnectionFixture >> authenticated: aBoolean [ authenticated := aBoolean ]

{ #category : 'account' }
SmallGPTalkConnectionFixture >> logout [ authenticated := false ]

{ #category : 'account' }
SmallGPTalkConnectionFixture >> beginLogin [ ^ self ]

{ #category : 'provider' }
SmallGPTalkConnectionFixture >> catalogBlock: aBlock [ catalogBlock := aBlock ]

{ #category : 'provider' }
SmallGPTalkConnectionFixture >> modelOptions [ requests := requests + 1. ^ catalogBlock value ]

{ #category : 'provider' }
SmallGPTalkConnectionFixture >> requests [ ^ requests ]

{ #category : 'login' }
SmallGPTalkConnectionFixture >> authorizationUrl [ ^ 'https://example.invalid/login' ]

{ #category : 'login' }
SmallGPTalkConnectionFixture >> wait [ gate wait ]

{ #category : 'login' }
SmallGPTalkConnectionFixture >> cancel [ cancelled := true. gate signal ]

{ #category : 'login' }
SmallGPTalkConnectionFixture >> state [ ^ cancelled ifTrue: [ #cancelled ] ifFalse: [ #completed ] ]

{ #category : 'error handling' }
SmallGPTalkConnectionFixture >> error [ ^ nil ]
