# Stone view assertion: wall-clock serialization race

Confirmed 2026-10-22. Only `quality-v1312/tests/test_stone_mechanic_view.gd` changed; no runtime modifications.

`cultivation_state.gd:684` computes saved_at as max(_clock_high_water, int(Time.get_unix_time_from_system())) on every `_snapshot()` call. Comparing full serialized snapshots before/after a read-only view can therefore cross a wall-clock second and fail without state mutation.

Independent reproduction (`reproduce.gd`, `reproduce.log`):
- No scene/view call at all, 1100ms between snapshots: only `saved_at` changed (1792667969 -> 1792667970).
- Real scene held non-processing, 1100ms across snapshot/view/snapshot: only `saved_at` changed (1792667972 -> 1792667973).
- Remove only `saved_at`: full dictionaries equal. Deliberate `qi += 1` sentinel remains unequal. Reproduction exit 0.

Fix: normalize only volatile `saved_at` out of comparison and separately assert actual `_clock_high_water` is unchanged, retaining both pose and all persistent gameplay state checks. No relaxation of gameplay values, RNG, combat timing or other metadata.

Three consecutive actual test runs: 3,239 checks each / 0 failures / exit 0. See fixed-1.log, fixed-2.log, fixed-3.log.

Final test SHA256: 5e3cc1bd150322964204a4caecf2e675592010e25ab2a8d33d57e68b954c932b.

The original single failure log is preserved at `quality-qa/full/test_stone_mechanic_view.log`; it is not relabeled as passed. Runtime full-suite revalidation belongs to the integration agent.
