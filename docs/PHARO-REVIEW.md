# Pharo code review

The native Pharo critic engine checked SmallGPTalk classes, methods, and AST nodes.
The check includes test code. Counts group each entity and rule once.

The review reduced 190 observations to 113. All 193 offline tests pass.

Corrections:

- Call the superclass window initialization.
- Rename arguments that hide inherited instance variables.
- Match method protocols to inherited protocols and Pharo conventions.
- Complete the validation fixture tool protocol.
- Add class comments that describe responsibilities.
- Separate chat event handling into smaller methods.

Remaining observations include design advice and checks that need individual review.
For example, type checks at provider boundaries trigger the questionable-message rule.
The remaining list is not a claim that every observation is a runtime failure.

| Observation | Entity/rule pairs |
| --- | ---: |
| Sends "questionable" message | 27 |
| Long methods | 15 |
| Temporaries may be read before written | 14 |
| The cyclomatic complexity is high | 13 |
| String concatenation instead of streams | 6 |
| Uses the result of an add: message | 5 |
| Excessive number of variables | 5 |
| Do not use  `shouldnt: [ ... ] raise: Error`  | 5 |
| Uses do: instead of collect: or select:'s | 4 |
| Unnecessary "= true" | 4 |
| branch nil is useless | 2 |
| Unnecessary assignment or return in block | 2 |
| Move assignment out of unwind blocks | 2 |
| Class not referenced | 2 |
| Uses "(a and: [b]) and: [c]" instead of "a and: [b and: [c]]" | 1 |
| Variable is only assigned a single literal value | 1 |
| Eliminate unnecessary not's | 1 |
| Uses or instead of a searching literal | 1 |
| Returns a boolean and non boolean | 1 |
| Provide a call to super tearDown as the last message in the tearDown method | 1 |
| Assignment inside unwind blocks should be outside. | 1 |

Use `scripts/critics.st` in a loaded test image to repeat the analysis.
It writes tab-separated entity, rule, and description fields to standard output.
The script exits the image when it completes. Use a disposable image.

## Refactoring check — 2026-09-10

This later check includes continuous improvement. The critic counts above belong
to the earlier review.

- Use one method to open a chat and restore its model and effort.
- Use the conversation presenter to browse an evaluation result.
- Remove two private chat methods with no callers.
- Use the existing assistant-entry check in the conversation presenter.
- Separate menu actions, improvement cycles, and improvement cleanup into short methods.
- Use one test helper to create an improvement controller with a test provider.

The refactoring preserves the test assertions and adds no features or classes.
The first baseline run stopped with `ConnectionClosed` in the local HTTP test
server. This occurred before the edits. The unchanged baseline then passed all
200 tests. Both test runs after the edits passed all 200 tests in clean copied
images. The intermittent server error still needs a separate investigation.

Native checks also passed for object identity, context menu actions, the inspector,
the browser, and the Playground. A separate check ran two improvement cycles
and stopped them with the Stop button. The chat then cleared its busy state.
These checks use a test provider. They do not use an OpenAI account or Keychain.

This is the refactoring step of TDD: keep the existing tests green while changing
the code structure. No new failing test was needed for this change.

## Run lifecycle refactoring — 2026-09-10

The run now separates request execution, cleanup, and the final state change.
The state lock still protects the final cancellation check. The run still releases
its session before it sends the terminal event. The completion signal remains
in an ensure block.

A new test checks the existing behavior when both a model request and resource
cleanup fail. The run keeps the request error as its main error. It records the
cleanup error separately, releases the session, and sends one terminal event.
All 201 tests passed before and after this refactoring in clean copied images.
The test was added before the code changes. It passed on the existing code.

## Complete source review

See [the complete review](CODE-REVIEW.md) for the later review of all source and
all test classes, fixes, the 211-test result, and the disposition of each remaining critic.
The earlier counts on this page are historical records.
