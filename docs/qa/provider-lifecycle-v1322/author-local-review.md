# Freed-provider lifecycle guard — narrow stability candidate

## Root cause and reachability
Godot4.6.3 reports typeof(freed Node)==TYPE_OBJECT, is_instance_valid=false, and freed==null true. v20 has no pruning guard. Both v20 and unchanged v21 full geometry/rig paths naturally take null fallback for freed strike/pose providers, returning clean results equal by serialized Variant hash to explicit-null controls. Do not claim those legacy paths are broken.

v21 _fit_pruning_safe performs `provider is Object` before validity checking. On freed instances the `is` operator emits SCRIPT ERROR and aborts that function; caller still receives false/default and full fit returns the same result with exit0. Thus guard can add a logged VM failure without changing the result. Recursive _finite_fit_input uses typeof dispatch then validity, and correctly rejects dead/nested dead without error already.

Normal bound providers are strongly referenced RefCounted modules; they are not normally manually freeable Node objects. This reproducer injects an externally invalid lifetime object. No evidence that ordinary player modules routinely free themselves, no claim of a widespread gameplay crash fixed.

## Minimal candidate
Only one expression changes in scripts/melee_contact_geometry.gd:
`not (provider is Object)` → `typeof(provider)!=TYPE_OBJECT`.
Subsequent is_instance_valid short-circuit and exact script whitelist remain unchanged. No altered recursive finite scan, cache algorithm, full fallback, math, candidate/selection rule, API, or performance gating. The rejected unarmed strategy is NOT included.
Candidate geometry SHA2563abcf94892b98f8b4ffc406de52093e9bf7d45b4b23ca4f76ebb38dfc3f7ce30; baseline v21 geometry22f6d2e77daa089f14eed6bd4982c89561193f42aac485201beb704464b15752. Duel remainsc71e5419b10010fc2b3225e515fc8c448676475e7d0b6dce18a9398b9b5432f9. STABILITY.patch contains the exact one-line delta.

## Runtime evidence and strict oracle
run.py invokes a separate process per mode and records stdout,stderr,returncode. Candidate27processes clean; v20 twelve controls clean; v21 five expected failures (pose-slot guard,strike-slot guard,trusted strike/pose/both fit) preserved. validate.py checks109conditions including values/hashes and five negative oracle injections. Valid builtin guard true; custom/null/scalar/dead guards false; nested dead recursively false; null/scalar finite accepted; dead samples/unused nested fields preserve full results. Candidate trusted fit hash equals v20 full dead/null fallback.

Historical false positive: prior gate_eligibility_review.gd printed23assertions0failures and quit0 while a freed-provider SCRIPT ERROR occurred. Its bool assertion did not detect the VM exception/default result. It is NOT a pass. Strict validation now requires exit0, BEGIN/END and hash markers, expected output, and absence of SCRIPT ERROR/ERROR/crash markers on BOTH stdout and stderr. Injected exit0 errors and missing markers are rejected.

Initial diagnostic harness parse failure (calling nonstatic call() on Script class) is retained under harness-parse-failure; fixed by a local geometry instance for dynamic method invocation. These were harness failures, not game/runtime diagnoses.

Normal full gameplay traces: three fixed scenes, two cold/warm trials each, same frozen semantic probe as native CPU workflow; compare with unchanged v21 B records from unarmed-pruning-gate-study. All3scenes and both cold/warm trials match v21 complete state/event/per-tick hashes exactly; trace-comparison.json and copied baseline-traces retain the comparisons. No timing/performance improvement claim; formal33.3ms remains separate failing gate.

## Handoff limits
Candidate is isolated only; root integrates/reviews/tests complete source and native packages before any v22 publication. No dependency installs or production modifications here. Preserve actual stderr failures in archives, not just assertion counts. Recommended regression integration retains probe.gd plus an external strict-log runner rather than relying on SceneTree quit status alone.
