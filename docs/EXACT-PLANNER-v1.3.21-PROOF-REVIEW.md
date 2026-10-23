# Independent shadow-bound review — 2026-10-23
Reviewer: `/root/prototype_native_geometry_acceleration/review_native_kernel`. Source/result inspection and JSON/hash aggregation only; no Godot/benchmark run.

## Conditional proof
LB0 replaces the original nonnegative residual penalty and travel penalty with +0; LB1 replaces only the residual penalty and retains the actual target travel expression. Both retain original constants, left-associated rounded additions and separate minus5. For finite values without reassociation/FMA, arithmetic monotonicity makes either result <= actual score: contact subtracts5, noncontact does not. A finite bound >= finite incumbent cannot win original strict `<`. Equality, including signed zero, retains the earlier winner and its bits. Excluding ai0/crouch0 preserves the special immediate contact return.

The implemented guards check finite origin/incumbent/bound; LB1 also finite target/first gap. They do NOT validate all provider/geometry inputs. This is not an arbitrary-NaN/external-provider proof. All135 scored observations were finite; this sample has zero exact bound/incumbent ties, so explicit tie/negativezero/nonfinite fixtures remain required.

## Independent counts and evidence
Final counts.json:195 candidates,5fits x39; valid counts31/26/26/26/26=135.
- LB0 qualifies114:58 originally valid,56 originally invalid.
- LB1 adds37 valid candidates beyond LB0.
- Valid union95 (19 per fit) could avoid separate+second measure.
- These savings overlap; do not add114 and95 as independent candidate savings.
- Zero bound violations; zero qualified candidates with would_win=true. Missing scores on invalid firstmeasure records correctly represent original continue.
- baseline.bin and shadow.bin independently hash to8eb5d219b3c422d77867852fab2aeb8e522b9592dd65825c9e3d14631154eea2,480ticks/24events/cloudfan/seed377. Object internals are not fully compared.

All original computations remain executed. record.merge(...,true) now correctly overwrites valid=false; earlier parse/valid-flag artifacts are invalid evidence. Observer creates records/bounds even outside active recording, so timings are not a speedup measurement.

## Decision and remaining conditions
There is a material counted opportunity; the no-opportunity stop condition is not met. This permits further bounded investigation, NOT actual-pruning approval or a performance claim.
Before pruning: audit1024-entry samples and96-entry pixel/deformed caches for output independence despite fill/eviction changes; prove builtin provider methods have no observable mutation/RNG dependence; exclude arbitrary custom providers; inspect `_last_pose` and motion-dependent first-filled source/front/body caches rather than assuming all are pure memoization. Compare isolated baseline/candidate providers and caches. Do not run skipped reference work on live candidate state for verification, as it could restore omitted effects and hide defects. Test ties, first-contact return, all-invalid/all-miss, cold/warm/eviction and multiple scenarios before timing.
No production or release changes approved.

## Follow-on provider/cache source audit (same date)

Read `weapon_fan`, `weapon_sword`, `weapon_unarmed`, base `attack_module`, `character_sidewalk` contact sampling, geometry source preparation, and monster source classification. For these exact builtin scripts, pose_track/geometry_points build local dictionaries/packed arrays and read motion/rig/grip; no selection_count/RNG/action/resource-state mutation was found. selection_count mutation belongs to select_action, not this path. standard_track/basic_track also return fresh dictionaries.

The narrow eligibility guard is non-null `pose_provider` AND `strike_provider`, each with `get_script()` identical to one of the three preloaded builtin Script objects. Do not accept subclasses, matching class names/resource paths alone, or registry fallback resolution for missing providers. `sample_contact_pose` sets contact_authority and bypasses presentation-response callbacks; guard_provider is currently not called on this contact path. If that call graph changes, re-audit rather than widening eligibility by assumption.

`MonsterRig._last_pose` is written in draw(), not source_pose/measure/separate. This geometry call graph only reads it for early defeated presentation. Main-thread synchronous evaluation must remain non-concurrent with renderer changes.

First-filled geometry caches need a structural argument, not the label 'memo': `_compile_source_record` passes enemy motion into body classification and registration. Missing-image fallback can alias `_front_rows` by actual fallback image key across different requested poses. The original behavior must be preserved even if that aliasing is imperfect. In the current fit implementation, `_clearance_sources` still runs fully before candidate enumeration; the first candidate is not pruned; enemy motion is fixed across candidates, and separate changes only visual_offset/body_separation/body_reservation, not source-pose-dependent phase/anatomy/impact fields. These facts support unchanged first-source selection, but cold-cache/missing-art fallback tests must verify it.

_source_records and _front_rows are not the96-entry eviction caches. Pixel/deformed caches have those policies; contact samples have1024. Cached-value recomputation must remain semantically identical under changed fill/eviction order. This audit does not permit live metadata/image/provider mutation, unknown Object-valued motion conversions, or threaded geometry. Side-effect/eviction runtime testing remains unfinished; actual pruning is not approved by source inspection alone.

## Frozen opt-in candidate re-review (2026-10-23 17:50 UTC)

Read actual candidate files, not earlier generator proposals. Verified SHA-256:
- scripts/melee_contact_geometry.gd: 22f6d2e77daa089f14eed6bd4982c89561193f42aac485201beb704464b15752
- scripts/duel_timeline.gd: c71e5419b10010fc2b3225e515fc8c448676475e7d0b6dce18a9398b9b5432f9

The samples-ownership issue is closed for the supported default API: the new trailing trusted_planning_samples argument defaults false; can_prune short-circuits on that flag, so existing four/five-argument callers retain full evaluation, including their supplied samples. Only two production-script call sites pass true, both inside _plan_melee_approach and using the local Dictionary freshly created at function entry. That dictionary is passed to geometry only, never published to callbacks or action state. Exact builtin pose/strike identity and finite-input checks remain required even for opt-in. is_instance_valid now precedes get_script in both Object guard paths. These are implemented fixes, not pending recommendations.

The boolean is an internal caller contract, not enforcement against arbitrary code deliberately opting in with poisoned cache data. New call sites or provider/call-graph changes must re-establish ownership and purity. No need to scan the entire trusted samples cache on every candidate.

Read the added test sources without executing Godot: pair.gd adds legacy four-argument behavior, default external pose-cache output/cache-byte equality, deep/cyclic dictionaries, nested unknown Objects, and freed Object rejection. logic_candidate.gd retains the current fit body with synthetic geometry; logic_test.gd covers an exact symmetric winner tie (first negative aim retained), neutral first-candidate contact early return, +/-0 origins, and default-path full-evaluation call counts. These are appropriate focused additions. +/-0 input coverage is not a claim that every internal signed-zero bound case is dynamically generated; the ordering proof still justifies equal-zero incumbent retention.

At this review time the newly queued tests, expanded scenario matrix, fixtures, and frozen-source ABBA results have not been independently observed by this reviewer. Earlier passing results on pre-final sources must not be relabeled as final-source results. Source review identifies no remaining blocker to executing the isolated final validation; it is not release approval or a claim that the frame-time gate passes. No Godot/benchmark was run during this review.
