# Complete source review — 2026-09-10

This review covers all 70 class files: 41 implementation and baseline classes,
and 29 test classes and fixtures. It also covers package declarations, scripts,
and Playground examples. The [file inventory](REVIEW-INVENTORY.tsv) records the
source hashes. Later feature changes require a new review.

## Findings and changes

| Area | Finding | Result |
| --- | --- | --- |
| Core | A failed tool factory could leave a new agent and instructions with old tools. | Create the replacement configuration before changing the session. A regression test checks failure leaves the session unchanged. |
| OpenAI stream | A non-empty terminal response could omit added items or argument fragments, or replace an item identifier. Argument fragments also accepted invalid indices. | Reject inconsistent output before returning a message. Five regression tests cover these cases. |
| Chat | An empty evaluation expression caused the list label to fail. | Use the first line when present and an empty label otherwise. A regression test covers the display operation. |
| Local HTTP tests | The client closed before the test server finished writing. An unhandled ConnectionClosed could end the test process. | A test server records ConnectionClosed. Other errors still propagate. A regression test checks the server remains active. |
| Tool results | Core and image tools repeated the same output truncation. | The result object now owns limitTextTo:. Identity, error flags, marker limits, and image output tests still pass. |
| Test cleanup | Some failed asynchronous tests could leave work or waiter processes behind. | Close test chats, cancel active provider runs, and terminate waiter processes in cleanup. Use a bounded startup wait in the chat cancellation test. |
| Schema tests | Positive tests used shouldnt:raise: Error without checking a result. | Check that validation returns the supplied argument object. |

## Coverage reviewed

| Package | Classes | Checks |
| --- | ---: | --- |
| Baseline | 1 | Package requirements, optional groups, clean load. |
| Core | 11 | Session isolation, conversation identity, resource ownership, cancellation, errors, tool schema and output limits. |
| OpenAI | 15 | OAuth state and PKCE, token renewal, shared coordination, native memory ownership, TLS, request cleanup, stream completion and continuation. |
| Pharo | 6 | Compilation, result identity, execution supervision, image lock, continuous cycles and Stop. |
| Chat | 8 | Model and effort choices, drafts, object menus, browser context, rendering, selection, close and new chat. |
| Tests | 29 | Assertions, fixture behavior, failure paths, asynchronous waits, cleanup and independence from account access. |

## Validation

- The first five new regressions produced four failures and one error before fixes.
- The agent configuration and item identity regressions also failed before fixes.
- The local disconnect reproduction exited with ConnectionClosed before the test server correction.
- All 211 SUnit tests pass in a clean copied Pharo 13 image.
- scripts/check-network-stability.st passed 100 local transport tests across 20 repetitions.
- The default API group loads without Chat or Tests.
- Native object identity, context menu, Inspector, Browser, and Playground checks pass.
- The separate Keychain check passed write, restart recovery, update, and delete with a synthetic record. It did not use the default credential record.
- All shell scripts pass bash -n. git diff --check passes.

The [critic review](CRITIC-REVIEW.tsv) records all 110 remaining entity/rule
observations and why each was retained. These include protocol type checks,
annotation discovery, explicit lifecycle state, size advice, and guarded cleanup.
No rule was disabled. The counts include the baseline and tests.

This review does not prove that all defects are absent. Live OpenAI login and
model requests were not repeated. The earlier live acceptance record remains
in PLAN.md. Foreign calls can delay cancellation. Conversation display entries
retain live objects and grow until the chat closes. Automatic context reduction
was not part of this reviewed version.

Protocol references include the pinned Pi sources in [PROTOCOL.md](PROTOCOL.md),
the [OpenAI streaming guide](https://developers.openai.com/api/docs/guides/streaming-responses),
and the Zinc implementation in the loaded Pharo image. The Zinc documentation
also describes [server setup and cleanup](https://github.com/svenvc/zinc/blob/master/doc/build-and-deploy-1st-webapp/build-deploy-1st-webapp.md).
