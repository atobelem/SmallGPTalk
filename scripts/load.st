"Load only the new source into a clean image."
(Smalltalk version beginsWith: 'Pharo13') ifFalse: [ Error signal: 'Use Pharo 13.' ].
Metacello new
 baseline: 'SmallGPTalk';
 repository: 'tonel://', (Smalltalk os environment at: 'SMALLGPTALK_ROOT'), '/src';
 load.
Smalltalk snapshot: true andQuit: true.
