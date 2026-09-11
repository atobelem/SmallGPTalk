"Bind macOS Security framework functions through threaded FFI."
Class {
	#name : 'SmallGPTalkSecurityLibrary',
	#superclass : 'FFILibrary',
	#category : 'SmallGPTalk-OpenAI',
	#package : 'SmallGPTalk-OpenAI'
}

{ #category : 'accessing - platform' }
SmallGPTalkSecurityLibrary >> macLibraryName [
	^ '/System/Library/Frameworks/Security.framework/Security'
]

{ #category : 'accessing' }
SmallGPTalkSecurityLibrary >> runner [
	^ TFWorker default
]

{ #category : 'accessing' }
SmallGPTalkSecurityLibrary >> constant: aName [
	^ (ExternalAddress loadSymbol: aName module: self libraryName) pointerAt: 1
]

{ #category : 'native calls' }
SmallGPTalkSecurityLibrary >> add: attributes [
	^ self ffiCall: #(int32 SecItemAdd(void *attributes, void *0))
]

{ #category : 'native calls' }
SmallGPTalkSecurityLibrary >> copyMatching: query into: result [
	^ self ffiCall: #(int32 SecItemCopyMatching(void *query, void *result))
]

{ #category : 'native calls' }
SmallGPTalkSecurityLibrary >> update: query attributes: attributes [
	^ self ffiCall: #(int32 SecItemUpdate(void *query, void *attributes))
]

{ #category : 'native calls' }
SmallGPTalkSecurityLibrary >> delete: query [
	^ self ffiCall: #(int32 SecItemDelete(void *query))
]

{ #category : 'native calls' }
SmallGPTalkSecurityLibrary >> openKeychain: path into: result [
	^ self ffiCall: #(int32 SecKeychainOpen(char *path, void *result))
]

{ #category : 'native calls' }
SmallGPTalkSecurityLibrary >> randomBytes: buffer size: count [
	^ self ffiCall: #(int32 SecRandomCopyBytes(void *0, size_t count, void *buffer))
]
