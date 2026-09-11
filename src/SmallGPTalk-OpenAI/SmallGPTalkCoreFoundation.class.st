"Bind the Core Foundation values used by the Keychain adapter."
Class {
 #name : 'SmallGPTalkCoreFoundation',
 #superclass : 'FFILibrary',
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'accessing' }
SmallGPTalkCoreFoundation >> macLibraryName [ ^ '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation' ]

{ #category : 'symbols' }
SmallGPTalkCoreFoundation >> symbol: name [ ^ ExternalAddress loadSymbol: name module: self libraryName ]

{ #category : 'symbols' }
SmallGPTalkCoreFoundation >> constant: name [ ^ (self symbol: name) pointerAt: 1 ]

{ #category : 'native' }
SmallGPTalkCoreFoundation >> release: reference [ ^ self ffiCall: #(void CFRelease(void *reference)) ]

{ #category : 'native' }
SmallGPTalkCoreFoundation >> newDictionaryKeys: keys values: values [
 ^ self ffiCall: #(void *CFDictionaryCreateMutable(void *0, long 0, void *keys, void *values))
]

{ #category : 'native' }
SmallGPTalkCoreFoundation >> dictionary: dictionary at: key put: value [
 ^ self ffiCall: #(void CFDictionarySetValue(void *dictionary, void *key, void *value))
]

{ #category : 'native' }
SmallGPTalkCoreFoundation >> stringBytes: bytes count: count [
 ^ self ffiCall: #(void *CFStringCreateWithBytes(void *0, void *bytes, long count, uint32 134217984, uint8 0))
]

{ #category : 'native' }
SmallGPTalkCoreFoundation >> dataBytes: bytes count: count [
 ^ self ffiCall: #(void *CFDataCreate(void *0, void *bytes, long count))
]

{ #category : 'native' }
SmallGPTalkCoreFoundation >> dataLength: data [ ^ self ffiCall: #(long CFDataGetLength(void *data)) ]

{ #category : 'native' }
SmallGPTalkCoreFoundation >> dataPointer: data [ ^ self ffiCall: #(void *CFDataGetBytePtr(void *data)) ]

{ #category : 'native' }
SmallGPTalkCoreFoundation >> array: pointers count: count callbacks: callbacks [
 ^ self ffiCall: #(void *CFArrayCreate(void *0, void *pointers, long count, void *callbacks))
]

{ #category : 'allocation' }
SmallGPTalkCoreFoundation >> dictionaryDuring: aBlock [
 | dictionary |
 dictionary := self newDictionaryKeys: (self symbol: 'kCFTypeDictionaryKeyCallBacks') values: (self symbol: 'kCFTypeDictionaryValueCallBacks').
 ^ [ aBlock value: dictionary ] ensure: [ self release: dictionary ]
]

{ #category : 'allocation' }
SmallGPTalkCoreFoundation >> string: text during: aBlock [
 | bytes reference |
 bytes := text utf8Encoded.
 reference := self stringBytes: bytes count: bytes size.
 ^ [ aBlock value: reference ] ensure: [ self release: reference ]
]

{ #category : 'allocation' }
SmallGPTalkCoreFoundation >> data: bytes during: aBlock [
 | reference |
 reference := self dataBytes: bytes count: bytes size.
 ^ [ aBlock value: reference ] ensure: [ self release: reference ]
]

{ #category : 'allocation' }
SmallGPTalkCoreFoundation >> arrayWith: reference during: aBlock [
 ^ ExternalAddress allocate: ExternalAddress wordSize bytesDuring: [ :buffer |
  | array |
  buffer pointerAt: 1 put: reference.
  array := self array: buffer count: 1 callbacks: (self symbol: 'kCFTypeArrayCallBacks').
  [ aBlock value: array ] ensure: [ self release: array ] ]
]

{ #category : 'conversion' }
SmallGPTalkCoreFoundation >> bytesFrom: data [
 | count |
 count := self dataLength: data.
 ^ count = 0 ifTrue: [ ByteArray new ] ifFalse: [ (self dataPointer: data) copyFrom: 1 to: count ]
]
