# Rewrite validation

These results belong to this rewrite, not to the archived implementation.
The rewrite acceptance checks passed. The latest clean Pharo 13 run passed all 170 offline
tests with seed 817845566. The historical cancellation timeout and a separate
completion-signal defect are explained below.

## Recent TDD evidence

| Behavior | Before the change | After the change |
| --- | --- | --- |
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
- Automatic compaction uses the latest measured input tokens at an 80% threshold.
  It cannot count new input or tool output before the next provider measurement.
  Missing measurements use the character fallback.

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
