# Source review — 2026-09-11

The current ten-principle audit is in
[docs/principles-audit.md](docs/principles-audit.md). It identified a request-snapshot defect at revision `4d24a9f`, now corrected
with a regression test. Its resolution section records all follow-up checks.
The sections below are historical.

This review started at `cfa1d90` on `main`. It covers all 70 Tonel classes,
the package declarations, all 22 scripts, and the project documents. The
review read the source and tests, traced the object collaborations, and
checked the loaded methods in a clean Pharo 13 image.

## Coverage

| Area | Classes | Review focus |
| --- | ---: | --- |
| Baseline | 1 | Load order and package dependencies |
| Core | 12 | Session ownership, run supervision, cancellation, observer order, reply commit, call validation, fork copies, compaction, and context estimates |
| OpenAI | 20 | Catalog selection, input encoding, complete stream validation, retained provider data, one 401 renewal attempt, OAuth state and PKCE, callback cleanup, TLS, and native credential storage |
| Pharo | 5 | Explicit evaluate tool, exclusive image access, compiler errors, time limits, recorded output, real values, and retained improvement code |
| UI | 6 | Detached views, subscriptions, model selection, estimates, evaluation inspection, literal tool text, local Markdown, and scroll position |
| Tests and fixtures | 26 | Assertions against behavior, process cleanup, cancellation boundaries, local HTTP fixtures, credential doubles, mutation checks, and UI integration |

The retained improvement classes and tests were read at that revision. They
have since been removed at the user's request. At review time, improvement
was outside the current scope; no live autonomous modification was started.

## Corrections

### Bounded errors in the conversation

`SmallGPTalkMessageText class>>forCall:` used the full error before considering the
operation's recorded output. An error with 1,000 characters bypassed a
32-character output limit while the view reported truncation.

The renderer now uses the operation's recorded output when an operation exists.
The full error remains in the evaluation object. The truncation notice directs
the reader to that object. Calls that fail before preparation still show their
call error. The regression checks the actual evaluation, recorded output,
truncation notice, and bounded displayed text.

### Context estimate after model selection

Applying a model changed the session but did not refresh the draft estimate.
The view could still show the capacity of the previous model until the user
edited the draft or another event refreshed the view.

The apply action now refreshes the local estimate after changing the model.
The regression switches from a 1,000-token catalog model to a 20,000-token model
and checks the new capacity without sending a request or changing history.

### Current documentation

The README and acceptance audit no longer describe the removed rewrite worktree
as the active checkout. They identify `main`, the integration merge, archived
tag, and retained stash. The manual Tonel path uses `SmallGPTalk`.
Historical test counts remain labeled as historical results. Current validation
is separate. The README records the exact launcher prompt, the estimate-based
compaction policy, and the fact that each launch creates a new image.
Instructions for starting deferred improvement were removed from the main guide.

## Validation

- The two new regressions failed before the corrections: 199 run, 197 passes,
  two failures. Evidence: `.build/review-red.log`.
- The corrected suite passed all 199 tests in a fresh copied image. The final
  seed is `894721354`. Evidence: `.build/review-final.log`.
- Loaded-source inspection checked 70 classes and 729 methods. It found zero
  undeclared references or missing self/super messages.
  Evidence: `.build/review-source.log`.
- A separate clean image loaded only Core and completed a named-agent session
  and an independent fork. Evidence: `.build/review-core.log`.
- The native chat check applied model effort, opened two views of one session,
  closed one, retained the other, and displayed completed compaction. Its
  screenshot was inspected. Evidence: `.build/native-chat/result.txt` and
  `.build/native-chat/window.png`.

## Limits and remaining work

This is a complete source review, not proof that all possible defects are absent.
The loaded-source check cannot validate arbitrary dynamic sends. The native
checks use Pharo 13 Morphic on macOS; other UI backends are not supported by the
transcript's scroll implementation.

No new live OAuth, token renewal, or Keychain check was required for these UI
corrections. Earlier live checks remain historical evidence. Renewal after a
real HTTP 401 still needs observation; the offline cases pass. Input estimates
remain a byte-based heuristic, not a tokenizer. Account coordination operates
within one image, not across separate Pharo processes.

Updating an existing running view with new source while retaining its session
remains separate work. The launcher opens a new image. Existing windows retain
their in-memory conversations until they are closed.

Local `.build` evidence is ignored by Git. Older logs can be absent after a
worktree is removed. Use [validation.md](validation.md) for the historical
record and the scripts for repeatable checks.

## Design follow-up: reply protocol

The first design correction removes repeated reply-class checks from the loop,
context, request measurement, fork, UI, and OpenAI model and encoder. One
conversion protocol adapts raw model values. The result remains inspectable by
identity, while conversation entries use a common reply protocol. Five tests
failed before the change; the final suite has 207 passes. See
[validation.md](validation.md#uniform-reply-protocol).

The extractions below address execution in Exchange and process supervision.
Improvement has since been removed. The test cleanup below addresses the
unnecessary internal reads. These follow-ups address the listed design concerns;
passing tests do not prove that all possible defects are absent.

## Design follow-up: turn execution

`SmallGPTalkTurn` now owns the loop. It receives the run, model, tools, and
limits from the session. Exchange retains and validates conversation records.
This separates execution from records without adding provider or UI knowledge.
Two new collaboration tests failed before implementation; all 209 tests now
pass. Core-only, loaded-source, native chat, and live session checks passed.
See [validation.md](validation.md#turn-execution-and-exchange-records).

## Design follow-up: process supervision

Run and TimeLimit now share `SmallGPTalkProcessSupervisor`. The supervisor
owns the worker lifecycle. Its callers supply permission to start and the rule
to continue waiting. Run retains cancellation and outcome handling; TimeLimit
retains the deadline. Five tests failed before extraction, then all 214 passed.
The clean core load, source check, and native chat check also passed.
See [validation.md](validation.md#shared-process-supervision).

## Remove continuous improvement

The feature and its chat connection were removed at the user's request.
Its tests and dedicated scripts were also removed. No optional package remains.
All 203 remaining tests pass. Source inspection and the native chat check pass.
See [validation.md](validation.md#remove-continuous-improvement).

## Design follow-up: test collaborations

Ordinary chat tests use presenter lookup and the existing status protocol.
Tests use direct references to loaded classes. Three internal reads remain
for precise concurrency regressions, with comments that explain their purpose.
No production API was added. The same 203 tests pass, and loaded-source
inspection reports zero issues. See
[validation.md](validation.md#test-collaboration-cleanup).
