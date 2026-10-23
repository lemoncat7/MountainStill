# Native headless source smoke

The manually dispatched `Native headless source smoke` workflow tests the exact
selected commit on standard public-repository GitHub runners: Windows 2025 x64,
macOS 15 arm64 and macOS 15 Intel. It is intentionally not triggered on push,
pull request or a schedule. A workflow-wide concurrency group prevents overlapping runs. Only the public `lemoncat7/MountainStill` repository
is permitted. No runtime, version, save schema or bootstrap ABI is changed.

## Security and cost boundary

`permissions: {}`; anonymous fixed-repository Git fetch of `github.sha`; no
checkout/action dependencies, credentials, secrets, cache, artifact storage or
external publication. Only console output and job summaries are retained.
Standard public-repository runners are used, never larger/self-hosted runners.
No billing settings or Actions permissions are changed. Each job is capped at
15 minutes; resource import at 240 seconds; each test at 60 seconds. Timeouts terminate the process tree (Windows taskkill, POSIX process group). Download connection failures receive at most three attempts; checksum mismatches never proceed. Missing
workflow permission is a blocker to report, not permission to expand a token.

Godot **4.6.3 stable** is downloaded from official `godotengine/godot-builds`
release assets and SHA256-checked before extraction or execution:

| Asset | SHA256 |
| --- | --- |
| `Godot_v4.6.3-stable_win64.exe.zip` | `e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90` |
| `Godot_v4.6.3-stable_macos.universal.zip` | `30630f3e9b11e10b35c1f90ba8814185dcec43fae1a48345159be7552c64bfe8` |

## What runs

`tools/native_platform_smoke.py --godot /absolute/path/to/Godot --project .`
copies source to a temporary project (without `.git`/`.godot`/Python caches).
A temporary `override.cfg` sets a UUID custom user-data directory. A real Godot
probe must report exactly the expected native location before tests run:
Windows `%APPDATA%/MountainStillNativeSmoke-UUID`, macOS
`~/Library/Application Support/MountainStillNativeSmoke-UUID` (Linux validation
uses `$XDG_DATA_HOME` or `~/.local/share`). This does **not** assume HOME/XDG
redirects Windows/macOS. Only that unique directory is deleted afterwards.
The checkout and normal game save directory are untouched.

The driver imports source resources and runs cultivation, scene geometry/assets,
stone-recovery contract, chapter-to-practice navigation, practice control contribution, practice-host isolation, shutdown lifecycle, update
policy and update-store tests. A passing exit code, exact success-line pattern
with positive check count, and no unexpected engine error/leak diagnostic are
all required. Currently the expected-error allowlist is empty: these nine
fault-injection tests do not need general `ERROR:` suppression. Missing markers,
timeouts and crashes fail closed. Other test failures do not prevent remaining
selected tests from running; a setup/isolation/import failure stops gameplay checks.

## Explicit limits

This is **native OS headless source** validation, not certification of released
EXE/app binaries, GUI, transparency, DPI/font appearance, GPU/frame performance,
audio playback, signing/notarization/Gatekeeper, or full native update chains.
`update_store_test.gd` uses a Windows manifest fixture even on macOS: it checks
native filesystem handling of that fixture, not macOS update compatibility.
The existing Linux-oriented `bootstrap_process_test.py` is not run here.

Linux driver validation cannot stand in for the three native workflow results.
The existing full-suite `test_encounter_balance` thresholds are outside this
focused smoke set; passing smoke does not erase prior full-suite failures.

Official runner/cost references:
- https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- https://docs.github.com/en/billing/concepts/product-billing/github-actions
- https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable
