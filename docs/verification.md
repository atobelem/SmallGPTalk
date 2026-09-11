# Verification

Use Python 3 and a clean Pharo 13 image with its matching changes and sources.
Set `SMALLGPTALK_VM` to the VM executable if it is outside the default path.
The command checks these paths before it creates images.

```sh
SMALLGPTALK_BASE_IMAGE=/path/to/Pharo.image python3 scripts/verify.py
```

This command loads the source, runs SUnit, checks compiled methods, loads Core
alone, and measures a burst of transcript updates. Each process has a five-minute
limit. A failed or timed-out check stops the command with a nonzero status.
Logs and image copies go to a new `.build/verify-*` directory on each run.
Each Pharo check uses its image directory as its working directory. A timeout
stops the process group and reports the log path.
The `image.txt` file in that directory contains the loaded test image path.
The default checks do not put credentials in that image.
The burst check asserts one queued render and complete text. Its timing is
reported for comparison; there is no host-dependent speed threshold.

Add `--native` to check the chat, text preview, context estimate, and evaluation
windows. Each check uses a separate image and output directory. Standalone
native scripts also create unique output directories unless
`SMALLGPTALK_CHECK_DIR` is supplied. Run native checks on macOS with a desktop.

Add `--live` to run the live evaluation, compaction, fork, and continuation
check using the stored login. It uses the exact two-line launcher prompt and
default model and effort. It forces compaction with a small character limit.
Live checks do not save their images. Default checks do not use credentials.

```sh
SMALLGPTALK_BASE_IMAGE=/path/to/Pharo.image python3 scripts/verify.py --native --live
```

The GitHub workflow runs the default command on push and pull requests, without
credentials. It uses an Intel macOS runner and the official Pharo 13 download.
It retains only logs and test reports, not image files. The download follows
the current Pharo 13 image stream; its exact image revision can change. Use a
fixed local base image to repeat a check against the same runtime.

References: [Pharo ZeroConf](https://github.com/pharo-project/pharo-zeroconf)
and [GitHub runner labels](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

## Check the runner

These Python tests need no Pharo image or account. They check configuration
errors, working directories, failure logs, and process cleanup after a timeout.
CI runs them before it downloads Pharo.

```sh
python3 -m unittest discover -s scripts -p 'test_*.py'
```

## Separate login and Keychain checks

The `--live` option uses an existing login. It does not test browser login or
Keychain write and delete operations. Use `scripts/check-browser-login.st` for
a fresh login, then `scripts/check-openai.st` in a separate clean process to
check that the stored login works after a restart. These scripts use the real
account record and exit without saving the image. Before the browser check,
set `SMALLGPTALK_LOGIN_CHECK_DIR` to an existing output directory. Open the URL
from its `authorization-url.txt` file while the check waits for the callback.

For `scripts/check-keychain.st`, set `SMALLGPTALK_KEYCHAIN_TEST_SERVICE` to a
unique `SmallGPTalk.Test.*` name. Set `SMALLGPTALK_KEYCHAIN_PHASE` to `write`,
then `read` in a separate process with the same service. The read phase deletes
the test record. This check uses invented data, not the account record.

## Latest results

The complete check passed on 2026-09-11 at source revision `b9589bc`:

| Check | Result |
| --- | --- |
| SUnit | 207 passes, no failures or errors; seed 323235140 |
| Loaded source | 73 classes, 728 methods; no undeclared references or missing self/super messages |
| Core alone | Named-agent session and independent fork passed |
| Native views | Chat, running preview, context estimate, and evaluation checks passed; screenshots inspected |
| Live session | Evaluation, automatic compaction, fork, manual compaction, and continuation passed with one independently verified mutation |

The live session used `gpt-5.6-luna`, effort `low`, and the exact two-line
launcher prompt. Local logs are in `.build/verify-tqcy5eks/`. They are ignored
by Git and can be removed. [The offline CI run passed](https://github.com/atobelem/SmallGPTalk/actions/runs/34615185876).

The controlled burst retained 25,000 characters. It took 15,448 ms for 1,000
immediate renders and 32 ms for one queued render on the local host. This
measures one burst, not all interactive workloads.

The active-request compaction regression failed before `f8b7a6c` fixed it.
Three refresh queue tests failed before `06bdb43` implemented the queue.
These are observed TDD cycles, not a claim that every test was written first.

Browser login and reuse in a second process passed separately on 2026-09-11.
The native Keychain check also passed write, update, restart read, and delete
with an invented record. The latest complete check did not repeat those steps.

## Validation limits

- Renewal after a real HTTP 401 still needs live observation. Offline tests
  cover renewal, repeated rejection, storage failure, logout, and continuation.
- Loaded-source inspection cannot check every dynamic message send.
- Native view checks cover Pharo 13 Morphic on macOS. Other UI backends are
  not covered by the transcript scroll implementation.
- Foreign calls can delay cancellation. Ordinary Smalltalk execution is tested.
- Input estimates use bytes and prior usage, not an exact tokenizer.
- The live example verifies one run. A model can still request a repeated
  mutation with a new call identifier.

See [README](../README.md) for API contracts and current feature limits.
