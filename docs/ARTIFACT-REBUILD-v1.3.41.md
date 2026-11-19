# v1.3.41 artifact transport alternative — preparation only

2026-11-19: No workflow run, artifact upload, release write, main change, credential expansion, or network-policy change is authorized by this preparation result. Execution remains blocked by unverified storage cost. This branch preserves an executable preparation; it is not a completed release.

## Fixed inputs and behavior

- Original source commit: `121ff2517188a28d3b89cfa6ce9a5faf3ce3d879` (`v1.3.41`), commit epoch `1794641418`.
- Godot `4.6.3.stable.official.7d41c59c4`; Linux archive SHA256 `d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3`.
- Official templates SHA256 `3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8`.
- Workflow pins setup-python and upload-artifact actions to immutable commits, Python 3.12.14, standard `ubuntu-24.04` x64. Runner image and zlib remain environment-dependent; actual versions are recorded. This is not a claim of hermetic or cross-host byte reproducibility.
- The driver downloads only verified official archives, anonymously fetches the fixed source commit into fresh directories, isolates XDG caches, and runs that commit's `build_updater_release.sh` and `package_updater_delivery.py` unchanged. The latter calls `package_source.py`; `package_builds.py` is not the delivery packager used here. Both delivery/source packagers preserve timestamp-sensitive ZIP behavior, including appending documents to Godot's macOS export ZIP.
- Tracked source timestamps are set to the commit epoch before import; tracked contents are checked unchanged afterward. Generated files and output ZIP timestamps are not rewritten. Original frozen files are never inputs to mutation.
- Every new output is compared against the seven original size/SHA records in `tools/v1341_frozen_artifacts.json`. Any mismatch is explicitly a new candidate, not original-byte transport or release acceptance.

## Local verification

Two clean Linux exports completed. Both yielded **0/7 identical files relative to the frozen original**. Across the two new runs only both update PCKs and update JSON matched (3/7); the three ZIPs and checksum list differed (4/7). See [machine-readable evidence](qa/artifact-rebuild-2026-11-19/REPRODUCIBILITY.json) and both run reports in the same folder.

Between the two new runs, all three ZIPs have identical member contents; only metadata differs (source 204 members, Windows 1, macOS 7). Their whole-file ZIP hashes still differ.

Content comparisons against original retained exports:

- Public source ZIP: all 1,389 member contents equal, all member metadata changed.
- Windows content export ZIP: all 395 member payloads equal, same member set.
- Update PCK: all 384 payloads equal, but directory order differs. Thus its whole-file difference is not an outer ZIP timestamp issue.
- Windows delivery ZIP: executable differs; other members equal.
- macOS delivery ZIP: executable, embedded PCK and CodeResources differ; other members equal. This examination does not prove all binary differences are benign.

These checks cover SHA/CRC, source preservation, original structural export validation and member-level comparison. They do not cover native Windows/macOS installation, launch, GUI, sound, input or long mixed workloads. Historical two sword-rhythm assertions remain known failures; this preparation did not rerun gameplay regression. Prior GUI result was inconclusive, Windows used software rendering/Dummy audio, ARM observation covered gathering only. None is promoted into a new native pass.

Four focused safety tests pass: existing-output refusal before download, cached digest rejection before network, duplicate ZIP rejection, and separation of member content from metadata. Workflow YAML safety structure was checked. Independent review recomputed all fourteen new output digests and original seven digests, checked source/tool pins and branch isolation. Its requested job-level disabled gate and retained two-run audit files were incorporated.

Local reproduction (new output directory required):

```sh
python3 tools/rebuild_v1341_artifact.py --workspace /tmp/v1341-new-attempt --cache /tmp/v1341-tools --repetitions 2
python3 -m unittest discover -s tests -p test_v1341_rebuild.py
```

Existing local evidence and candidates remain `/workspace/v1341-repro-20261119/`; the first-run artifact staging directory including both audit trails is 570,857,774 bytes. No upload occurred. Original frozen outputs remain `/workspace/MountainStill/builds/release-v1.3.41/`.

## Cost and execution gates

[GitHub billing documentation](https://docs.github.com/en/billing/concepts/product-billing/github-actions) makes public-repository standard runner compute free, but artifact storage is accounted separately against shared allowances over time. Public visibility, one-day retention, a small upload or later deletion does not prove zero cost.

The existing credential's `GET /users/lemoncat7/settings/billing/usage?year=2026&month=11` returned HTTP 403, `Resource not accessible by integration`. We have no verified shared remaining storage allowance or protective budget evidence. Do not broaden credentials to resolve this. Before any execution, obtain sufficient evidence through existing authorized account access that the full artifact plus concurrent shared usage for its retained lifetime will incur no added cost, or an applicable enforced spending protection. Otherwise leave both gates disabled and do not create the execution branch.

The preparation branch is `ci/v1.3.41-artifact-rebuild`; only a push to **different** branch `ci/v1.3.41-artifact-execute` matches the new workflow. Existing workflows are manual dispatch only. There is deliberately no workflow_dispatch: GitHub requires a manually dispatched workflow to exist on the default branch, and this task forbids changing main. See [GitHub manual-run rules](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).

After cost is independently established, a reviewed future change may remove the literal job-level `false &&` and set `ARTIFACT_STORAGE_ZERO_COST_VERIFIED` to `true`, then push the reviewed preparation commit to the execution branch. These are human-reviewed evidence gates, not automatic account-budget checks. The job also requires the exact public repository, uses `permissions: {}`, fetches public Git data without a token, does no Release writes, has no Actions cache, limits runtime, and uploads only its bounded artifact staging directory. Artifact runtime credentials are provided by Actions without adding repository token scopes.

If later run successfully, obtain the real artifact ID/URL/digest from upload-artifact output or GitHub's run artifacts API. Download through GitHub's supported artifact path, extract and verify each original-file SHA against its new report. Artifact wrapper SHA is not a package SHA. URLs require authorized GitHub access and expire with retention. A different-byte candidate requires renewed target-platform acceptance and separately reviewed native-driver pins; do not silently overwrite original release assets or claim frozen-byte identity.

## Remaining delivery blockers

No new Library ID exists. Official large/multi-file Library prepared helper discovery remains blocked at `https://chatgpt.com/backend-api/wham/apps` by the existing managed proxy policy (previous tunnel HTTP 403). No retry or direct-upload bypass was performed. A GitHub artifact would be an alternate supported transfer only after the storage gate is satisfied; it would contain rebuilt candidates, not the frozen originals.

v1.3.41 remains a prerelease without public attachments; latest official release remains v1.3.40. Actual target-system acceptance and Library persistence remain incomplete. The preparation branch is intentionally not presented as satisfying the user's main/release delivery goal.
