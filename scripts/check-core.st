"Run in a clean image. Load only the core and check the public collaboration."
[
 | root check fixture agent session run fork original |
 root := OSPlatform current environment at: 'SMALLGPTALK_ROOT'.
 check := [ :condition :message | condition ifFalse: [ Error signal: message ] ].
 Metacello new baseline: 'SmallGPTalk';
  repository: 'tonel://', root, '/src'; load: 'SmallGPTalk-Core'.
 #(SmallGPTalkChat SmallGPTalkEvaluate SmallGPTalkOpenAIAccount) do: [ :name |
  check value: (Smalltalk globals includesKey: name) not
   value: 'The core check must not load UI, image tools, or OpenAI.' ].
 fixture := (Object << #SmallGPTalkCoreModelFixture)
  package: 'SmallGPTalk-Core-Check'; install.
 fixture compile: 'respondTo: request ^ request text' classified: 'model protocol'.
 agent := (Smalltalk globals at: #SmallGPTalkAgent) named: 'Ada'.
 session := agent newSessionWith: fixture new.
 run := session send: 'First'. run wait.
 check value: (run state = #completed) value: 'The core run did not complete.'.
 check value: (run result = 'First') value: 'The core result is incorrect.'.
 original := run exchange.
 fork := session forkAt: original.
 run := fork send: 'Second'. run wait.
 check value: (run result = 'Second') value: 'The fork did not continue.'.
 check value: (session conversation size = 1) value: 'The fork changed the source history.'.
 check value: (fork conversation size = 2) value: 'The fork lost its history.'.
 check value: (fork conversation first == original) not value: 'The fork did not copy the exchange.'.
 check value: (fork agent == agent) value: 'The fork lost its agent.'.
 Stdio stdout nextPutAll: 'PASS: core-only load, named agent, session, and independent fork.'; lf.
 Smalltalk exit: 0
] on: Error do: [ :error | Stdio stdout nextPutAll: error messageText; lf. Smalltalk exit: 1 ]
