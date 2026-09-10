# SmallGPTalk

SmallGPTalk is a minimal agent harness in Smalltalk for Pharo 13 on macOS.
An agent harness connects a model, a conversation, and tools.

**Pi Coding Agent is the main design reference.**
SmallGPTalk applies its small core and simple tool protocols to the Pharo image.
It exposes a Smalltalk API. An optional Pharo chat window uses this API.
Documentation, comments, and interface text use simplified English under ASD-STE100.

## Project status

The source contains the agent loop, image tools, OpenAI account login, and a native macOS Keychain store.
Login uses the ChatGPT account flow. It does not require an API key.
Version 1 passed its completion checks on 2026-09-09.
All 157 offline tests passed in a clean Pharo image.
Native login and Keychain recovery in a new process passed.
Model `gpt-5.6-luna` inspected a fixture, repaired its method, and ran its SUnit test.
Independent assertions, conversation continuation, token renewal, and sign-out also passed.
See [PLAN.md](PLAN.md) for the completion checks and validation status.

## Design principles

Pi keeps its core small and adds extra behavior through extensions.
See its [design principles](https://github.com/earendil-works/pi/tree/main/packages/coding-agent#philosophy)
and the [original design account](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/).

Apply these principles to SmallGPTalk:

- Keep the agent loop small and easy to inspect.
- Give each object one clear responsibility.
- Use a few tools with clear inputs and results.
- Keep the default model instructions short.
- Keep provider details outside the agent loop.
- Add a dependency only when it meets a current requirement.

Conversations stay in memory. The caller supplies each tool.
The API release has an optional chat extension. There is no terminal interface.
File tools, shell tools, other providers, MCP, agent teams, and session storage are outside this version.
The external browser and macOS Keychain can show their own windows during login.

## Load and test

Use a Pharo 13 VM and a clean Pharo 13 image archive.
The scripts use the Pharo Launcher archive at `/Applications/PharoLauncher.app/Contents/Resources/images/pharo-stable.zip` by default.
Set `SMALLGPTALK_VM` when the VM is outside `$HOME/Documents/Pharo/vms/130-x64/Pharo.app/Contents/MacOS/Pharo`.

From this repository, run:

```sh
bash scripts/load.sh
bash scripts/test.sh
```

Each script starts from a copy of the base image.
The load script saves the loaded image at `.build/test/SmallGPTalk.image`.
The test script runs the offline SUnit suite and writes JUnit XML.
A failed test gives a nonzero exit status.

| Environment variable | Purpose |
| --- | --- |
| `SMALLGPTALK_VM` | Path to the Pharo VM executable. |
| `SMALLGPTALK_IMAGE_ARCHIVE` | Path to a clean Pharo 13 image ZIP. |
| `SMALLGPTALK_BASE_DIR` | Extracted base image directory. Default: `.build/base`. |
| `SMALLGPTALK_WORK_DIR` | Directory for the disposable work image. Default: `.build/test`. |

Use a new base directory when you select another archive.
Keep personal images outside these directories.
The default suite does not use an OpenAI account or the user Keychain.

To load the packages in an open image, evaluate:

```smalltalk
Metacello new
    baseline: 'SmallGPTalk';
    repository: 'tonel:///absolute/path/to/SmallGPTalk/src';
    load
```

Replace the repository path with the path on your machine.
The baseline groups are `Core`, `OpenAI`, `Pharo`, `default`, `Chat`, and `Tests`.
Zinc, STON, Opal, SUnit, and threaded FFI come from the selected Pharo image.

## Use the chat window

Run `bash scripts/chat.sh` on macOS to open a new development image.
The script loads the optional `Chat` group into a separate image copy.
It does not replace your open image.

1. Press **Connect**.
2. Complete login in the browser if required.
3. Check the selected model and reasoning effort.
4. Enter a message in the lower text area.
5. Press **Send**.

After connection, the chat selects `gpt-5.6-luna` and effort `medium`.
The effort list contains only values from the selected model's account catalog.
If the default model or effort is unavailable, select an available value.
Use `provider reasoningEffort:` to set the effort through the API.

The window shows response text and tool results as they arrive.
Use **Stop** to cancel a run or browser login.
Keychain operations and model catalog requests must finish before the window becomes ready.
Use **New chat** to clear the conversation and change the model or effort.
Use **Sign out** to remove the local credential record.
Closing the window cancels an active run or login. It does not sign out.
Conversations stay in memory. Image changes remain after cancellation.

In an image with the `Chat` group loaded, evaluate `SmallGPTalkChat new open`.
The default API load does not include the chat package.
The chat tests use a test provider. They do not access an account or Keychain.

## Use the Smalltalk API

Start with [the login example](examples/login.st).
It returns an authorization URL for the external browser.
Wait for login before you request the model catalog.
Select an explicit model identifier from that account catalog.

```smalltalk
account := SmallGPTalkOpenAIAccount new.
login := account beginLogin.
login authorizationUrl. "Open this URL in a browser."
login wait.
login state. "Must be #completed before model access."
provider := SmallGPTalkOpenAIProvider account: account.
provider models. "Returns model identifiers from the account catalog."
```

Use [the agent example](examples/agent.st) to inspect code and continue a conversation.
The [live acceptance script](scripts/live-acceptance.st) repairs a fixture method and runs its tests.
The [custom tool example](examples/custom-tool.st) defines a tool without a core change.
The [cancellation example](examples/cancel.st) stops a run through its public API.

Run the live checks with an explicit model from the account catalog:

```sh
bash scripts/login.sh
SMALLGPTALK_MODEL=gpt-5.6-luna bash scripts/live-check.sh
bash scripts/keychain-test.sh
```

The login script stores credentials in Keychain and exits.
The live check starts a new image, repairs a fixture, continues the conversation, and renews credentials.
It checks model access with the renewed credentials.
A successful live check signs out at the end.
The `scripts/live-evaluate.st` check uses gpt-5.6-luna with medium effort.
It checks a real evaluate result and keeps the account signed in.
The separate Keychain test uses a synthetic record and removes it after the check.

| Object | Public messages |
| --- | --- |
| `SmallGPTalkOpenAIAccount` | `beginLogin`, `isAuthenticated`, `logout`. |
| Login operation | `authorizationUrl`, `wait`, `cancel`, `state`, `error`. |
| `SmallGPTalkOpenAIProvider` | `account:`, `models`. |
| `SmallGPTalkSession` | `provider:`, `model:`, `instructions:`, `tools:`, `messages`, `send:onEvent:`. |
| `SmallGPTalkRun` | `state`, `wait`, `cancel`, `result`, `error`, `observerErrors`. |
| `SmallGPTalkImageTools` | `all`. |

`session send: text onEvent: aBlock` starts a background run and returns it immediately.
The observer is set before the run starts.
`run wait` returns the run after it stops.
For a completed run, `run result` is the final assistant message and `run result text` is its text.
A failed or cancelled run has no final result. Inspect `run error`.
Run errors and observer errors are `SmallGPTalkFailure` records.
They expose `exceptionClassName`, `messageText`, and an optional numeric `status`.
They do not retain exception contexts.

Events are dictionaries. Read their type with `event at: #type`.
The types are `#text`, `#toolStarted`, `#toolResult`, and `#finished`.
The run sets its final state before it sends the single `#finished` event.
Observer errors remain in `run observerErrors` and do not repeat completed work.
Keep observer blocks short. They run as part of execution.

Only one run can be active per session.
Only one run with image tools can be active per image.
The loop commits complete model responses and executes tool calls in order.
Tool errors return to the model as results.
A broken response does not commit partial tool calls.
Completed conversation entries remain after a failure.

Custom tools subclass `SmallGPTalkTool`.
Implement `name`, `description`, `inputSchema`, and `execute:context:`.
The execution method receives an argument dictionary and the active run.
Return a `SmallGPTalkToolResult`. Set `requiresImage` to true for access to image state.
The base class checks required fields, types, allowed values, and extra properties in the input schema.
Providers implement `respondTo:onText:run:` and return a complete `SmallGPTalkMessage` with the assistant role.
The text block receives text fragments. It does not commit conversation entries.

## Agent identity

The default instructions identify the agent as SmallGPTalk, a Smalltalk assistant in Pharo.
The agent uses the user's language and gives short answers.
It uses the supplied tools, inspects code before changes, and reports validation limits.
The chat always supplies evaluate. API callers select their own tool collection.
Inspect `SmallGPTalkSession defaultInstructions` to read the complete text.
Use `session instructions:` to replace it before a run.
An existing session keeps its current instructions.

## Image tools and limits

The chat always supplies `evaluate` as its only tool. There is no tool checkbox.
API callers can supply `SmallGPTalkImageTools all`, which returns only evaluate.
The API also accepts an empty collection or caller-defined tools.

`evaluate` accepts Smalltalk in `source`. It returns the result class and bounded text.
Use Smalltalk reflection to search and read code. Use the compiler to change methods.
Use SUnit to run tests. All operations act on the image that runs SmallGPTalk.
The earlier search, read, compile, and test classes remain in source for comparison.
They are not in the default tool collection or the chat.

| Limit | Default | Configuration |
| --- | --- | --- |
| Model turns per run | 20 | `session maxTurns:` |
| Model request | 120 seconds | `session requestTimeoutSeconds:` |
| Tool output | 20,000 characters | `session toolOutputLimit:` and `tool outputLimit:` |
| Image tool execution | 10 seconds | `tool timeoutSeconds:` |
| Login | 15 minutes | `account loginTimeoutSeconds:` |

SUnit code run through evaluate uses the evaluation time limit too.
Output limits add a truncation indicator.
Cancellation stops further model requests and tool starts.
Pending committed calls receive cancelled results.
Ordinary Smalltalk execution stops in its supervised process.
A foreign call can delay cancellation. The run stays in `#cancelling` until execution stops.
Image tools provide no sandbox or automatic rollback. Completed changes remain after cancellation.

## Credentials and project terms

The account stores one credential record in macOS Keychain, under service `SmallGPTalk.OpenAI` and account `default`.
Account objects with the same native service and account share login and renewal coordination in the image.
Token renewal updates that record. `account logout` deletes it.
Sign-out removes the local credential record; it does not revoke the account at OpenAI.
Keychain access errors are explicit. Tokens do not pass through shell arguments.
An active image snapshot can contain temporary token copies. Do not share it.
Release images must contain no credentials.
The HTTPS client checks the server certificate chain and host name before it sends a request.
This version does not support HTTP proxies.
See [the connection record](docs/PROTOCOL.md) for endpoints and reference versions.

A **conversation** is the ordered collection of messages and tool results.
A **provider** converts these objects to model requests and complete responses.
A **tool** is an operation that the model can request.
A **run** executes the agent loop for one user message.
See [AGENTS.md](AGENTS.md) for development rules.
