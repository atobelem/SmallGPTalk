# SmallGPTalk version 1 completion plan

## Outcome and status

Build a minimal Smalltalk API for agents in Pharo 13 on macOS.
Pi Coding Agent remains the main design reference.
Keep conversations in memory and supply image tools through a small protocol.
Preserve ChatGPT account login in macOS Keychain across process restarts.

Version 1 passed all completion checks on 2026-09-09.
The offline suite passed 150 tests with no failures or errors.
The live account integration and the complete API example passed.
An API key is not a substitute for account login.

## Implementation checks

| Stage | Required check | Status |
| --- | --- | --- |
| Clean environment | Load Tonel through Metacello into a clean Pharo 13 image. Run headless SUnit with failure exit codes. | Passed. Verified an arm64 VM and nonzero exit on test failure. |
| Account login | Complete browser login, request model text, restart Pharo, reuse the Keychain record, renew tokens, and sign out. | Passed with native OAuth and the default Keychain record. |
| Agent loop | Test complete responses, ordered tools, invalid inputs, failures, observer errors, cancellation, and turn limits. | Passed in the offline suite. |
| Image tools | Test search, source reads, compilation, evaluation, output limits, and SUnit in disposable fixtures. | Passed in the offline suite and live example. |
| OpenAI provider | Test fragmented streams, incomplete responses, continuation, authentication failures, and no repeated mutations. | Passed offline and with live model requests. |
| Complete API | Run the release example from a fresh load and continue the conversation. | Passed with independent checks of the repaired method. |

Keep live OpenAI and Keychain checks separate from the default suite.
Use a test provider and a credential-store test double for offline tests.
Record the actual test result after execution.
Do not mark a stage complete from source inspection alone.

The native Keychain check passed with a synthetic record under a separate test service.
The first process wrote and read the record.
The second process read, updated, and deleted it, then checked its absence.
A third process checked cleanup.
This check did not use existing credentials and does not prove OpenAI account access.

The live check completed native browser login and recovered its credential record in a new Pharo process.
Model `gpt-5.6-luna` returned `SMALLGPTALK_OK` as streamed text and as the complete run result.
The live example read the fixture, compiled its repair, and reported one passed SUnit test.
Three independent addition checks passed. The fixture test source did not change.
A second message in the same conversation returned a complete reply.
Token renewal passed, and a new account object used the stored credentials to request the model catalog.
Sign-out removed the default SmallGPTalk credential record.
The live check exited with status zero and removed the fixture package.
Native TLS checks rejected expired, self-signed, and wrong-host certificates.

The final offline command was:

```sh
SMALLGPTALK_LOAD_GROUP=Core SMALLGPTALK_WORK_DIR=.build/test SMALLGPTALK_BASE_DIR=.build/base bash scripts/test.sh
```

This also verified relative directory settings and the test script's required `Tests` load group.
Result: 150 tests, 150 passes, zero failures, zero errors.
The separate `bash scripts/keychain-test.sh` check also passed.
The live command was `SMALLGPTALK_MODEL=gpt-5.6-luna bash scripts/live-check.sh`, after browser login.

## Release check

1. Load SmallGPTalk into a clean Pharo 13 image.
2. Start account login from Smalltalk.
3. Complete login in the external browser.
4. Request the account model catalog.
5. Select an explicit model identifier.
6. Ask the agent to inspect a disposable fixture class.
7. Ask the agent to repair its method and run its SUnit tests.
8. Check the changed method with independent assertions.
9. Send a second message in the same conversation.
10. Stop Pharo without saving credentials in a shared image.
11. Start Pharo again and reuse the Keychain record for a model request.
12. Verify token renewal updates the stored record.
13. Sign out and verify that the record is absent.

Record the model identifier, date, image version, and result.
A failed native login remains a release issue. Continue independent offline work while the connection issue is investigated.

## Environment record

The implementation uses the clean archive supplied with Pharo Launcher.

| Component | Selected version |
| --- | --- |
| Image | Pharo 13.1.0SNAPSHOT, revision `e84a2d15c7`. |
| VM | `10.3.9+0.33e04bb60`, arm64, macOS. |
| Archive SHA-256 | `5977dac81cddae745bb4b1747b3047900fbe4d64af10bfef36d01679e1ad5a5f`. |
| Dependencies | Zinc, STON, Opal, SUnit, and threaded FFI from that image. |

The image version uses the Pharo 13 development version name supplied in the archive.
The archive checksum identifies the exact input for validation.

## Deferred work

Defer graphical and terminal interfaces, file and shell tools, other providers, MCP, agent teams, and session storage.
Also defer automatic context reduction, extension discovery, a marketplace, and a built-in planner.
Keep the Smalltalk API, native image tools, and account login as the version 1 boundary.

## Chat extension

The user requested a Pharo chat window after the API release.
The optional `SmallGPTalk-Chat` package uses Spec and the existing public API.
It provides account connection, explicit model selection, optional image tools,
response text, tool results, cancellation, new conversations, and sign-out.
The default API load remains independent of this package.
All 154 offline tests passed in a clean image.
The new tests cover explicit selection, conversation continuation, close cancellation,
and partial text with a failed response.
The existing live provider checks remain separate from chat validation.

## Project name update

The project now uses SmallGPTalk in all source names and text.
The API uses the SmallGPTalk prefix without compatibility aliases.
All 154 offline tests passed before and after the change.
The local credential record was transferred to SmallGPTalk.OpenAI.
The transfer checked the new record before it removed the previous record.
A separate Pharo process used this record for a successful gpt-5.6-luna request.

## Evaluation-only tool collection

The chat now supplies evaluate as its only tool, without a checkbox.
The default image tool collection also contains only evaluate.
Earlier multi-tool checks above describe the previous configuration.
Search, source inspection, compilation, and SUnit execution now use Smalltalk expressions.
The evaluation timeout, output limit, and cancellation rules remain in force.

The chat selects gpt-5.6-luna and medium effort after connection.
Effort choices come from the account model catalog.
The provider sends the selected value in reasoning.effort.
All 157 offline tests passed.
A live request used evaluate to compute 6 * 7 and returned 42.
The revised fixture repair acceptance script has not been run in this configuration.

## Multiple chat windows

New chat opens another window and preserves the previous conversation and draft.
The new window copies the selected model and effort.
Sessions and providers are separate. Windows share the image and stored account login.
The existing image execution lock still permits one active tool run per image.
All 159 offline tests passed. A headless check opened two chat windows successfully.

## Pharo integration

Class and method menus now provide Ask SmallGPTalk.
The action opens an editable context message without sending it.
Successful evaluations retain the local object and expression outside the provider text.
The chat can inspect or browse a result and copy its expression.
Each chat retains at most 100 results and clears them when it closes.
All 164 offline tests passed. A headless UI check opened a context chat, inspector,
and browser, and constructed both menu activations.
Interactive menu placement still needs a visual check in the desktop image.

## Chat layout

The window uses a conversation panel and a separate evaluation panel.
Model and effort controls share a row. Input and transcript areas have labels.
The selected evaluation shows its expression, result class, and text value.
The window was rendered to PNG in a clean test image for visual review.

## Agent definition

SmallGPTalkAgent now owns the name, instructions, and tool prototypes.
Each session copies that configuration and owns its model and reasoning effort.
New chat windows share an agent definition without sharing conversations.
The run loop remains in SmallGPTalkRun.
All 168 offline tests passed, including session isolation and configuration snapshots.

## Responsibility cleanup

The chat delegates account operations to SmallGPTalkChatConnection.
Tools implement newForSession to create configured instances with fresh state.
The core run reserves resources through reserveFor: and releaseFor:.
SmallGPTalkImageAccess owns the image lock in the Pharo package.
OpenAI reasoning values are validated by the provider.
The four unused tools and their dedicated tests were removed.
Evaluation tests cover source inspection, compilation, compiler failure, and SUnit results.
All 165 remaining and new offline tests passed.
Live connection, catalog access, and evaluation with medium effort passed.
The headless context chat, inspector, browser, and menu activation check passed.

## Interactive conversation objects

SmallGPTalkConversation owns committed history and tool call lookup.
The session keeps its existing messages API.
SmallGPTalkConversationPresenter renders selectable entries with live object references.
Context actions inspect messages, calls, results, failures, conversations, agents, and runs.
Selected code opens in Playground without execution. Class and method references open in the browser.
The view binds completed replies to the original session messages.
All 182 offline tests passed.
The native check passed with a test provider, two model turns, and an evaluation.
It checked message identity and opened the Inspector, Browser, and Playground through menu actions.

## Visible Pharo review

A visible Pharo image recovered login and connected to OpenAI.
The review used the Connect and Send buttons with gpt-5.6-luna and medium effort.
The model evaluated OrderedCollection with: 42 and continued the conversation.
The object menus opened the Inspector, Browser, and Playground.
New chat lost its model selection when the window opened. Selection is now restored after opening.
New text could extend an old selection. The view now clears that selection after rendering.
Regression tests cover both fixes. All 184 offline tests passed.
The visible live check and the native scroll check passed after the fixes.

## Code review corrections

Resource release failures now retain diagnostics and permit other resources to be released.
The session is released and one terminal event is emitted with failed state.
Conversation commits reject reused tool call identifiers before tool execution.
A selected conversation keeps its displayed text and position while responses continue.
Clearing the selection displays pending content and resumes automatic scrolling.
All 188 offline tests passed. A visible Pharo check passed for selection and scrolling.

## Literal code rendering review

The renderer could hide a code line that started with backticks.
It now tracks the opening fence length and accepts only a valid closing fence.
Inline code matches the full backtick delimiter and keeps shorter literal sequences.
Unmatched inline delimiters remain visible.
Four new regression cases failed before the fixes. All 193 tests now pass.
A native Pharo render confirmed that literal code remains visible.

## Native critic review

The native critic engine checked classes, methods, and AST nodes, including tests.
The review corrected 77 of 190 entity/rule observations. 113 remain for individual review.
Changes include superclass initialization, inherited variable names, method protocols,
class comments, a complete test tool protocol, and smaller chat event handlers.
All 193 offline tests and the native object interaction check passed.
The repeatable critic script is scripts/critics.st.

## Continuous self-improvement

Improve SmallGPTalk opens a separate chat and starts cycles until Stop or window closure.
Cycles use new sessions and bounded previous-cycle summaries.
Errors pause before another cycle. Stop interrupts active work and pauses.
The feature uses the existing evaluate tool and keeps changes in the current image.
All 200 offline tests passed, including repeated cycles, cancellation, failures, and observer errors.
A live OpenAI check completed two cycles, repaired a fixture, and passed independent SUnit.
The native UI check completed two cycles and stopped through the Stop button.

## Complete review and context features

The complete source review covers 70 class files and the scripts and examples.
See docs/CODE-REVIEW.md for fixes and the 211-test review result.
The local transport suite passed 100 checks across 20 repetitions.
The separate synthetic Keychain check passed across process restarts.

The later context extension adds SmallGPTalkContext and SmallGPTalkCompactionRun.
Manual /compact and automatic compaction preserve the full conversation.
The UI shows the percentage of a configurable character limit and can inspect
active context and the OpenAI request body. It does not claim exact token usage.
Evaluation inspection now opens the expression, output, value, and execution context.
The value alone remains available through the context menu.
All 228 offline tests pass. New regressions were run before implementation.
Native checks cover both compaction modes, percentage, history, and inspectors.
The follow-up review passed all 231 offline tests. Three added checks cover an
empty summary, worker cleanup after timeout, and observer failures.
Live OpenAI manual compaction, continuation, and automatic compaction passed
with gpt-5.6-luna and medium effort. Independent assertions checked that the
fixture mutation ran once. See docs/CONTEXT-REVIEW.md.
