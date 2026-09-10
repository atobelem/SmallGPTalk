Class {
	#name : 'SmallGPTalkSecureRandom',
	#superclass : 'Object',
	#category : 'SmallGPTalk-OpenAI',
	#package : 'SmallGPTalk-OpenAI'
}

{ #category : 'accessing' }
SmallGPTalkSecureRandom class >> bytes: count [
	(count isInteger and: [ count >= 0 ]) ifFalse: [
		self error: 'The byte count must be a non-negative integer.' ].
	count = 0 ifTrue: [ ^ ByteArray new ].
	^ ExternalAddress allocate: count bytesDuring: [ :buffer |
		| status |
		[ status := SmallGPTalkSecurityLibrary uniqueInstance randomBytes: buffer size: count.
		status = 0 ifFalse: [ self error: 'The secure random source failed.' ].
		buffer copyFrom: 1 to: count ] ensure: [
			1 to: count do: [ :index | buffer unsignedByteAt: index put: 0 ] ] ]
]
