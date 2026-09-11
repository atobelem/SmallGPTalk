| engine classes report |
engine := ReCriticEngine new.
classes := Smalltalk allClasses select: [ :class | (class name beginsWith: 'SmallGPTalk') or: [ class name = 'BaselineOfSmallGPTalk' ] ].
report := Stdio stdout.
[
 classes do: [ :class |
  { class. class class } do: [ :behavior |
   (engine critiquesOf: behavior) do: [ :critic |
    report nextPutAll: behavior name; nextPut: Character tab; nextPutAll: critic rule class name; nextPut: Character tab; nextPutAll: critic rule name; lf ].
   behavior localMethods do: [ :method |
    ((engine critiquesOf: method), (engine nodeCritiquesOf: method)) do: [ :critic |
     report nextPutAll: behavior name, '>>', method selector; nextPut: Character tab;
      nextPutAll: critic rule class name; nextPut: Character tab; nextPutAll: critic rule name; lf ] ] ] ]
] ensure: [ report flush ].
Smalltalk exit: 0.
