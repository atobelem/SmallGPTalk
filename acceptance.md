# Rewrite acceptance audit

This audit uses the rewrite sources and its own test results. A passing unit
suite does not prove that the complete goal is finished. See `validation.md`
for run counts, seeds, failure history, and native checks. The acceptance
run below is historical. The current tree is on `main`, and its full source
review is in [review.md](review.md).

## Requirements and evidence

| Requirement | Evidence inspected | Assessment |
| --- | --- | --- |
| Start from a separate implementation | The rewrite was developed separately and integrated by merge `a73bb62` | The active checkout is now `SmallGPTalk` on `main`. The temporary worktree was removed after integration. |
| Preserve the archived version | Annotated tag `archive/pre-restart-2026-09-10` has object `a8bb17f2cce333e71891447b26ee5ad4698bc8e7` and points to commit `328cbdd9ada1fd84bc998e7e41c0292c87f6dcbb` | Tag verified. The abandoned local refactor is retained in Git stash. |
| Use Smalltalk objects, composition, and TDD | Core sources and the red-to-green records in `validation.md` | Session supplies requests to a model; runs supervise execution; context selects history; tools prepare operations. Review tests added later are identified separately. |
| Keep the core independent of UI and providers | `scripts/check-core.st`, `.build/core-only-check.log`, and the baseline dependencies | Passed in a clean image with only Core loaded. A named agent, session, and independent fork worked without the UI, image-tool, or OpenAI classes. |
| Name agents and inspect sessions and conversations | Agent and Session sources; named-agent, retained-history, and agent-change tests | Covered offline. Requests retain the agent name and instructions selected for that request. |
| Supply evaluate as the only initial tool | Evaluate, Evaluation, Call, and ToolLoop sources and tests | Covered offline. Source, real values, bounded output, and failure text remain inspectable. Tool access is explicit. |
| Execute asynchronously and preserve effects on cancellation | Run, TimeLimit, and ImageAccess sources; Session, Evaluation, and ToolLoop cancellation tests | Ordinary execution and completed results are covered. The historical timeout overlapped a 906-second host suspension. A separate interrupted-wait defect has a failing regression and a verified fix; see validation.md. |
| Fork from a finished point and continue independently | Session, ToolLoop, and Compaction fork tests | Covered offline. Histories and call records are copied. Live values are shared. Active and foreign points are rejected. Fork does not undo image changes. |
| Compact manually and automatically without deleting history | Compaction tests and the live-session script | Covered offline and in the earlier live run, including compaction between tool turns. Failed summaries retain completed work. The token policy update passes offline threshold, fallback, model-change, and fork tests; see validation.md. |
| Inspect context and display usage | Request, Context, Evaluations, Chat, and provider tests; native evaluation view check; `.build/live-token-usage.log` | Originating requests are retained. Measured input tokens use the catalog capacity; fork preserves the association. Missing telemetry uses an explicit character-limit fallback. Live measurement passed with 31 input tokens and capacity 272000. |
| Open and close views without owning execution | Chat and Observation tests; native `check-chat.st` result | Two views share one session. Closing a view removes its subscription. Reconnection rejects old queued notifications. |
| Keep results useful in the native UI | MessageText and Evaluations sources and tests; native screenshots | Code formatting, source, recorded output, real values, and originating context were checked. Full Markdown rendering is not claimed. |
| Show incremental text without committing partial responses | Observation, stream, and composed HTTP tests; native and live stream scripts | Passed. Preview is separate from replies, discarded on failure or cancellation, and replaced at completion. The native screenshot shows the running preview; OpenAI delivered two preview notifications before completion. |
| Use OpenAI with persistent login | OAuth, account, HTTP, TLS, credential-store sources; offline tests; separate live checks | Stored-login catalog and response requests passed. Native Keychain write, update, restart read, and delete passed with invented records. Fresh browser login and a request from a second Pharo process passed on 2026-09-11; see `.build/fresh-login-restart.log`. |
| Complete a real evaluate, fork, compact, and continue example | `scripts/check-live-session.st` and `.build/final-live.log` | Passed again after the completion-wait correction. The fixture changed exactly once through automatic compaction, fork, manual compaction, and continuation. The preceding live failures and attempted fixes remain recorded in `validation.md`. |
| Keep tests independent of credentials | Default test runner, fixture sources, and separate native/live scripts | Offline tests use test models, local HTTP fixtures, and invented records. Live scripts exit without saving the image. |
| Review the loaded code | `scripts/check-source.st`, `.build/reply-source.log`, and `review.md` | The latest check inspected 72 classes and 747 methods. No undeclared references or missing self/super messages. Dynamic sends still require behavior tests. |
| Keep documentation accurate and use simplified English | README, validation record, source comments, and examples | Implementation limits and pending work are explicit. Formal STE dictionary compliance has not been independently certified. |

## Acceptance result

The rewrite acceptance checks passed on 2026-09-11. The final check completed a
fresh browser login and stored the credential in Keychain. That process exited
without saving the image. A second Pharo process used a separate clean image
copy and completed a model request with the new record. It also received
incremental text and measured input usage. These acceptance checks passed at
that revision. Later changes have their own validation records.
See `validation.md` for the historical failures and remaining validation limits.


## Optional continuous improvement

This feature is outside the current scope and hidden in the standard chat.
The controller and UI controls were added after the rewrite acceptance. Offline
checks cover repeated cycles, independent evaluation, cancellation, retained
failures, restart, and fixture repair. Native controls were checked with a test
model. See `validation.md` for evidence and the limits of same-image verification.


## Main integration

The integration retains both the previous main history and the independent
rewrite history in merge `a73bb62`. The resulting source uses the rewrite.
The temporary worktree was removed. The archived tag and the stash retain the
previous work. Continuous improvement remains
hidden and outside the current scope.

The integrated tree passed all 181 tests in a clean Pharo 13 image
(seed 228986182).


## Next-request estimation

The next-request estimate includes encoded input growth and is separate from
measured usage in the UI. Automatic compaction uses it when supplied by the
model. The OpenAI transport is not called when the estimate reaches its window.
At that change, all 190 offline tests passed. Separate live and native checks are recorded in
`validation.md`. The heuristic can reject early and is not an exact token count.
