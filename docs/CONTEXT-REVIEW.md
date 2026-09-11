# Context feature review — 2026-09-10

This review extends [the earlier source review](CODE-REVIEW.md). It covers the
context and compaction objects, their session and run integration, OpenAI input
conversion, evaluation metadata, chat actions, and related tests and scripts.
The [inventory](CONTEXT-REVIEW-INVENTORY.tsv) records the reviewed source hashes.
The earlier full-project inventory and critic report remain historical records.

## Responsibilities and behavior

- The conversation keeps complete messages. Context selects the active messages.
- The compaction run uses the normal run lifecycle and does not reserve image tools.
- The run owns cancellation, time limits, model turn counts, and terminal events.
- The provider converts active messages to request items. It does not select which history to remove.
- The chat invokes the session API. It owns display entries and inspector actions.
- Evaluation results keep the value, source, bounded text, and local context references. The local references do not enter the model response text.

Manual compaction retains the history and accepts only a complete non-empty
summary without tool calls. Automatic compaction keeps the current user turn
and its tool calls and results together. The summary commit checks cancellation.
A committed summary remains if cancellation occurs later. Summary requests count
against the same model turn budget. Observer errors do not restart requests.

The review found no additional production defect in these changes. Three added
behavior tests cover rejection of an empty summary, worker cleanup on timeout,
and ordered events when every observer invocation fails. These are review tests
for existing behavior; they were not a new red-green implementation cycle.

## Validation

All 231 offline SUnit tests passed in a clean Pharo 13 image, with zero failures
and errors. The seed was 684507478. Native checks from the implementation pass
for both compaction modes, retained history, percentage, Inspector, Browser,
Playground, and live object identity. Production UI code did not change in this
follow-up review.

The separate scripts/live-compaction.st check passed in a fresh process using
the saved account login. The model was gpt-5.6-luna with medium reasoning effort.
It executed one fixture increment, then completed manual compaction and recalled
a marker in the next request. A forced automatic compaction also preserved the
marker. Independent image assertions checked that the increment occurred once.
The script removed its fixture. It did not save credentials in the image or sign
out. This was one live sequence, not a reliability measurement across many runs.

## Limits

The percentage measures a configured character limit, not the model token window.
An active turn can exceed that limit because compaction keeps its calls together.
A generated summary can omit facts. One successful recall check does not prove
that every summary retains all relevant information. Full history stays in memory.
Inspector references are live objects; a snapshot does not freeze those objects.
Foreign calls can delay cancellation.
