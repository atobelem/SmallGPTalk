"Inspect compiled rewrite methods in a disposable loaded image."
[
 | classes methods issues |
 classes := Smalltalk globals allClasses select: [ :each |
  (each package name beginsWith: 'SmallGPTalk') or: [ each name = #BaselineOfSmallGPTalk ] ].
 methods := classes flatCollect: [ :each | each methods , each class methods ].
 issues := OrderedCollection new.
 methods do: [ :method |
  method usesUndeclareds ifTrue: [ issues add: method printString, ': undeclared reference' ].
  method ast selfMessages do: [ :selector |
   (method methodClass canUnderstand: selector) ifFalse: [
    issues add: method printString, ': missing self message ', selector ] ].
  method ast superMessages do: [ :selector |
   (method methodClass superclass canUnderstand: selector) ifFalse: [
    issues add: method printString, ': missing super message ', selector ] ] ].
 issues do: [ :issue | Stdio stdout nextPutAll: issue; lf ].
 Stdio stdout nextPutAll: 'Classes: '; print: classes size;
  nextPutAll: '. Methods: '; print: methods size;
  nextPutAll: '. Issues: '; print: issues size; lf.
 Smalltalk exit: (issues isEmpty ifTrue: [ 0 ] ifFalse: [ 1 ])
] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
