# Verification

Use Python 3 and a clean Pharo 13 image with its matching changes and sources.
Set `SMALLGPTALK_VM` to the VM executable if it is outside the default path.

```sh
SMALLGPTALK_BASE_IMAGE=/path/to/Pharo.image python3 scripts/verify.py
```

This command loads the source, runs SUnit, checks compiled methods, loads Core
alone, and measures a burst of transcript updates. Each process has a five-minute
limit. A failed or timed-out check stops the command with a nonzero status.
Logs and image copies go to a new `.build/verify-*` directory on each run.
The printed `image.txt` path identifies the loaded, credential-free test image.
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
