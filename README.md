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
All 231 offline tests passed in a clean Pharo image.
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

The chat uses bold speaker names and separate activity notices.
The conversation scrolls to the latest text when new content arrives.
While text is selected, the view keeps the selection and scroll position.
The model continues to run. Clear the selection to show pending text and resume scrolling.
Assistant replies display fenced code blocks, inline code, and bold text.
Code uses a fixed-width font. This is a small Markdown subset.
Longer backtick delimiters can contain shorter literal backtick sequences.
The display does not change the source sent to the model.
Successful evaluations show a short notice in the conversation.
Select an evaluation in the side panel to read its result or inspect its object.
Errors stay visible in the conversation.

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
Use `session reasoningEffort:` to set the effort through the API.

The window shows response text and tool results as they arrive.
Use **Stop** to cancel a run or browser login.
Keychain operations and model catalog requests must finish before the window becomes ready.
Use **New chat** to open another window without clearing the current conversation.
The new window copies the model and effort choices. You can change them before sending.
Each window has its own conversation. All windows use the same Pharo image and Keychain login.
Only one run with image tools can execute at a time.
Signing out removes the shared login for all windows.
Use **Sign out** to remove the local credential record.
Closing the window cancels an active run or login. It does not sign out.
Conversations stay in memory. Image changes remain after cancellation.

In an image with the `Chat` group loaded, evaluate `SmallGPTalkChat new open`.
The default API load does not include the chat package.
The chat tests use a test provider. They do not access an account or Keychain.

## Use Pharo code context and objects

In the Calypso browser, open the context menu on a class or method.
Select **Ask SmallGPTalk**. A new chat contains the selected definition or method source.
Add your question to the prepared message. Connect and press **Send** when ready.
The context remains visible and editable. Opening the chat does not send code to OpenAI.
If several methods are selected, the action uses the first method.

You can also evaluate:

```smalltalk
SmallGPTalkChat askAbout: SmallGPTalkSession.
SmallGPTalkChat askAbout: SmallGPTalkSession >> #send:onEvent:.
```

The chat places conversation and message input on the left.
The right panel contains evaluations, expression previews, and object actions.
Model and effort controls share a compact row above both panels.

The **Evaluations** list keeps the last 100 successful evaluations in each chat.
Select an expression and press **Inspect evaluation** to open the complete evaluation.
It contains the expression, bounded output, value, and execution context.
Use **Browse result** to browse a returned class or method, or the class of another object.
Use **Copy expression** to copy the Smalltalk source for use in Playground.
These actions do not execute the expression again.
The objects are live references. Later image changes can change their state.
Each conversation entry keeps its object until the chat closes.
The side list shows the last 100 successful evaluations. Earlier results remain in the conversation view.
Closing the chat releases the view entries and result list. Open inspectors can still hold these objects.

Select a message or notice, then open the context menu with a right-click.
Use **Inspect object** to inspect its message, tool call, result, or failure.
During a response, the message is a display draft. A complete response uses the message stored by the session.
Use **Inspect value** in the evaluation context menu to inspect only the returned value.
Use **Open expression in Playground** to edit its source without running it.
Select text and use **Open selection in Playground** to edit a code example.
Select a class name or a reference such as `SmallGPTalkSession >> messages` and use **Browse selection**.
The same menu can inspect the conversation, session, agent, and current run.

The model receives only the bounded text result. Local evaluation results expose
`value`, `expression`, and `context` through `SmallGPTalkEvaluationResult`.
The context records the model, effort, active messages, run, and tool call.
Message and value references remain live objects. The context collection is a snapshot.
The chat package supplies the browser commands. The default API load does not add them.

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
Return a `SmallGPTalkToolResult`.
Implement `newForSession` to create a tool with the same configuration and fresh mutable state.
`executionResources` returns the resources that a run must reserve.
Each resource implements `reserveFor:` and `releaseFor:`.
Image tools use `SmallGPTalkImageAccess` from the Pharo package.
The base class checks required fields, types, allowed values, and extra properties in the input schema.
Providers implement `respondTo:onText:run:` and return a complete `SmallGPTalkMessage` with the assistant role.
The text block receives text fragments. It does not commit conversation entries.

## Agent and session

`SmallGPTalkAgent` holds a name, instructions, and tool prototypes.
`agent newSession` starts an independent conversation configuration.
The new session keeps a reference to its agent and copies its instructions and tools.
Tools create their session instances through `newForSession`.
The agent stores configured prototypes; `agent tools` returns a copy of their collection.
Later changes to the agent apply to new sessions only.
The agent name is a local label. Use instructions to define the model's role.

```smalltalk
agent := SmallGPTalkAgent new
    tools: SmallGPTalkImageTools all;
    yourself.
session := agent newSession
    provider: provider;
    model: 'gpt-5.6-luna';
    reasoningEffort: 'medium';
    yourself.
```

Each session owns its messages, model, reasoning effort, and execution limits.
`SmallGPTalkRun` still owns the execution loop.
New chat windows share the agent definition and create separate sessions.
The core agent has no tools by default. The chat configures it with evaluate.
Existing `session instructions:` and `session tools:` calls override that session only.
Set `session agent:` before the conversation starts.

## Agent identity

The default instructions identify the agent as SmallGPTalk, a Smalltalk assistant in Pharo.
The agent uses the user's language and gives short answers.
It uses the supplied tools, inspects code before changes, and reports validation limits.
The chat always supplies evaluate. API callers select their own tool collection.
Inspect `SmallGPTalkAgent defaultInstructions` to read the complete text.
Use `session instructions:` to replace it before a run.
An existing session keeps its current instructions.

## Image tools and limits

The chat always supplies `evaluate` as its only tool. There is no tool checkbox.
API callers can supply `SmallGPTalkImageTools all`, which returns only evaluate.
The API also accepts an empty collection or caller-defined tools.

`evaluate` accepts Smalltalk in `source`. It returns the result class and bounded text.
Use Smalltalk reflection to search and read code. Use the compiler to change methods.
Use SUnit to run tests. All operations act on the image that runs SmallGPTalk.
The separate search, read, compile, and test tools have been removed.
Their previous implementations remain in Git history.

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

A **conversation** owns the ordered messages and relates tool calls to their results.
A **provider** converts these objects to model requests and complete responses.
A **tool** is an operation that the model can request.
A **run** executes the agent loop for one user message.
See [AGENTS.md](AGENTS.md) for development rules.

## Responsibility boundaries

SmallGPTalkChatConnection coordinates login, catalog access, cancellation, and sign-out.
It reports events. The chat presents those events and opens the authorization URL.
The core run reserves tool resources without knowing about Pharo image locks.
SmallGPTalkImageAccess owns the shared image lock.
The session stores reasoning effort as a string. The OpenAI provider validates its values.

`session conversation` returns a `SmallGPTalkConversation`.
Its `messages` method returns a collection copy with the original message objects.
Use `messageWithCallId:` and `resultWithCallId:` to follow a tool call.
`SmallGPTalkConversationPresenter` owns display entries, text selection, menus, and scrolling.
`SmallGPTalkChatEntry` associates each displayed range with its source object.
Display drafts and local values do not enter provider requests.

`scripts/check-chat-objects.st` is a separate native UI check for a loaded test image.
It uses a test provider and opens the Inspector, Browser, and Playground.
It does not access OpenAI or Keychain. It exits the test image when complete.

Tool call identifiers must be unique in the conversation.
A repeated identifier fails the run before the response is committed or its tools execute.
Resource cleanup attempts each release even if another release fails.
A cleanup failure fails the run, clears the active session run, and emits the terminal event.
`run cleanupErrors` contains the cleanup diagnostics. An earlier run error remains the primary error.

See [the native Pharo review](docs/PHARO-REVIEW.md) for critic results and remaining observations.

## Continuous self-improvement

Connect and select a model and reasoning effort. Press **Improve SmallGPTalk**.
A separate chat starts autonomous improvement cycles with the same model and effort.
Each cycle inspects SmallGPTalk, chooses a small change, modifies code, and runs relevant tests.
It does not request approval between these steps.
The controller starts another cycle after each completed or failed cycle.
Press **Stop**, or close that improvement chat, to cancel it.
Stop also interrupts the pause between cycles. Completed image changes remain.
The controller does not resume automatically after a Pharo process restart.

Each cycle uses a new session with the normal turn limit and a summary of at most 2,000 characters.
The default pause is one second after success and 30 seconds after an error.
A failed cycle does not replay an old request. The next cycle must inspect the current image.
The chat keeps display entries and local result objects in memory until it closes.
Long runs use more memory and consume model usage while active.
Changes apply to the running image. Repository files are not updated by this mode.
The instructions require relevant SUnit checks; they do not guarantee that every model change is correct.
Tests that require a second image run cannot use the image lock held by the active run.

The API controller is `SmallGPTalkSelfImprovement`.
Set `sessionFactory:` to a block that returns a new configured session on each call.
Use `startOnEvent:`, `cancel`, `wait`, `state`, `cycleCount`, and `activeRun` to control it.
`agent forSelfImprovement` creates a separate agent definition with improvement instructions.
See [the continuous improvement example](examples/self-improvement.st).

## Context and compaction

The complete conversation stays in `session messages`.
`session context messages` returns the messages that the model currently uses.
Compaction asks the selected model for a continuation summary. It replaces the
older model context with that summary and keeps the original conversation and
chat entries. The summary can omit details; the original objects remain available.

Enter `/compact` in the chat to compact the current context. This command does not
become a user message in the model conversation. It uses one model turn and no
tools. Stop cancels the request. A failed or cancelled summary request leaves the
previous context in place. A complete summary committed before Stop remains.

Automatic compaction is enabled at a default limit of 60,000 characters.
Before a model turn, it summarizes older turns when the context reaches that
limit. It keeps the current user request and all its tool calls and results together.
If there are no older messages to summarize, it continues with the current turn.
The percentage can exceed 100 percent in that case. Summary requests also count
against the run turn limit. They do not execute or replay image operations.

The UI shows the percentage of this character limit. This is not the model's
exact token usage or maximum token window. The character count includes active
text, tool definitions, arguments, and preserved provider items. Provider items
replace the text count when they already contain that text.

Press **Inspect context** to inspect a snapshot with the model, effort, instructions,
tools, active messages, summary, and limit. For OpenAI, `request` contains the
request body built from the current context. It excludes authorization headers.
This is the context at inspection time, not a record of the last HTTP request.
The conversation context menu can also inspect the context object itself.

```smalltalk
session context inspect.
session context snapshot inspect.
session context autoCompactLimit: 60000.
session context autoCompactLimit: nil. "Disable automatic compaction."
run := session compactOnEvent: [ :event | ].
run wait.
```

Compaction emits `#compactionStarted` and `#compacted` events. The normal run
terminal event still reports completion, failure, or cancellation.
`scripts/check-context-chat.st` checks both compaction modes, retained history,
usage percentage, and inspection with a test provider. It exits the test image.
The context features passed offline and native UI checks. On 2026-09-10,
`scripts/live-compaction.st` passed manual compaction, continuation, and automatic
compaction with `gpt-5.6-luna` at `medium` effort. An independent assertion checked
that a completed image mutation occurred only once. The script uses the saved
account login in a disposable image. It removes its fixture and does not sign out.
See [the context review](docs/CONTEXT-REVIEW.md) for scope and limits.
