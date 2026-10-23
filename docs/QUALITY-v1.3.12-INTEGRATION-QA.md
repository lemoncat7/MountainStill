# v1.3.12-test.1 integrated candidate verification

2026-10-22. NOT published; not first-stable ready. This report describes actual merged quality-v1312 execution, not the sum of tests from three earlier branches. Final-runtime 60-minute real-wall-time soak completed; scope and limitations below.

## Frozen scope

Base mechanic-candidate includes no-reward practice and authoritative stone-state UI. Only the approved round2 patch (SHA d184b138e5193a742f9e676b4c3553a50bd9a8a33a17fa8a587288971de67fa9) was applied, not withdrawn experiments. Additional integrated fixes own native WM quit so existing save/cleanup gates run, and use explicit String material keys for new/restored rare jade rewards. Version 1.3.12-test.1; bootstrap ABI 1 and save schema 4 unchanged. Runtime/config hashes are in runtime-freeze.json; all 64 remained equal across final builds and benchmark. All 255 accepted asset files are byte-identical to the base; 60 runtime scripts remain covered in three export presets.

Final key runtime SHA256:
- geometry: 315cfec357dd06427feddad8d777614bd31701eba3e5a82d18d04faf816d371b
- duel: b94c39545d58c1891af5de9d63a84f82841d71ac8003d5be8327a3061abad3c4
- cultivation: ebf19da98e3218cb4b497d252ade06e99a83bfd36276f2a119bff411262dd729
- state: 2d7df34d83bddf03f2c75d791a47b6bd44364d41724fb1d3a9f05b53791ee16d

## Integrated regression results

98 direct test entries were executed on the final runtime in fresh isolated userdata. Original run: 96 exit0, two nonzero entries. One is the unchanged encounter_balance pair of authored-pacing assertions (sword/summit_gate/gate_sentinel 6.82s vs minimum7s). The other was an independently proven test bug: full serialized snapshots included the wall-clock-generated saved_at. A 1100ms wait with no view call reproduced that difference alone. Only that volatile field was excluded while actual _clock_high_water and all gameplay fields remained checked; deliberate qi+1 mutation remains detectable. Corrected stone test ran three times, each3239 checks/0fail. Its original failed log and proof remain; it is not relabeled as an original pass. Thus final per-entry outcomes: 97 passing, one pre-existing pacing failure, with the explicit targeted test correction provenance.

Additional actual checks (final merged runtime except the explicitly scoped earlier unchanged-duel checks):
- All five sensitivity builds: 1920/1920 complete routes, 5760/5760 fights; 17450 checks/0fail.
- Repeated 180 earned encounters: 10798 complete event digests, reports, elapsed/victory exact-equal to rerun recovery-v1311; both JSON SHA5bc84ef8adf2c7435f4d0036dfea0af1e6db01250c4b3589dac7246f17d33f41.
- Before lifecycle/reward-only repairs, same frozen duel/geometry merge: 72 scenario comparisons, 3540 events +720 sampled poses exact-equal to baseline.
- Cache tests46320+149680 checks/0fail; practice five suites4716/0; earlier integrated 60 repeated trials (before lifecycle-only repair) preserved complete formal snapshots, nodes64→64, one temporary comparison report. Final-runtime five-suite practice results above were rerun after all runtime repairs.
- Shutdown audio and lifecycle regressions: actual default-quit race reproduced before fix; lifecycle11/0 after fix.
- Rare reward defect: fixed seed12 also reproduced on old recovery baseline. Before-fix100-seed scan had one blocked pickup; same scan after fix1800/0. New state228/0 and real host19/0 cover strict ledger, all recipe alternatives,18 reward variants, old pending-corpse save, capacity-blocked atomic retention/retry, no double award and no RNG reroll. Probability/ledger strictness/schema unchanged.

## Independent native GUI and exported artifacts

Linux XFCE/X11 llvmpipe only. Independent real-window tests covered readable960×540/1200×400/1340×720 layouts, dark/light desktop transparency, authoritative stone states, repeated practice pause/finish/compare, saved strategy and explicit route resume. Two post-fix real AltF4 paths and a further three rare-reward-run shutdowns show no ObjectDB/resource leak. Native seed12 actually claimed jade1, quit/reopened with jade1 and retained1/3 checkpoint, explicitly resumed, completed all three fights and natural return, then reopened with jade1/clear1/three reports/empty route; key save sections exact-equal and no duplicate reward. See the two native QA reports. ALSA fallback Dummy means audible sound quality is unverified.

Final actual two-platform exported payload tests passed independently: 334 active resources each, exact runtime/dependency bytes, manifest policy/guard, six older Windows/macOS payloads with twelve boots, non-default strategy/history/save preservation and actual no-reward practice. Both new rare-reward tests also run against each actual PCK. External test-base absolute-path bridge is recorded; tests correctly are not runtime export dependencies. Expected health-failure injections exited1 with the required pause/free behavior; normal runs have no unexpected errors or resource residuals. These are Linux executions of payload content and structure checks, NOT native Windows/macOS GUI execution.

## Serial CPU benchmark — final integrated runtime

Known Godot/GUI/export jobs were stopped. Same shared cloud host (not dedicated hardware), 480 ticks, two warmups and seven trials per scenario, serial before/after. p50/p95 are medians across trial percentiles; maximum is the worst measured tick. All seven final-state dictionaries equal per scenario, and all64 frozen source hashes unchanged. These are CPU logic/pose costs, not rendered FPS.

| Scenario | median total ms before→after | p50 ms | p95 ms | worst tick ms |
|---|---:|---:|---:|---:|
| bamboo sword |2611.646→966.071|3.081→1.471|9.342→3.576|281.373→69.751|
| cloud fan |3662.126→1300.971|3.451→1.920|17.254→4.678|411.465→128.023|
| cloud unarmed |4214.924→1077.395|4.235→1.645|14.913→3.723|658.249→67.808|

Worst128.023ms still FAILS ≤33.3ms first-stable CPU target. No first-stable/performance-ready claim is made.

## Preserved negative evidence / limits

Earlier runs invalidated by a legitimate runtime hash edit are under pre-quit-fix/. Reusing test userdata caused three hot-update assertions; a fresh-userdata same-command HTTP fixture confirmation passed49/0 and final fresh full suite also passed. Two separate-exec fixture attempts could not access the private loopback server and are invalid harness runs, not product outcomes. These logs are retained. pre-jade-fix/ records the real rare-reward defect before repair. stone-clock-proof/ preserves the clock-boundary test failure and minimal correction.

The final-runtime Linux headless soak completed3602.175s/1531cycles/21180checks/0fail/exit0, with64 frozen runtime/config hashes equal before/after. Observed nodes48–64/resources162/orphans0, RSS356.25→368.27MiB (+12.02MiB), last15min slope+0.03444MiB/min; no ERROR/ObjectDB/resource residual. This finite observation is not proof of indefinite leak freedom. See QUALITY-v1.3.12-SOAK.md and raw evidence. Native Windows/macOS high-DPI/audio/transparent interaction and dedicated GPU/frame-time targets remain unverified. The old pacing assertions and previously noted historical rendering limitations are not silently relaxed.
