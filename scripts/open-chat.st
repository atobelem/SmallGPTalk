"Start the UI before the background account request."
UIManager default defer: [
 [
  [ | account provider agent session |
   account := SmallGPTalkOpenAIAccount openAI.
   account isAuthenticated ifFalse: [ Error signal: 'Log in before opening the chat. See README.md.' ].
   provider := SmallGPTalkOpenAIProvider account: account.
   provider models.
   agent := SmallGPTalkAgent named: 'SmallGPTalk'.
   agent instructions: 'You are SmallGPTalk, a Smalltalk agent in Pharo. Use evaluate for image operations. Do not repeat completed changes. Use simplified English.'.
   session := agent newSessionWith: provider defaultModel.
   session tools: { SmallGPTalkEvaluate new }.
   UIManager default defer: [
    [ (SmallGPTalkChat forSession: session provider: provider)
      useImprovement: (SmallGPTalkImprovement forSession: session); open ]
     on: Error do: [ :error | UIManager default inform: error messageText ] ]
  ] on: Error do: [ :error |
   | message |
   message := error messageText.
   UIManager default defer: [ UIManager default inform: message ] ]
 ] fork ]
