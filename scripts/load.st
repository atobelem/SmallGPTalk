| root group |
root := Smalltalk os environment at: 'SMALLGPTALK_ROOT'.
group := Smalltalk os environment at: 'SMALLGPTALK_LOAD_GROUP' ifAbsent: [ 'Tests' ].
(Smalltalk version beginsWith: 'Pharo13') ifFalse: [
	Error signal: 'SmallGPTalk requires Pharo 13 for this release.' ].
Metacello new
	baseline: 'SmallGPTalk';
	repository: 'tonel://', root, '/src';
	load: group.
Smalltalk snapshot: true andQuit: true.
