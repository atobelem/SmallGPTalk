# Rewrite validation

These results belong to this rewrite, not to the archived implementation.
The rewrite acceptance checks passed. The latest clean Pharo 13 run passed all 207 offline
tests with seed 763305028. The historical cancellation timeout and a separate
completion-signal defect are explained below.

The latest source review is in [review.md](review.md). Counts in the dated
sections below describe those earlier revisions. `.build` files are local
evidence, not versioned artifacts. Logs from the removed rewrite worktree may
no longer be present; their recorded results are historical evidence.

## Recent TDD evidence

| Behavior | Before the change | After the change |
| --- | --- | --- |
| Tool activity in the conversation | 192 tests, one failure and one error | 192 passed; native view checked |
| Occupied login port | 108 tests, one failure | 108 passed |
| Authorization refusal | 110 tests, one failure | 111 passed, including operation integration |
| Compaction within a tool turn | 113 tests, two failures | 115 passed, including cancellation and repeated identifiers |
| Usage for selected context | 116 tests, one failure | 116 passed |
| Cancellation at call start | 117 tests, one failure | 117 passed after implementation and refactor |
| Renewal after HTTP 401 | 119 tests, one failure and one error | 125 passed, including retained tool results and storage failure |
| Chat `/compact` command | 127 tests, two failures | 127 passed |
| Compaction outcome in the chat | 128 tests, one error | 128 passed; native notification check passed |
| View reconnection | 129 tests, one error | 129 passed; old subscription notifications are ignored |
| Cancellation at model request start | 130 tests, one failure | 130 passed; a cancelled summary does not invoke the model |
| Verified model catalog | Two provider tests and one HTTP test failed before implementation | 135 passed, including unavailable default and failed refresh |
| Model selection in the chat | Active-run guard, selector, and chat integration tests failed first | 138 passed; native selector check passed after a rendering fix |
| Summary tool contract | 139 tests, one failure | 139 passed; the original request keeps its tools |
| Native message formatting | Two renderer tests failed before implementation | 142 passed, including no image fetch; native code display inspected |
| Evaluation context and view | Context and view tests failed before implementation | 144 passed; native evaluation window inspected |
| Model selection after view reconnection | 145 tests, one failure | 145 passed; a model without selection metadata clears the old draft |
| Accounts for one credential record | 148 tests, one failure: a second account left the first login active after logout | 150 passed, including logout during renewal and separate adapters for the same record |
| Mid-turn continuation | Live diagnostic repeated the fixture mutation 20 times; encoding and retained-result regressions failed separately | 151 offline tests passed; full live example passed with one mutation after retaining results |
| Authentication header cleanup after a close failure | 152 tests, one failure: the client kept its Authorization header | 152 passed; cleanup runs even when close raises an error |
| Measured context usage | Catalog and UI tests failed first; fork measurement then failed separately | 155 passed, including provider metadata, missing telemetry, and fork context identity |
| Incremental text | Stream and exchange tests failed before implementation | 159 passed after extraction of request supervision; native preview and live stream checks passed |
| Interrupted completion wait | A controlled interruption lost the completion signal: 160 tests, one failure | 161 passed with `Semaphore>>critical:`, including no premature completion when an active wait is interrupted |

Local test logs are in `.build`. Tests use clean copied images, local HTTP
fixtures, and credential-store doubles. Live credentials do not enter fixtures.

## Notification review

Two additional behavior tests passed without a production change. They are
review coverage, not a red-to-green implementation claim.

- `testNotificationsOrderRepliesCallsAndFinalOutcome` records each notification
  while one evaluation fails and the next succeeds. It checks reply commit,
  call start, call result, final reply, terminal state, and completion order.
- `testCancelAfterAResultPublishesCancelledCallsBeforeCompletion` cancels from
  a result observer. It checks that the completed value remains, the next call
  has no operation, only one model request runs, and the terminal notification
  contains the cancelled pending call before completion is reported.

The evidence is `.build/event-order-review.log`. Notifications supply the live
exchange; these tests record state values inside each callback. An observer
that stores only the exchange reference sees its later state when it reads it.
Text fragments now notify observers through the exchange's separate preview.
Completion commits only the validated response. Failure and cancellation clear
the preview and remove its request callback. Tests also cover cancellation from
the preview observer, late fragments, observer failure, and delivery through
the composed HTTP model. Summary requests do not publish previews.

## Separate native and live checks

- `scripts/check-source.st` inspected 61 loaded classes and 614 compiled methods.
  It found no undeclared references or missing self/super messages
  (`.build/compiled-source-audit.log`). This does not check arbitrary dynamic
  sends or prove runtime behavior.
  After the completion-wait fix, it passed again for 61 classes and 616 methods
  (`.build/final-source.log`). The full live-session check also passed again
  in a disposable image (`.build/final-live.log`), with the fixture count one
  after automatic compaction, fork, manual compaction, and continuation.
- The order-check watchdog was exercised with an intentionally blocked model.
  It reported the process stacks and `running` state, then exited with failure
  as expected (`.build/watchdog-self-check.log`). Stack and test descriptions
  are now converted to strings before writing them to `Stdio`; direct object
  printing had exposed an unsupported stream message during the source audit.

- `scripts/check-stream-view.st` passed in native Pharo. It blocked the model
  after a text fragment, checked that the view displayed the preview without
  committing it, then completed the response and checked that the preview label
  disappeared. The screenshot `.build/native-stream.png` was inspected.
  The updated `scripts/check-openai.st` also passed with two preview notifications
  before the final reply (`.build/live-stream-check.log`).

- `scripts/check-core.st` passed in a clean image after loading only
  `SmallGPTalk-Core`. It checked a named agent, session execution, and fork
  continuation with the UI, image tools, and OpenAI classes absent.
  Evidence: `.build/core-only-check.log`.

- `scripts/check-evaluations.st` passed in native Pharo. It checked source,
  printed output, the real value, and the exact originating context. Its
  screenshot was inspected.

- `scripts/check-chat.st` passed with the model selector. Two native windows
  shared a session. Closing one preserved the second window and the completed
  run. The second view also showed the compaction result through its registered
  observer. The generated screenshot was inspected.
  The check applied effort `high` through the selector before sending work.
  The first native attempt exposed a display-block error missed by headless
  tests. It passed after the fix. The script now exits with an error code on
  UI failure and deletes its previous result before running.
- `scripts/check-keychain.st` wrote and updated an invented record, then read
  and deleted it in a separate process. It used a unique `SmallGPTalk.Test.*`
  service. Both phases passed without using the production record.
- `scripts/check-tls.st` accepted the real auth and ChatGPT hosts and rejected
  expired and wrong-host certificates.
- `scripts/check-account.st` retrieved the model catalog using a stored login.
  It now uses the production provider and model-description objects.
  It passed again after shared account coordination was added
  (`.build/shared-account-native.log`), in a new process without saving the image.
  `scripts/check-openai.st` selected the verified default through that provider
  and completed a real response from Pharo. Both updated scripts passed.
  The script now also checks measured usage against the selected model capacity.
  It passed with 31 input tokens and capacity 272000
  (`.build/live-token-usage.log`). The percentage is rounded to a whole number;
  the UI also shows the token count and capacity.
- `scripts/check-live-session.st` passed with `gpt-5.6-luna`, effort `low`, and
  a small character limit. It independently verified one fixture mutation,
  automatic compaction inside the tool turn, fork continuation, manual
  compaction, and continuation with the fixture count still one.
  A later run through `SmallGPTalkOpenAIProvider defaultModel` failed at the
  20-turn limit (`.build/live-acceptance-provider.log`). The earlier success
  does not establish current acceptance. A diagnostic run now records fixture
  count and call failures if the first exchange fails.
  That run confirmed 20 successful calls and a fixture count of 20
  (`.build/live-acceptance-diagnostic.log`). Direct evaluation of the fixture
  succeeded once. The input encoder placed the summary before the original
  request, leaving the request as the last message. A regression test now
  requires a mid-turn summary to follow that request as an assistant message.
  Historical summaries remain before the new user request. Changing only the
  summary position did not fix the live failure (`.build/live-continuation-fixed.log`).
  The loop now also retains the latest complete reply and its tool results
  after mid-turn compaction. A failing test established that the result was
  absent before this change; the passing test also checks its identity in a
  fork. Live verification then passed (`.build/live-retained-tail.log`): one
  fixture mutation, automatic mid-turn compaction, independent fork, manual
  compaction, and continuation with the fixture count still one. It used the
  same default model and effort in a separate disposable image. This verifies
  the example; it does not guarantee that a model can never request a repeated
  operation with a new identifier.
- An earlier `scripts/check-browser-login.st` attempt timed out after 15 minutes
  without a callback. On 2026-09-11, a fresh attempt completed and stored the
  credential in Keychain. That Pharo process exited without saving its image.
  A second process, using a separate clean image copy, ran
  `scripts/check-openai.st` and retrieved the new record. The request completed
  with gpt-5.6-luna and low effort: `Ready.`, two text previews, 31 input tokens,
  and capacity 272000. Evidence: `.build/fresh-login-restart.log`.

The live scripts exit without saving the image. To repeat the native Keychain
check, set `SMALLGPTALK_KEYCHAIN_TEST_SERVICE` to a unique `SmallGPTalk.Test.*`
name and run phases `write` and `read` in separate processes with
`SMALLGPTALK_KEYCHAIN_PHASE`. Do not use the production service for this check.

## Cancellation investigation

The original cancellation test recorded 904.546 seconds and raised
`TestTookTooMuchTime` (seed 515275062). Its report was written at
2026-09-11 01:12:47, local time. The macOS power log records idle sleep at
00:57:40 for 906 seconds, followed by a dark wake at 01:12:46. This places the
long test interval inside host suspension. The timeout is classified as
suspension-related on that evidence; it is not evidence of a reproduced
cancellation deadlock. The two power transitions are retained in
`.build/timeout-power-events.log`.

The original seed replay passed 143 tests. Another check passed 300 login
cancellation cycles. Thirty shuffled full-suite runs then passed 4770 test
executions. These runs did not reproduce the timeout. The diagnostic scripts
remain available and report stacks and run states if execution stalls.

A separate controlled test reproduced a completion-signal defect: terminating
an awakened waiter could consume the signal needed by later waiters.
`SmallGPTalkRun>>wait` now uses Pharo's `Semaphore>>critical:` protocol. The
regression failed before the change and passed after it. A second test confirms
that interrupting an active waiter does not report premature completion. This
fix is independently demonstrated; it is not claimed as the cause of the old
host-suspension timeout.

The test runner now uses `caffeinate -i` when available to prevent idle system
sleep while each Pharo load or test process runs. This temporary assertion ends
with that process. It does not change system preferences or prevent explicit
sleep. The updated runner passed all 161 tests.

## Validation limits

- Verify renewal after HTTP 401 against a live account when that failure occurs.
  Offline tests cover one retry, repeated rejection, other HTTP failures,
  logout, newer credentials, failed storage, and continuation after evaluation.
- OpenAI input estimation uses encoded byte growth and the previous measurement.
  This heuristic is not an exact token count. It can compact or reject early and
  does not guarantee room for all generated output or provider framing.

File tools, shell tools, other providers, MCP, agent teams, and persistent
conversation storage remain outside this version's scope.


## Token compaction update

Four behavior tests first produced three failures and one error (165 tests,
seed 77958470). After the change, all 165 passed. Four further checks covered
model changes, manual summaries, fork, and disabling automatic compaction.
A character-policy selection test then failed (170 tests, one failure).
The final suite passed all 170 tests (seed 255424582); see
`.build/token-compaction-final.log`.
The live-session script now selects the character policy explicitly so that
its small fixture still forces compaction. The token policy is verified with
supplied measurements in offline tests, not a live near-capacity request.


## Continuous improvement update

Five initial behavior tests failed with missing behavior (175 tests, five
errors). After implementation, all 175 passed. Review tests covered UI control,
observer errors, verification failure, stopping during the interval, restart,
and timeout. All 180 then passed.

A fixture-repair test exposed a nested SUnit execution problem. The inherited
test environment cleaned up the controller's processes and blocked termination.
The scoped watchdog captured the stacks in `.build/improvement-diagnostic.log`.
Verification now activates the default execution environment around its
supervised evaluation, so SUnit creates a separate test environment. No global
process-cleanup setting is disabled. The fixture test checks its initial failure,
a method repair through evaluate, and the successful independent test result.

The final clean suite passed 181 tests (seed 227130436). The default verification
expression also ran the complete suite in a separate process; see
`.build/improvement-verification-final.log`. The native controls opened and
stopped execution with a test model; the screenshot is
`.build/improvement-ui.png`. Loaded-source inspection is recorded in
`.build/improvement-source-final.log`.

These checks use a test model and disposable images. Continuous OpenAI-directed
self-modification was not enabled during validation. The mode is now outside the current scope and hidden in the standard chat.
Same-image checks are not protected from agent changes.


## Next-request estimation

Four initial tests produced three failures and one error (185 tests). The
implementation passed those tests; an older telemetry fixture then needed a
1000-token capacity instead of 100 because the new input guard rejected its
encoded request. Its exact input measurement and rounded percentage remain
asserted. A draft UI test failed before its new behavior was added.

The final suite passed 190 tests (seed 904249712). Cases include new-message
growth, UTF-8 size, a completed tool result that triggers compaction, an oversized
result retained on failure, fork, summary and model changes, active-run handling,
and draft updates without network requests. The local guard applies to all
OpenAI requests, including summaries.

A live request passed and recorded 12 input tokens. The next draft estimate was
304 tokens (`.build/context-estimate-live.log`). Native verification displayed
2000 measured tokens and a separate 3068-token draft estimate; screenshot:
`.build/context-estimate-ui.png`. Loaded-source inspection checked 68 classes
and 712 methods with no undeclared references or missing self/super sends.
These are example checks, not evidence that the byte heuristic equals the
provider tokenizer.


## Chat layout update

The existing 190 tests passed after the layout change (seed 658237766). A native
preview used three exchanges, a Smalltalk code block, model selection, context
measurements, and a draft. The screenshot `.build/chat-layout.png` was inspected
for control placement and clipping. History and inspection actions occupy the
left column; the conversation and editor occupy the main area. No font size or
execution behavior was changed.

## Tool activity in the conversation

The renderer shows tool calls in reply order. Tests cover pending, running,
completed, cancelled, and failed calls. The ordered-call test checks source,
output, and the final assistant message. Empty replies retain their calls
without an empty assistant heading. A separate Pharo 13 image rendered three
evaluations in the native chat. The image closed without saving.

Local evidence: `.build/tool-activity-red.log`,
`.build/tool-activity-green.log`, and `.build/tool-activity-preview/preview.png`.

## Conversation scroll

Four Morphic text tests first failed because the transcript presenter was
absent. They passed after the implementation. A composed chat test then failed:
a history refresh moved the reader from pixel 563 to pixel 1876. The fix ignores
transient selection changes during the history refresh. All 197 tests passed.
The checks cover growth at the bottom, a fixed reading position, return to the
bottom, short text that grows, and a different exchange selection.

A separate native window checked follow, preserve, and resume after UI cycles.
It closed without saving. Evidence: `.build/scroll-red.log`,
`.build/scroll-chat.log`, `.build/scroll-final.log`, and
`.build/scroll-native-qlg5w0af/native.log`.

## Full source review on 2026-09-11

The review covered every source file, test, and script. Two UI regressions
first failed in a 199-test run. One showed an unbounded evaluation error instead
of the recorded output. The other kept the previous capacity in the draft
estimate after model selection. Both passed after small UI corrections.
All 199 tests passed with seed 894721347. The final run, after the truncation
notice was clarified, passed all 199 tests with seed 894721354. The loaded-source check inspected
70 classes and 729 methods with zero undeclared references or missing self/super
messages. A separate clean image passed the core-only load and fork check.

Evidence: `.build/review-red.log`, `.build/review-green.log`,
`.build/review-final.log`, `.build/review-source.log`, and `.build/review-core.log`.
The native `check-chat.st` check passed with shared views, model selection,
window close, and compaction status. Its screenshot was inspected.
See [review.md](review.md) for coverage and validation limits.

## Uniform reply protocol

Five initial behavior tests produced one failure and four errors in a 204-test
run. They require reply records for simple text and opaque values, unchanged
public result identity, correct fork records, and text continuation encoding.
All 204 tests passed after adaptation was added. Three review tests also passed:
custom conversion without inheritance, recorded text after the original string
changes, and rejection of opaque values as provider text or summaries.
The final suite passed 207 tests with seed 763305028.

`SmallGPTalkReply from:` owns conversion. Consumers send reply messages instead
of testing for `SmallGPTalkReply`. `SmallGPTalkValueReply` uses the same reply
behavior and overrides the result and text continuation for simple values.
No extension was added to Object or String. This is the first design correction;
loop extraction and process supervision are separate work.

Evidence: `.build/reply-protocol-red.log`, `.build/reply-protocol-green.log`,
`.build/reply-protocol-final.log`. The loaded-source check passed for 72 classes
and 747 methods (`.build/reply-source.log`). The core-only load and fork passed
in a clean image (`.build/reply-core.log`).

The encoding review used the official [function calling guide](https://developers.openai.com/api/docs/guides/function-calling).
Provider output and matching call results remain in the continuation request.

The native chat check passed with two views, model selection, close, and
compaction status; its screenshot was inspected. The separate live session
check passed with gpt-5.6-luna and low effort: one evaluation, automatic
mid-turn compaction, fork, manual compaction, and continuation without another
fixture mutation. Evidence: `.build/reply-native/native.log`,
`.build/native-chat/result.txt`, and `.build/reply-live.log`. Both images exited
without saving.
