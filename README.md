# SmallGPTalk

A minimal Smalltalk agent harness for Pharo 13 on macOS.

This implementation was rebuilt from zero and integrated into `main`.
The previous version remains at tag `archive/pre-restart-2026-09-10`.
The temporary rewrite worktree was removed after integration. The abandoned
local refactor is retained in Git stash. The active checkout is `SmallGPTalk`.

## Design principles

[Pi Coding Agent](https://github.com/earendil-works/pi/tree/main/packages/coding-agent#philosophy)
is the main design reference: a small core, short instructions, and simple tool
protocols. Discover collaborations through executable Smalltalk examples and
TDD. Use composition. Add an abstraction when a behavior needs it.

The session owns execution and conversation history. A view can observe that
session without owning it. A `SmallGPTalkTurn` executes model requests and tools.
Its `SmallGPTalkExchange` records replies, context, and preview text.
Runs and time limits share a process supervisor. Each supplies its stop rule.
Provider details stay outside the core loop.
`evaluate` is the only initial image tool. It gives access to Pharo reflection,
compilation, and SUnit through Smalltalk expressions.

See [AGENTS.md](AGENTS.md) for the ten engineering principles and repository rules.

## Current status

The rewrite has named agents, asynchronous sessions, retained exchanges,
evaluation objects, cancellation, fork, manual and automatic compaction,
context inspection, detachable chat views, and an OpenAI account connection.
Credentials use the macOS login Keychain.

The rewrite acceptance checks passed. On 2026-09-11, a fresh browser login
stored credentials in Keychain. A second Pharo process used that record for a
model request. Live checks also passed evaluation, automatic compaction within
a tool turn, fork, and continuation without a repeated mutation.
The current offline suite has 214 passing tests. See [review.md](review.md)
for the complete source review and its corrections.
See [validation.md](validation.md) for evidence and validation limits.
See [acceptance.md](acceptance.md) for the requirement-by-requirement audit.

## Load and test

Use a clean Pharo 13 image with its matching changes and sources files.
Set `SMALLGPTALK_VM` if the VM is outside the default path in `scripts/test.sh`.

```sh
SMALLGPTALK_BASE_IMAGE=/path/to/Pharo.image bash scripts/test.sh
```

The script copies the image to a new directory in `.build`, loads Tonel through
Metacello, and runs SUnit. Test failures produce a nonzero exit status. Offline
tests do not use an OpenAI account or the Keychain.
When available, `caffeinate` prevents idle system sleep while each Pharo process
runs. The assertion ends with the process and does not change system settings.

For a manual load, replace the path below with this checkout's absolute path:

```smalltalk
Metacello new
    baseline: 'SmallGPTalk';
    repository: 'tonel:///absolute/path/to/SmallGPTalk/src';
    load.
```

The packages are `SmallGPTalk-Core`, `SmallGPTalk-Pharo`, `SmallGPTalk-OpenAI`,
`SmallGPTalk-UI`, and `SmallGPTalk-Tests`. The core has no UI or provider dependency.

## Connect an account

```smalltalk
account := SmallGPTalkOpenAIAccount openAI.
account isAuthenticated.
```

If no login is stored, start a login and open its authorization URL in a browser:

```smalltalk
login := account beginLogin.
login authorizationUrl.
```

Inspect `login state` and `login error` after the browser flow. `login cancel`
cancels the operation. `login wait` returns after cleanup. Do not wait in the UI
process if the window must remain responsive. The login limit is 15 minutes.
An occupied callback port returns a failed login without a usable URL.

The credential record uses service `SmallGPTalk.OpenAI`, account `default`, in
the user login Keychain. Credentials renew before expiry. `account logout`
deletes the record and invalidates its pending login. Native storage failures
are reported explicitly. Tokens are not passed through shell arguments.

Accounts for the same credential record share `SmallGPTalkAccountAccess` in
the image. It coordinates renewal, login commit, and logout. Logout from one
account cancels a login started by another account for that record. It waits
for a renewal that has already started, then deletes the renewed record.
Separate Keychain adapters use service and account as their coordination key.
Custom stores can supply `coordinationKey`; otherwise supply the same store
object to accounts that share credentials. This coordination does not span
separate Pharo processes.

An HTTP 401 model failure permits one credential renewal and one new attempt
with the same request body. A second rejection stops the request. Other HTTP
failures and broken streams are not retried. Completed tool results remain in
the request; the agent loop is not restarted. Renewal must be stored before
the new credentials can be used. A late rejection uses a newer stored token
without renewing it again, and cannot restore a deleted login.

`withHeadersDo:` is the account's request protocol. Its block must send only
one request; it can run twice after HTTP 401. Do not put image operations in
that block. The model adapter only sends its already encoded body there.

An active image can contain temporary token copies. Do not distribute a saved
image that has used credentials. The live check scripts exit without saving.

## Compose an agent and session

The provider reads the account catalog and validates each selection. Its
configured default is `gpt-5.6-luna` with effort `low`. If that pair is not
available, selection fails without choosing a substitute.

```smalltalk
provider := SmallGPTalkOpenAIProvider account: account.
provider models inspect.
model := provider defaultModel.
agent := SmallGPTalkAgent named: 'Ada'.
agent instructions: 'You are Ada, a Smalltalk agent in Pharo.
Use evaluate for image operations. Do not repeat completed changes.'.
session := agent newSessionWith: model.
session tools: { SmallGPTalkEvaluate new }.
run := session send: 'Evaluate 6 factorial and explain the result.'.
```

`send:` returns immediately. From another process, `run wait` returns the run
after completion, failure, or cancellation. Inspect `run state`, `run result`,
and `run error`. A successful OpenAI result is a `SmallGPTalkReply` with text.
More than one process can wait for the same run. Interrupting one waiting
process does not remove the completion signal needed by other waiters.

For an explicit selection, use `provider model: 'gpt-5.6-luna' effort: 'high'`.
Each catalog description answers `identifier` and `efforts`. Call
`provider refreshModels` to read the catalog again. A failed refresh preserves
the last valid descriptions. The low-level model and transport constructors
remain available for explicit composition and tests.

The model protocol is `respondTo:`. The model receives a request object, not
the session. Tests supply this protocol without a framework or live provider.

The history uses one reply protocol. `SmallGPTalkReply from:` adapts model
values at the boundary. A structured reply returns itself from
`asSmallGPTalkReply`. A simple value uses `SmallGPTalkValueReply`, which retains
the original object as its `result`. A string also supplies recorded text;
other values have no display text and cannot be sent as provider text.
Custom values can implement `asSmallGPTalkReply` without inheriting from a
SmallGPTalk class.

Replies answer `text`, `calls`, `context`, `usage`, `characterCount`, and
`result`. The loop validates and records them through these messages. The UI,
context measurement, and fork do not select behavior by reply class.
`run result` and `exchange response` retain their existing meaning: a structured
reply returns that reply, while a simple value returns the original object,
including nil. Fork copies reply records and their contexts. Simple values
remain shared by reference. Recorded string text does not change when the
original string changes.


## Inspect the objects

```smalltalk
session conversation inspect.
run exchange inspect.
run exchange context inspect.
run exchange modelContext inspect.
run exchange calls inspect.
```

For a particular call, `exchange contextForCall: call` returns the request that
produced it. Each complete reply retains that request. Fork maps these contexts
to the copied history and call records, while preserving live values by reference.
The chat's Inspect evaluations button opens a view with source and recorded
output, plus separate inspectors for the value, call, and originating context.
Use Refresh to update that view while its exchange is still active.

An exchange retains its request, replies, calls, state, and error. `context`
is its initial request. `modelContext` is the last selected model request,
including any summary. A call retains its arguments and evaluation operation.
The operation retains source, actual result, bounded output, and failure text.
Inspect `call operation` for the evaluation and `call result` for its live value.

Output is recorded once. Later changes to a result do not change that output.
Truncation sets `truncated` and adds an ellipsis. It does not shorten the real
result object. Compiler and ordinary execution errors are caught without
opening a debugger.

## Execution and limits

One run can be active per session. One run with image tools can hold the image
at a time. Calls execute in order after the complete reply has been validated.
Incomplete provider responses are discarded. Tool errors return to the model.
Completed conversation entries remain after failure.

`run cancel` or `session cancel` stops further work. Committed calls that have
not started receive cancelled results. Model requests, including summary
requests, start under the same lock used to accept cancellation. A request
whose start is refused does not invoke the model.
Completed image changes remain.
Ordinary Smalltalk workers stop before cancellation completes. Foreign calls
can delay termination. Image access has no sandbox or automatic rollback.

| Setting | Default | Configuration |
| --- | --- | --- |
| Tool-loop turns | 20 | `session maxTurns:` |
| Model request | 120 seconds | `session requestTimeoutSeconds:` |
| Evaluation | 10 seconds | `tool timeoutSeconds:` |
| Printed output | 20,000 characters | `tool outputLimit:` |
| Automatic compaction | 80% of model capacity, using estimated input when available | `session context autoCompactPercentage:` |
| Character fallback | 60,000 characters | `session context autoCompactLimit:` |

Configure tools before supplying them to a session. Set both compaction limits
to nil to disable automatic compaction. Set only `autoCompactPercentage:` to nil
to select the character policy. Token percentages must be integers from 1 to 100.

## Fork and compact

```smalltalk
fork := session forkAt: session conversation first.
nextRun := fork send: 'Continue from this point.'.
```

Choose a finished exchange. Fork copies history through that point, including
call and evaluation records. Evaluated values stay shared by reference. Model
and agent collaborators are shared. Later conversation changes are independent.
Fork does not undo image changes or import summaries from later history.

```smalltalk
compaction := session compact.
```

Manual compaction requires an idle session with history. To start it from the
chat, enter `/compact` and press Send. The command invokes
the same session operation as the Compact button and does not add a user
message. If the operation cannot start, the chat keeps the input and shows
the error.

The status line shows when compaction starts and how it ends. A failed
compaction shows its error there, since it does not add a history entry.

Automatic compaction runs before an interaction or between tool turns after
the calls finish. It
replaces selected model input with a summary and keeps the complete history.
Summary requests contain no supplied tools, including before provider encoding.
Creating a summary request does not change the original request's tool list.
Cancelled or invalid summaries do not discard completed evaluations. Used call
identifiers remain recorded after compaction. Summary requests have the model
request timeout and do not count as tool-loop turns.

A summary of the current turn follows its user request in the provider input.
It represents assistant work already performed. A summary of earlier exchanges
precedes the new user request. This distinction keeps current-turn compaction
from presenting the original request as a new instruction after completed work.
The latest complete reply and its tool results also remain in the selected
context after mid-turn compaction. Older replies can be summarized. The latest
tool output is not replaced by summary text, even when it exceeds the configured
character threshold.

When a response supplies token usage and the catalog supplies model capacity,
the usage indicator shows the measured input tokens as a percentage of that
capacity. `exchange modelUsage` returns the measurement for its selected model
request. It retains `inputTokens`, `capacity`, and `percentage`, including in a
fork. It describes the request that produced the response, not an estimate of
the next request after new output and tool results.

If measured usage is unavailable, the indicator explicitly shows selected text
against the character limit. That fallback excludes provider framing and tool
schemas. Missing or invalid optional usage data does not discard a completed
response.

Automatic compaction starts at 80% by default, without rounding the comparison.
For models with `estimateFor:`, it uses the next request estimate. Otherwise it
uses the latest measurement, or the character limit if no measurement exists.
The UI rounds percentages for display. Fork keeps thresholds and measurements.

The OpenAI model estimates the complete encoded request locally, including
instructions, tool schemas, provider data, and recorded tool output. The last
measurement retains its encoded byte count in `inputBytes`. The estimate adds
one token for each additional UTF-8 byte. It does not subtract measured tokens
when the byte count decreases. After a summary or model change, it starts from
the new request's full byte count instead of reusing the old measurement.

This is a conservative byte-based estimate, not a tokenizer or an exact limit.
It can trigger compaction or reject input earlier than necessary. Provider
framing, changed text, output, and reasoning can still affect the actual limit.
The [OpenAI conversation-state guide](https://developers.openai.com/api/docs/guides/conversation-state)
explains the shared input and output window.

The chat shows measured context and Next request estimate on separate lines.
The estimate changes with the draft and the applied model. It describes the request before any
automatic compaction. It is unavailable while a run is active. Estimation does
not send a model request or execute tools. Inspect it from Smalltalk with:

```smalltalk
(session estimateFor: 'Explain 6 factorial.') inspect.
```

Before transport, OpenAI requests at or above the estimated window size fail
locally with an explicit error. This also applies to summary requests and the
request after compaction. A large input that cannot be reduced must be shortened.
Completed tool calls and their results remain in history; they are not replayed
or silently truncated to make the next request fit.

The live-session check explicitly selects the character policy to force
compaction with a small fixture. Separate offline tests cover estimated growth,
Unicode input, tool results, fork, and local rejection. The estimate itself is
also checked with a live response and in the native UI.

## Deferred features

Continuous improvement is outside the current scope. Its classes and offline
checks remain in the repository, but the standard launcher does not create a
controller or show its controls. It is not active in the standard chat.
The historical checks are recorded in [validation.md](validation.md).

File tools, shell tools, other providers, MCP, agent teams, and conversation
storage are also outside this version. Conversations remain in memory.

## Open views and observe

The chat places history and selected-exchange actions in a left column. The
conversation and message editor use the main area. Model and effort selection
stay at the top; Apply selection applies both to future requests. Context usage
and Compact stay together above the message editor. Send and Cancel sit below
that editor.

The conversation labels each tool call Assistant and shows it in order, with
its identifier, state, source, and recorded output or error. Empty assistant replies have no heading.
Tool source and output use literal text. The view does not print the live result
again. Errors from an evaluation use its bounded output too. Inspect evaluations
still opens the evaluation objects. A notice marks truncated output. The full
error stays available in the evaluation inspector.

The conversation follows new activity when the view is at the bottom. Scroll
up to read earlier text without being moved by updates. Return to the bottom
to follow again. Selecting a different exchange starts at its latest text.

To open a new chat from the terminal after login:

```sh
SMALLGPTALK_BASE_IMAGE=/path/to/Pharo.image bash scripts/open-chat.sh
```

The script copies a clean Pharo 13 image and loads the current source. It opens
a chat with the default model, low effort, and evaluate. The account uses the
stored Keychain record. The script saves the loaded image before account use;
it does not save the running chat. Each launch uses a separate image copy.
The launcher does not update an existing window or transfer its conversation.
Keep that window open if you need its in-memory session.

The launcher uses these exact instructions:

```text
You are SmallGPTalk, a Smalltalk agent in Pharo.
Use evaluate to inspect and modify the current Pharo image.
```

```smalltalk
(SmallGPTalkChat forSession: session) open.
(SmallGPTalkChat forSession: session) open.
```

To include model and effort selection, supply the provider:

```smalltalk
(SmallGPTalkChat forSession: session provider: provider) open.
```

The selector lists the supplied catalog descriptions. Select a model and
effort, then press Apply selection. Selection alone does not change the session.
The change applies to future requests and preserves history. An active run
prevents changing the model. Fork windows keep the provider selector.
Read the provider catalog before opening the view to avoid a network wait
while the UI is being built. Each view keeps its own selection before Apply selection;
the session's model is the applied configuration.

Both views use the same session. Closing a view removes its observer and keeps
the run and history. Messages show separate You and Assistant labels. Basic
Markdown emphasis and code blocks become native rich text. Code uses the
standard code font. Each message is rendered separately; its stored source
does not change. The renderer uses the Microdown parser and a local visitor,
not the composer that can load resources or execute script markup.
Images show their labels, external document includes show a placeholder,
and script blocks show their source. Full Markdown tables, clickable links,
and mathematical layout are not implemented. A rendering error falls back
to the original text.

The list follows the latest exchange unless an earlier
exchange is selected. Reconnecting a view clears its selection and status;
queued notifications from its old subscription cannot update the new view.
If the new session's model has no identifier and effort protocol, reconnection
clears the old model selection. Apply selection then has no effect until a new
selection is made.
Inspect context and the usage indicator use the selected
exchange's last model context. Fork from here opens an independent session view.

```smalltalk
observer := session whenFinished: [ :completedRun | completedRun state ].
progress := session whenChanged: [ :exchange | exchange state ].
```

Register observers before sending work. Remove them with
`session removeObserver:`. Observer errors remain in `session observerErrors`.
Callbacks run synchronously outside the session lock. Keep them short; do not
wait for the same run inside a callback. Views defer changes to the UI process.
Progress includes the start of each call, before its operation is prepared.
Notifications supply the live exchange. Copy the state you need inside the
callback if you want a record of that point in time. Text becomes visible
as fragments arrive through `exchange partialText`. The view marks it as
`Assistant (in progress)`. Preview text is not a conversation entry and cannot
execute tools. Completion replaces it with the validated reply. Failure or
cancellation discards it. Summary requests do not publish chat previews.

A streaming model can send fragments with `request receiveText:` during
`respondTo:`. The exchange installs the callback for that request and removes
it when the request stops. Completed requests do not keep a subscription to
the exchange. The OpenAI adapter forwards text and refusal fragments; tool
argument fragments remain private until the complete response is validated.
Call start and run cancellation use the same lock. The notification runs after
that lock is released. An observer can cancel at this point; the call then
becomes cancelled without preparing or executing its operation.

## Protocol references

The protocol reference revision is
`d12cd92e45e308d4af000554292165ef1984253b`:

- [Pi OAuth implementation](https://github.com/earendil-works/pi/blob/d12cd92e45e308d4af000554292165ef1984253b/packages/ai/src/auth/oauth/openai-codex.ts).
- [Pi Codex response implementation](https://github.com/earendil-works/pi/blob/d12cd92e45e308d4af000554292165ef1984253b/packages/ai/src/api/openai-codex-responses.ts).
- [OpenAI streaming guide](https://developers.openai.com/api/docs/guides/streaming-responses).
- [OpenAI conversation state guide](https://developers.openai.com/api/docs/guides/conversation-state).
- [Apple SecItem guidance](https://developer.apple.com/forums/thread/724023).

OAuth uses PKCE S256, native random state, client
`app_EMoamEEZ73f0CkXaXp7hrann`, callback
`http://localhost:1455/auth/callback`, and scopes
`openid profile email offline_access`. The token endpoint is
`https://auth.openai.com/oauth/token`. The listener binds to IPv4 loopback only.
TLS verifies the certificate and exact peer host. Proxy and wildcard-host
support are not implemented. Response streams accept `text/event-stream` and
`application/octet-stream`. Provider output needed for continuation stays in
the reply's separate provider data.
