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
