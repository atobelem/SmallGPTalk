# Engineering principles audit — 2026-09-11

## Resolution — 2026-09-11

All four follow-up items below are complete at `b9589bc`:

1. `f8b7a6c` preserves the active request settings through automatic compaction.
   The regression failed first, then passed. Send and compact now share run setup.
2. The live check now uses the exact launcher prompt. Evaluation, compaction,
   fork, and continuation passed without a repeated mutation.
3. `b9589bc` adds one verification command and offline CI. HTTP test servers
   use allocated ports. Native checks use separate output directories.
4. `06bdb43` adds a small refresh queue after measuring a burst of text updates.
   It keeps one pending UI task and retains the complete conversation.
   Three queue tests failed first, then passed.

The final check passed 207 tests, source inspection, Core-only loading, four
native checks, and the live example. GitHub Actions also passed. See
[validation](../validation.md) for evidence and measurement limits, and
[verification](verification.md) to repeat the checks.

The remaining sections record the original audit at `4d24a9f`. References to
open work, missing tests, and unmeasured behavior describe that revision.


Audited revision: `4d24a9f` on `main`.

The design generally follows the ten principles in `AGENTS.md`. One defect
was reproduced: automatic compaction can replace the instructions of a request
that is already active. The passing suite does not cover this case. The audit
also identifies limits and follow-up work. It does not recommend another rewrite.
Production source was not changed during this audit.

## Scope and method

The audit covered all 71 Tonel classes, six package declarations, 20 scripts,
the baseline, and the project documents. It read implementations and tests,
traced collaborations, checked recent commits, ran the offline suite in a clean
image, inspected compiled methods, and loaded Core alone in another clean image.
Three small experiments used test models in a disposable image, without account
access. The experiments are described below so they can be repeated.

The first five principles concern the development process as well as code.
Commit history and recorded experiments are evidence for them. Class counts,
short methods, or passing tests alone cannot prove compliance.

## Confirmed defect

### F1 — P2: compaction changes an active request's instructions

Location: `SmallGPTalkSession>>prepareContextFor:during:`,
[src/SmallGPTalk-Core/SmallGPTalkSession.class.st](../src/SmallGPTalk-Core/SmallGPTalkSession.class.st),
lines 152–160.

`send:` creates a request that copies the agent name and instructions. If an
automatic summary is needed, `prepareContextFor:during:` later builds another
request from the live agent. An agent edit during the summary therefore changes
the current request. Without compaction, the same edit affects only future
requests. This makes the request contract depend on whether compaction ran.

The existing `SmallGPTalkSessionTest>>testAgentChangesApplyOnlyToFutureRequests`
checks sequential requests. It does not edit the agent during a summary.

Reproduction in a loaded test image:

```smalltalk
| model agent session received run |
model := SmallGPTalkCompactionTest new
    answerWith: [ :request | 'Done.' ]; yourself.
agent := SmallGPTalkAgent named: 'Before'.
agent instructions: 'Original instructions'.
session := agent newSessionWith: model.
(session send: 'First') wait.
session context autoCompactLimit: 1.
model answerWith: [ :request |
    request isCompaction
        ifTrue: [ agent instructions: 'Changed instructions'. 'Summary.' ]
        ifFalse: [ received := request. 'Done.' ] ].
run := session send: 'Second'.
run wait.
received instructions. "Observed: Changed instructions"
```

Expected: the active request keeps `Original instructions`; a later send uses
`Changed instructions`. The same reconstruction also rereads the agent name.
The experiment changes the agent inside the test model to control the timing;
a Playground edit during the summary produces the same ordering.

Recommended correction: derive the compacted request from the existing request.
Replace its selected history and summary while retaining its captured settings.
First add a failing regression for an agent edit during automatic compaction.
Also check cancellation, the copied context, and the next request's settings.

Principles affected: feedback, experimentation, information hiding, and loose
coupling. Request identity should not depend on later changes to its agent.

## Results for all ten principles

| Principle | Assessment | Evidence and next action |
| --- | --- | --- |
| 1. Iteration | Supported by recent history | Reply adaptation, turn execution, process supervision, feature removal, and test cleanup are separate commits. Each has a validation record. Continue with one correction for F1. |
| 2. Feedback | Strong local feedback; gaps remain | The 203-test suite takes about one second after loading. Native and live scripts give additional feedback. F1 passed unnoticed. Add its boundary case; make the standard checks easy to run together. |
| 3. Incrementalism | Supported | The recent changes preserve public behavior and have scoped commits. The removal deletes the whole deferred feature. Correct the request reconstruction without redesigning sessions or providers. |
| 4. Empiricism | Supported with explicit limits | Fresh tests, source inspection, a Core-only load, and three controlled experiments were run. Earlier live results remain historical. Default-prompt behavior, real HTTP 401 renewal, and long-stream responsiveness were not newly established. |
| 5. Experimentation | Supported, not universal proof of TDD | `validation.md` distinguishes observed failing tests, later coverage, and test refactors. F1 has a controlled reproducer. Source alone cannot prove that every method was developed through TDD. |
| 6. Modularity | Strong | Core loads and runs without UI, OpenAI, or image-tool classes. Model, transport, store, and tool collaborators are supplied through messages. The standard test package deliberately loads the whole product; individual Core loading remains verified. |
| 7. Cohesion | Generally good | Turn executes the loop; Exchange records outcomes; Supervisor owns worker cleanup; TimeLimit supplies a deadline. Session still coordinates three paths: send, manual compaction, and preparation before a turn. F1 is a concrete reason to improve their shared request handling, not to add a generic framework. |
| 8. Separation of concerns | Strong | Provider encoding and OAuth stay in OpenAI. Opal evaluation and image access stay in Pharo. Rendering and Morphic scrolling stay in UI. Login reuses Run through its outcome protocol. Synchronous observer delivery remains an explicit API constraint. |
| 9. Information hiding and abstraction | Partial | Requests copy text and agent settings; records retain output instead of printing live values again; forks copy records while sharing values deliberately. F1 breaks the captured-settings boundary. Context policy remains a mutable collaborator; avoid changing it during a run unless that behavior is defined. |
| 10. Loose coupling | Generally good | Models use `respondTo:`; tools prepare operations; account storage uses an adapter; views subscribe to sessions. Three internal test reads have documented concurrency purposes. Morphic-specific scrolling is contained in one presenter. Independent selection drafts should remain distinct from the applied session model. |

## Reproduced behavior that is not a new defect

### Synchronous completion observers cannot wait for their own run

Experiment: register `whenFinished:` with a block that signals entry, sends
`wait` to its run, and then signals return. After entry, the return signal was
still absent after 100 ms while the run state was `#completed`. The disposable
observer process was then stopped and normal waiting completed.

`SmallGPTalkRun>>start:whenFinished:` signals completion after cleanup.
`SmallGPTalkSession>>release:` calls the observers as part of cleanup. Such a
callback therefore waits for itself to return. This is a structural dependency,
not a performance measurement.

The README explicitly says not to wait for the same run inside a callback.
This blocking behavior follows that documented limitation. Do not report it as a
new contract violation. A future asynchronous notification design would need
an explicit decision about event order, cleanup, and what `wait` guarantees.
No such redesign is required to fix F1.

### Separate views keep independent model selection drafts

Experiment: open two presenters for one session with the test provider. Apply
`high` in the first, then refresh the second. The applied session effort is
`high`; the second presenter's selection remains `low`.

The README explicitly defines these as independent drafts. This is not a
failed synchronization contract. An optional UI improvement is to display the
applied model and effort separately from the draft, so a reader can see both.
Do not silently discard another view's uncommitted selection.

## Follow-up work and validation gaps

1. Correct F1 with a failing regression and the existing compaction suite.
2. Align a live acceptance check with the standard launcher configuration.
   `scripts/check-live-session.st` uses a longer instruction set, including an
   explicit prohibition on repeated changes. `scripts/open-chat.st` uses the
   user's two-line prompt. Earlier no-repeat results apply to the former
   configuration. Test the latter too before claiming equivalent acceptance.
   This is an evidence gap, not a demonstrated default-prompt failure.
3. Make verification more reproducible. `scripts/test.sh` loads a caller-supplied
   base image and runs SUnit. It does not run source inspection or Core-only
   checks. The repository has no CI workflow. Native checks write to shared
   `.build` paths, and some local HTTP fixtures choose random ports. A small
   documented check sequence, isolated output directories, and allocated ports
   would improve feedback. Do not claim these tests failed in this audit.
4. Profile long streaming replies before changing the UI. Each text event queues
   a refresh, and rendering reparses the selected exchange. There is no measured
   queue or rendering budget here. Coalescing refreshes may help, but no UI hang
   was established by this audit.

Do not merge ContextEstimate and ContextUsage only because some methods match.
They distinguish predicted size from provider measurements. Do not replace
provider JSON dictionaries with a large class hierarchy without a concrete
need. Do not hide live result objects merely to simulate immutability: shared
live values are an explicit part of the Smalltalk API.

## Verification

- Clean Pharo 13: **203 run, 203 passes, 0 failures, 0 errors**.
  Seed: `904249666`. Evidence: `.build/principles-tests.log`.
- Loaded methods: **71 classes, 718 methods, zero undeclared references or
  missing self/super messages**. Evidence: `.build/principles-source.log`.
- Core-only load: named-agent session and independent fork passed.
  Evidence: `.build/principles-core.log`.
- Controlled experiments: observer wait, in-flight instruction change, and
  independent selection drafts produced the results above.
  Evidence: `.build/principles-probes.st` and `.build/principles-probes.log`.

The normal suite does not include F1's reproducer yet. The audit experiments
report observed behavior; a successful experiment process does not mean those
behaviors are all correct. Local logs are ignored by Git. The reproduction
above and the checked-in validation scripts make the important checks repeatable.

The audit did not renew a real login, write Keychain records, perform live model
requests, run a new native screenshot check, test foreign-call cancellation,
or benchmark long streams. Compiled-source inspection cannot validate every
dynamic send. Existing live and native results are recorded in `validation.md`.
The audit also does not certify every sentence against the STE dictionary.

## Source inventory

| Package | Classes read |
| --- | --- |
| BaselineOfSmallGPTalk | `BaselineOfSmallGPTalk` |
| SmallGPTalk-Core | `SmallGPTalkAgent`, `SmallGPTalkCall`, `SmallGPTalkContext`, `SmallGPTalkContextEstimate`, `SmallGPTalkContextUsage`, `SmallGPTalkExchange`, `SmallGPTalkObservers`, `SmallGPTalkProcessSupervisor`, `SmallGPTalkReply`, `SmallGPTalkRequest`, `SmallGPTalkRun`, `SmallGPTalkSession`, `SmallGPTalkTimeLimit`, `SmallGPTalkTurn`, `SmallGPTalkValueReply` |
| SmallGPTalk-OpenAI | `SmallGPTalkAccountAccess`, `SmallGPTalkCallbackServer`, `SmallGPTalkCoreFoundation`, `SmallGPTalkCredentialStore`, `SmallGPTalkHTTPFailure`, `SmallGPTalkKeychain`, `SmallGPTalkLogin`, `SmallGPTalkOAuthCallback`, `SmallGPTalkOAuthRequest`, `SmallGPTalkOAuthTokens`, `SmallGPTalkOpenAIAccount`, `SmallGPTalkOpenAIHTTP`, `SmallGPTalkOpenAIModel`, `SmallGPTalkOpenAIModelDescription`, `SmallGPTalkOpenAIProvider`, `SmallGPTalkOpenAIRequest`, `SmallGPTalkOpenAIResponse`, `SmallGPTalkOpenAIStream`, `SmallGPTalkSecurity`, `SmallGPTalkTLSClient` |
| SmallGPTalk-Pharo | `SmallGPTalkEvaluate`, `SmallGPTalkEvaluation`, `SmallGPTalkImageAccess` |
| SmallGPTalk-Tests | `SmallGPTalkChatTest`, `SmallGPTalkCloseFailingClient`, `SmallGPTalkCompactionTest`, `SmallGPTalkContextEstimateTest`, `SmallGPTalkCredentialStoreTest`, `SmallGPTalkEvaluationTest`, `SmallGPTalkEvaluationsTest`, `SmallGPTalkLoginTest`, `SmallGPTalkMessageTextTest`, `SmallGPTalkModelSelectorTest`, `SmallGPTalkOAuthCallbackTest`, `SmallGPTalkOAuthRequestTest`, `SmallGPTalkOAuthTokensTest`, `SmallGPTalkObservationTest`, `SmallGPTalkOpenAIAccountTest`, `SmallGPTalkOpenAIHTTPTest`, `SmallGPTalkOpenAIProviderTest`, `SmallGPTalkOpenAIRequestTest`, `SmallGPTalkOpenAIResponseTest`, `SmallGPTalkOpenAIStreamTest`, `SmallGPTalkProcessSupervisorTest`, `SmallGPTalkReplyTest`, `SmallGPTalkSessionTest`, `SmallGPTalkTLSTest`, `SmallGPTalkToolLoopTest`, `SmallGPTalkTranscriptTest`, `SmallGPTalkTurnTest` |
| SmallGPTalk-UI | `SmallGPTalkChat`, `SmallGPTalkEvaluations`, `SmallGPTalkMessageText`, `SmallGPTalkModelSelector`, `SmallGPTalkTranscript` |

All package declarations were read. Scripts read:

- `scripts/check-account.st`
- `scripts/check-browser-login.st`
- `scripts/check-chat.st`
- `scripts/check-context-estimate-ui.st`
- `scripts/check-context-estimate.st`
- `scripts/check-core.st`
- `scripts/check-evaluations.st`
- `scripts/check-keychain.st`
- `scripts/check-live-session.st`
- `scripts/check-login-cancellation.st`
- `scripts/check-openai.st`
- `scripts/check-random.st`
- `scripts/check-source.st`
- `scripts/check-stream-view.st`
- `scripts/check-test-order.st`
- `scripts/check-tls.st`
- `scripts/load.st`
- `scripts/open-chat.sh`
- `scripts/open-chat.st`
- `scripts/test.sh`
