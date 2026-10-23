# Native installed-package smoke (manual only)

This check downloads **the existing public `v1.3.23-test.1` Windows ZIP / macOS Universal ZIP**, pins their exact SHA256 and byte length, and runs the included Windows `MountainStill.exe` or macOS `Contents/MacOS/山隐 · Mountain Still` executable. It does not export a new game, substitute an editor/engine, modify packaged scripts, or publish a release.

The workflow is `workflow_dispatch` only, on standard `windows-2025`, `macos-15` (ARM64), and `macos-15-intel` runners, with `permissions: {}`, anonymous fixed-public-repository fetch, no secrets, actions, caches, or artifact uploads. It is restricted to this public repository. The existing public-repository standard-runner free tier applies; do not change to larger/custom runners. Job timeout is 15 minutes; each executable invocation has a 120-second timeout with process-tree termination on timeout. Runs are serialized by a dedicated concurrency group.

## What is checked

1. Fixed release ZIP hashes and sizes (from the already published/verified release manifest), path traversal/link/device-name and duplicate-path rejection before extraction. macOS executable permissions restored from ZIP attributes; no signature alterations.
2. Real native executable bootstrap reports `UPDATE BOOT: 1.3.23-test.1`, no unexpected error/leak/crash diagnostics, and actual verbose resource loading mentions both `creek_bridge_boss_settle.png` and `creek_bridge_boss_retract.png`. This proves headless resource-load reachability, **not rendered pose appearance or GPU upload**.
3. First real startup reaches its normal ten-second automatic save, using 900 frames at fixed 60 FPS. The save must have schema 4 and at least ten seconds of simulated progression. The test records the actual observed save fields rather than assuming a wall-time wait proves a save.
4. An explicit external test fixture changes only selected legal fields in that newly game-created save (resources, tactic, manual meditation), not package code. The second real startup must retain those choices/resources and write at least ten further simulated seconds, with an atomic backup file. Corrupt-save recovery is rejected.
5. Both processes return zero through Godot's frame-limited engine exit; timeout/nonzero/error output fails the job. This is **not the in-game close button / save-guard path**, which is separately covered by source lifecycle tests.

## Disposable default user directory, not a simulated Linux HOME

The installed project uses the real default Godot user directory named `山隐 · Mountain Still`:

- Windows: `%APPDATA%/Godot/app_userdata/山隐 · Mountain Still`
- macOS: `~/Library/Application Support/Godot/app_userdata/山隐 · Mountain Still`

The driver refuses execution unless running in official GitHub-hosted CI for this repository. It prints the actual OS path. **If that leaf exists, it aborts before reading, launching, or deleting it.** It creates a new leaf with an ownership marker; cleanup requires the matching marker and never removes an ancestor. Do not run this workflow on self-hosted machines or personal save directories. No `HOME`/XDG spoofing or unverified `override.cfg` assumptions.

A normal `updates/preferences.cfg` in this job-owned leaf disables automatic network checks; installed-package testing does not need a live updater request. No game assets/scripts are overwritten. The default user directory is removed only after the native process exits and the ownership check passes. Logs and Actions summaries are the evidence; no artifact storage is used.

## Limits / honest interpretation

This is native **headless installed-package** startup/resource/save smoke, not native GUI, DPI, transparency, keyboard/mouse interaction, graphics correctness, frame-time/performance, Windows signing, macOS Gatekeeper/notarization, or full native updater-chain acceptance. macOS launches the existing app's executable directly; this does not simulate a user's first Finder-open Gatekeeper experience. The release remains unsigned/ad-hoc as documented. Release template `--script` support is not assumed or used.

Offline regression command: `python3 tests/native_package_driver_test.py`. Linux mechanism checks with a separately installed Godot are development-only and never counted as native package success. The three CI jobs must independently finish successfully before reporting native package coverage.

The fresh-directory v1.3.16 package check does not cover an installed v1.3.16 bootstrap with an older active v1.3.15 gameplay PCK, nor does it certify native rate-limit interaction. Those are separate compatibility/service checks.

Earlier v1.3.17 evidence used the published approved B package, not the rejected A candidate. Both textures remain required in actual native loader logs on each boot; archive presence alone does not pass.

The v1.3.18 pins test fresh full-package Service/Timer startup. Its gameplay PCK equals v1.3.17, but full ZIP bytes differ. This double-boot check does not measure GUI cooldown-expiry precision or replace separate timer/interaction evidence.

The v1.3.19 target retains the existing actual-package boot/resource/save gate. New navigation interaction is not exercised: there is no external input or script injection in this headless driver. Navigation source/GUI tests remain separate evidence.

The v1.3.20 target preserves headless boot/resource/save scope. No control-feedback GUI interactions or rendered timing cues are tested; source logic and GUI checks are separate evidence.

The v1.3.21 target retains the same actual-package double-boot/resource/save smoke. Planner pruning behavior and performance are not inferred from boot success; source regression/benchmarks remain separate evidence. Earlier v20 long-run, current-save50 and representative compatibility results are not re-labelled as v21 coverage.

The v1.3.22 target verifies the same fresh actual-package two-boot/resource/save scope. Freed provider lifecycle behavior is exercised by separate source regression, not injected into the installed package. This short headless gate does not certify GUI/provider interaction or inherit earlier long-run/CPU/50-cycle results.

The v1.3.23 target retains the actual-package double-boot/resource/save scope. Dynamic chapter objective interactions are tested separately by source regression, not inferred from headless package startup. Previous native GUI, extended lifecycle and CPU evidence remains version-specific; no failed historical result is replaced.
