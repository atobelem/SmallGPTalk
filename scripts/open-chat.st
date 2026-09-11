"Start the UI before the background account request."
UIManager default defer: [
 [
  [ | account provider agent session |
   account := SmallGPTalkOpenAIAccount openAI.
   account isAuthenticated ifFalse: [ Error signal: 'Log in before opening the chat. See README.md.' ].
   provider := SmallGPTalkOpenAIProvider account: account.
   provider models.
   agent := SmallGPTalkAgent named: 'SmallGPTalk'.
   agent instructions: 'You are SmallGPTalk, a Smalltalk agent running in Pharo.
Use evaluate to inspect objects, browse code, create classes, compile methods, and run tests in the current image.
Read class comments, method source, tests, and examples to learn Pharo APIs.
Check the available methods before you use them.
Your implementation is in the SmallGPTalk packages. Inspect your own classes and tests to understand how you work.'.
   session := agent newSessionWith: provider defaultModel.
   session tools: { SmallGPTalkEvaluate new }.
   UIManager default defer: [
    [ (SmallGPTalkChat forSession: session provider: provider) open ]
     on: Error do: [ :error | UIManager default inform: error messageText ] ]
  ] on: Error do: [ :error |
   | message |
   message := error messageText.
   UIManager default defer: [ UIManager default inform: message ] ]
 ] fork ]
