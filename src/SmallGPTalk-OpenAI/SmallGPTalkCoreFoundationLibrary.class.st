Class {
	#name : 'SmallGPTalkCoreFoundationLibrary',
	#superclass : 'FFILibrary',
	#category : 'SmallGPTalk-OpenAI',
	#package : 'SmallGPTalk-OpenAI'
}

{ #category : 'accessing' }
SmallGPTalkCoreFoundationLibrary >> macLibraryName [
	^ '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation'
]

{ #category : 'accessing' }
SmallGPTalkCoreFoundationLibrary >> symbol: aName [
	^ ExternalAddress loadSymbol: aName module: self libraryName
]

{ #category : 'accessing' }
SmallGPTalkCoreFoundationLibrary >> constant: aName [
	^ (self symbol: aName) pointerAt: 1
]

{ #category : 'native calls' }
SmallGPTalkCoreFoundationLibrary >> release: reference [
	^ self ffiCall: #(void CFRelease(void *reference))
]

{ #category : 'native calls' }
SmallGPTalkCoreFoundationLibrary >> createDictionaryWithKeys: keyCallbacks values: valueCallbacks [
	^ self ffiCall: #(void *CFDictionaryCreateMutable(void *0, long 0, void *keyCallbacks, void *valueCallbacks))
]

{ #category : 'native calls' }
SmallGPTalkCoreFoundationLibrary >> dictionary: dictionary at: key put: value [
	^ self ffiCall: #(void CFDictionarySetValue(void *dictionary, void *key, void *value))
]

{ #category : 'native calls' }
SmallGPTalkCoreFoundationLibrary >> createStringBytes: bytes size: count [
	^ self ffiCall: #(void *CFStringCreateWithBytes(void *0, void *bytes, long count, uint32 134217984, uint8 0))
]

{ #category : 'native calls' }
SmallGPTalkCoreFoundationLibrary >> createDataBytes: bytes size: count [
	^ self ffiCall: #(void *CFDataCreate(void *0, void *bytes, long count))
]

{ #category : 'native calls' }
SmallGPTalkCoreFoundationLibrary >> dataLength: data [
	^ self ffiCall: #(long CFDataGetLength(void *data))
]

{ #category : 'native calls' }
SmallGPTalkCoreFoundationLibrary >> dataBytes: data [
	^ self ffiCall: #(void *CFDataGetBytePtr(void *data))
]

{ #category : 'native calls' }
SmallGPTalkCoreFoundationLibrary >> createArrayFrom: values size: count callbacks: callbacks [
	^ self ffiCall: #(void *CFArrayCreate(void *0, void *values, long count, void *callbacks))
]

{ #category : 'instance creation' }
SmallGPTalkCoreFoundationLibrary >> newDictionary [
	^ self
		createDictionaryWithKeys: (self symbol: 'kCFTypeDictionaryKeyCallBacks')
		values: (self symbol: 'kCFTypeDictionaryValueCallBacks')
]

{ #category : 'instance creation' }
SmallGPTalkCoreFoundationLibrary >> newString: aString [
	| bytes |
	bytes := aString utf8Encoded.
	^ self createStringBytes: bytes size: bytes size
]

{ #category : 'instance creation' }
SmallGPTalkCoreFoundationLibrary >> newData: bytes [
	^ self createDataBytes: bytes size: bytes size
]

{ #category : 'instance creation' }
SmallGPTalkCoreFoundationLibrary >> newArrayWith: reference [
	^ ExternalAddress allocate: ExternalAddress wordSize bytesDuring: [ :buffer |
		buffer pointerAt: 1 put: reference.
		self createArrayFrom: buffer size: 1 callbacks: (self symbol: 'kCFTypeArrayCallBacks') ]
]

{ #category : 'converting' }
SmallGPTalkCoreFoundationLibrary >> bytesFromData: reference [
	| size |
	size := self dataLength: reference.
	size = 0 ifTrue: [ ^ ByteArray new ].
	^ (self dataBytes: reference) copyFrom: 1 to: size
]
