"Create a tool through the public protocol. Use a development image."
| clockToolClass clockTool |

clockToolClass := Smalltalk classInstaller make: [ :builder |
	builder
		name: #SmallGPTalkExampleClockTool;
		superclass: SmallGPTalkTool;
		package: 'SmallGPTalk-Examples' ].
clockToolClass compile: 'newForSession ^ self class new' classified: 'sessions'.
clockToolClass compile: 'name ^ ''clock''' classified: 'accessing'.
clockToolClass compile: 'description ^ ''Return the current local date and time.''' classified: 'accessing'.
clockToolClass compile: 'inputSchema
	^ Dictionary new
		at: ''type'' put: ''object'';
		at: ''properties'' put: Dictionary new;
		at: ''required'' put: #();
		at: ''additionalProperties'' put: false;
		yourself' classified: 'accessing'.
clockToolClass compile: 'execute: arguments context: aRun
	aRun checkCancellation.
	^ SmallGPTalkToolResult text: DateAndTime now asString' classified: 'execution'.

clockTool := clockToolClass new.
clockTool execute: Dictionary new context: SmallGPTalkRun new.

"Supply the tool when you create a session: session tools: { clockTool }."
