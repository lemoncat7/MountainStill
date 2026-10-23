# Fixed-source native headless CPU ABBA

Manual-only, independent diagnostic workflow. A is published v1.3.20 commit
`a0f1ff4e066b1d0697d5918037bfc9902f004d5a`; B is published v1.3.21 commit
`75827e1b51b799194fd8d81e8c52ed7e19adf3bf`. Neither release assets nor production
scripts are modified. Frozen probes are copied into isolated source trees only.
This is not a benchmark of exported release executables.

## Reproduction and isolation

Workflow fetches its exact harness commit and the two fixed public source commits
anonymously, with no token, secret, third-party action, cache or artifact upload.
`permissions: {}` and the public `lemoncat7/MountainStill` job condition are
mandatory. Standard free `windows-2025`, `macos-15` ARM and `macos-15-intel` runners
are fixed. No larger runner, billing or Actions permission changes.

Godot official 4.6.3 ZIPs use the same SHA256 as existing native smoke:
Windows `e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90`;
macOS Universal `30630f3e9b11e10b35c1f90ba8814185dcec43fae1a48345159be7552c64bfe8`.
Downloads are bounded at 256 MiB and expanded engine bytes at 768 MiB. Checksum
verification precedes execution. Two fresh source trees are separately imported.
Each uses a unique real native user-data directory, verified by a Godot probe;
cleanup requires its ownership marker and refuses symlinks.

CI requires **4 GiB initially free**, not a claim that the entire runner uses at
most 4 GiB. No files are deleted to meet this prerequisite. Two source trees are
about 340 MiB combined, imports about 250 MiB locally; actual platform usage can
vary. Local small-script tests may set `--require-free-gib 0` deliberately, while
the workflow always passes 4. Job limit is 15 minutes. The first fetch step records an epoch; the driver
uses a 14-minute deadline from that step (including fetch/download time), or
14 minutes from entry for local runs, leaving completion margin. Each semantic/timing process has a 60-second hard limit. Import
gets 240 seconds each. Insufficient remaining time fails before starting a block.
No samples/trials are reduced to make a run fit.

## Measurement contract

Three fixed cases: bamboo_pass/sword, cloud_slope/unarmed, cloud_slope/fan.
Seed377, mist, boss=true, hero420/11/1, enemy780/8/1, zero guard/dodge probability,
480 simulation ticks at 1/60 per trial. Per scene, fresh processes run **A1-B1-B2-A2**
serially on the same host, each with one warmup and three measured fresh-Duel
trials. Process caches are retained between a block's trials. Across three scenes:
12 blocks, 12 warmups, 36 measured trials. Warmups are retained but not pooled
with measured observations. No other benchmark runs concurrently within a job.

Four raw 480-element microsecond series (advance, pose, rig, tick) and all original
per-trial statistics are retained. Arrays are serialized only after timing.
Nearest-rank percentiles use `ceil(n*p)-1`; p95, peak and total are independently
recomputed by Python. The tick interval is advance+pose+rig; total_ms is the whole
loop including observer bookkeeping, not equal to summed tick samples. Retaining
raw arrays increases memory vs the old summary-only probe, symmetrically A/B.
JSON/hash/file I/O is outside the timed loop. All block/trial/order observations
are printed, not only favourable aggregates. The 33.3ms original budget is a
reported Boolean, not lowered and not used to label formal release acceptance.
ABBA mitigates some order drift but does not remove all noise or imply significance.

## Semantic contract

Before any timing, separate untimed processes collect both cold/warm trials for
each scene/version. `tools/native_cpu_probes/SCHEMA.md` specifies the exact frozen
field list and canonical representation. The driver verifies fixed schema,
probe hashes, complete field list, ordered ticks, complete/per-tick state and
event digests, source provenance and cold/warm equality. Comparisons are within
one OS/host, never across OS. Semantic hashes have **no epsilon tolerance**.
JSON dt metadata alone permits 1e-16 representation error for 1/60; this does not
relax state equivalence. Arbitrary Object internals, module registry internals,
cache bytes and complete engine memory are explicitly outside the schema.

## Output and failure policy

Console logs include all compact raw timing reports, semantic per-tick hashes,
source/probe provenance and every measured trial summary. Job summary lists all
36 observations. A global **10 MiB log budget** reserves completion space; child
output is streamed to a temporary file and monitored, not accumulated unbounded
in a PIPE. Exceeding a budget fails/incompletes the run; it never truncates slow
samples to create a passing result. Large canonical trace binaries are not emitted
or uploaded. Hash reports remain complete. Unexpected diagnostics, missing fields,
nonfinite timings, count/order errors, timeouts and unequal traces fail closed.

Native headless CPU is not GPU, rendered FPS, GUI/input, desktop transparency,
HiDPI, consumer-hardware performance, update-chain or formal 33.3ms certification.
Synthetic fixed combat inputs are not a lawful-player-growth claim. Existing
pacing limitations and prior failed performance evidence remain applicable.
