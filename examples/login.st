"Evaluate each section separately in the Playground."

account := SmallGPTalkOpenAIAccount new.
login := account beginLogin.
login authorizationUrl.

"Open the URL in a browser and complete login. Then evaluate this section."
login wait.
login state.

"A new account object uses the record in macOS Keychain."
SmallGPTalkOpenAIAccount new isAuthenticated.

"To sign out, evaluate: account logout."
