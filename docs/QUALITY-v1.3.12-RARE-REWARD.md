# Rare treasure search: deterministic baseline defect and minimal fix

## Reproduction
The integration full-suite failure was a real product defect, not insufficient 12-second test timeout.

- Candidate before fix, same host checkpoint test with reward seeds 0..99: **1789 checks, 1 failure**, exit 1. Only seed12 failed. Search was complete at 2 seconds, phase remained pickup at 12 seconds, `pickup_block_reason=invalid_material`, no reward committed.
- recovery-v1311 baseline with the same host fixture seed12: **7 checks, 1 failure**, exit1, same fully searched blocked corpse.
- Minimal production-State probe on candidate and baseline: both seed12 generated `spirit_jade` with **StringName** key; normal material keys are String. Both complete_stage_search returned invalid_material.
- Before fix candidate and baseline cultivation_state.gd SHA are both bf4d63f255855ca0aa93c83304c692f636e2f7c186fe91e7f0157e74c19f9a88; MaterialLedger identical e77695cc5e25e0ac16b94203edf27288fe0e6b081d45a014bebff96b015fded2.

The normal 1% treasure branch was not exercised in earlier unseeded full suites. When it was exercised, strict ledger validation correctly rejected the incorrectly typed producer key. Reload recreated the same malformed key, so the body remained blocked. Increasing a timeout or freezing to a non-treasure seed would hide the defect.

## Fix and scope
Only two assignments in cultivation_state.gd change: generated and restored reward dictionaries now insert `["spirit_jade"]` (String) rather than `.spirit_jade` (new StringName key). Ledger validation stays strict. Reward probabilities, RNG calls/order, amount, schema, and ABI are unchanged.

Final cultivation_state.gd SHA256: 2d7df34d83bddf03f2c75d791a47b6bd44364d41724fb1d3a9f05b53791ee16d.

Audit found one other material-dot assignment, crafting output refinement_stone. Its key already exists as a String in the trusted recipe definition, so assignment preserves String type. Every recipe and all alternative-material outputs/net-delta key types are now checked; no extra runtime change was needed.

## Focused fixed regression
- `tests/test_treasure_search_state.gd`: **228 checks, 0 failures**, exit0. Covers all 6 stages × 3 corpse slots, generated/restored rare keys, all recipe alternatives, actual pending-corpse save/reload, full jade capacity atomic refusal, freeing exactly one slot then retry, exactly-once reward/checkpoint and unchanged loot RNG, and continued rejection of StringName/unknown ledger keys.
- `tests/test_treasure_search_host.gd`: **19 checks, 0 failures**, exit0. Actual combat/contact damage→approach/search→jade credited→next encounter, fixed seed12.
- Existing `test_looting_crafting_state.gd`: **179 checks, 0 failures**, exit0, including bag/material capacity, retained earned payload and crafting protections; 60000 probability samples unchanged (treasure614).
- Existing `test_battle_resource_host.gd`: **376 checks, 0 failures**, exit0.
- Fixed 0..99 host sweep: **1800 checks, 0 failures**, exit0; same probe/fixtures as failing pre-fix sweep.

Native verification owned by verify_integrated_quality_gui. Its isolated fixture was generated through actual State.save_game, realm4/unarmed/paused/960x540/transparent; adventure seed12 and state -5747927450922496082. Logs/source script are retained here; save copy quality-jade-native-qa/FIXTURE.json. No real user save touched.
