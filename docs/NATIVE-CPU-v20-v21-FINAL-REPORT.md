# Fixed v20/v21 native source CPU ABBA — final evidence

## Exact runs and repairs
- Original harness commit a9094d307843f5079700e7d9826596293da98989, run 40012384188: macOS ARM and Intel complete; Windows stopped at frozen probe hash guard before measurements.
- LF checkout repair 9cd7d7dc213d84aafa45e4b4a0b7d537dbeb7ee6, Windows-only run 40013971752: byte hash guard passed, stopped at userdata path guard due to CRLF protocol terminator captured into path. No measurements.
- Protocol parser repair 7078d5f1d4daec178698a6335934bfd63d7227ac, Windows-only run 40014450170: complete. No Mac rerun. Both failed runs retained. No game, benchmark probe, sample count, input, seed, threshold, or safety-gate weakening occurred.

A = published v1.3.20 a0f1ff4e066b1d0697d5918037bfc9902f004d5a. B = published v1.3.21 75827e1b51b799194fd8d81e8c52ed7e19adf3bf. Godot 4.6.3 official pinned platform archives. These are imported source copies, not exported release packages.

## Validated coverage
Each successful platform has six untimed semantic reports (A/B × three scenes, each cold and warm), all 480 ordered per-tick state/event hashes and full digests matching within that OS under the declared schema. Frozen source SHA values were independently checked against Git blobs. Arbitrary object internals and engine memory are not covered by that schema; no cross-OS hash equivalence claim.

Each platform has twelve serial A1-B1-B2-A2 timing blocks, twelve warmups and thirty-six measured trials, each 480 ticks, with four scalar timing arrays: 92,160 raw scalar samples including warmups per platform. All stored samples/statistics/summary rows were independently recomputed and checked. Warmups remain in raw evidence but are excluded from the comparison below. Same-host ABBA mitigates some linear drift; it does not remove all drift. No significance or representative-user-machine claim.

## Observations (all six measured trials per version/scenario)
Maximum tick milliseconds, A → B:

| Platform | bamboo/sword | cloud/unarmed | cloud/fan |
|---|---:|---:|---:|
| Windows | 84.879 → 84.139 | 96.478 → 100.644 | 161.741 → 74.650 |
| macOS ARM | 72.750 → 62.640 | 104.297 → 118.868 | 174.305 → 66.870 |
| macOS Intel | 257.973 → 169.138 | 218.032 → 229.557 | 436.631 → 179.107 |

The unarmed worst peak worsens on all three native platforms. Windows median trial peak worsens 93.0965 → 97.921 ms while total measured loop duration improves 9649.961 → 9302.492 ms. ARM median peak improves 94.5805 → 89.652 ms but total duration worsens 9120.498 → 9846.971 ms. Intel median peak worsens 188.617 → 207.228 ms and total slightly worsens 19629.061 → 19746.807 ms. Different metrics do not support a blanket claim that every aspect regresses or improves.

Fan peak reduction is consistently observed on these three hosts. Windows fan p95 ranges overlap and shift slightly upward (A 6.212–6.267 ms, B 6.259–6.385 ms) despite large peak reduction. Windows sword worst peak is near unchanged, not a broad speedup. Full individual block/trial p95, peak and total values remain in validated JSON and all raw samples remain in original logs, including slow observations.

**33.3 ms remains the unchanged budget and is not satisfied.** Every scenario/version has worst peaks above it. Green CI means measurement and safety/schema checks completed, not performance acceptance. Native headless CPU is not rendered FPS/GPU/UI/HiDPI/actual-package/consumer-hardware validation. Formal release readiness is not established.

Earlier Linux failed tool attempts, both successful Linux ABBA rounds including repeated unarmed regression, and all independent reviews remain in the same Library history. This final native report is evidence, not a production change or a release asset update.
