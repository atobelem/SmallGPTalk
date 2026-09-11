"Use macOS Security through threaded FFI."
Class {
 #name : 'SmallGPTalkSecurity',
 #superclass : 'FFILibrary',
 #category : 'SmallGPTalk-OpenAI'
}

{ #category : 'accessing' }
SmallGPTalkSecurity >> macLibraryName [ ^ '/System/Library/Frameworks/Security.framework/Security' ]

{ #category : 'accessing' }
SmallGPTalkSecurity >> runner [ ^ TFWorker default ]

{ #category : 'random' }
SmallGPTalkSecurity >> randomBytes: count [
 (count isInteger and: [ count > 0 ]) ifFalse: [ self error: 'The random byte count must be positive.' ].
 ^ ExternalAddress allocate: count bytesDuring: [ :buffer |
  [
   (self fillRandom: buffer count: count) = 0 ifFalse: [ self error: 'The secure random source failed.' ].
   buffer copyFrom: 1 to: count
  ] ensure: [ 1 to: count do: [ :index | buffer unsignedByteAt: index put: 0 ] ] ]
]

{ #category : 'native' }
SmallGPTalkSecurity >> fillRandom: buffer count: count [
 ^ self ffiCall: #(int32 SecRandomCopyBytes(void *0, size_t count, void *buffer))
]

{ #category : 'symbols' }
SmallGPTalkSecurity >> constant: name [
 ^ (ExternalAddress loadSymbol: name module: self libraryName) pointerAt: 1
]

{ #category : 'native' }
SmallGPTalkSecurity >> add: attributes [ ^ self ffiCall: #(int32 SecItemAdd(void *attributes, void *0)) ]

{ #category : 'native' }
SmallGPTalkSecurity >> read: query into: result [ ^ self ffiCall: #(int32 SecItemCopyMatching(void *query, void *result)) ]

{ #category : 'native' }
SmallGPTalkSecurity >> update: query values: values [ ^ self ffiCall: #(int32 SecItemUpdate(void *query, void *values)) ]

{ #category : 'native' }
SmallGPTalkSecurity >> delete: query [ ^ self ffiCall: #(int32 SecItemDelete(void *query)) ]

{ #category : 'native' }
SmallGPTalkSecurity >> open: path into: result [ ^ self ffiCall: #(int32 SecKeychainOpen(char *path, void *result)) ]
