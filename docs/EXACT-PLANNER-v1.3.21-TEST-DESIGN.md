# Final build execution addendum — 2026-10-23

The final source regression and both actual shipped payloads (Windows EXE embedded PCK and macOS PCK) each ran the frozen external fixture with **217 checks / 0 failures**, 32 neutral early returns and 2 finite equal-best observations. Builder used Linux Godot with the actual payload as `res://`, not a source-runtime fallback. This closes the actual-PCK execution item below; it does not establish native Windows/macOS or performance acceptance. Full build scope is in `../BUILD_VERIFICATION.md`.

The original author design and freeze record below is preserved as a historical, source-only report.

---
# Exact planner guard targeted regression

Status: final author source run PASS, 217 checks / 0 failures, exit0. Product files untouched. Actual exported-PCK run remains builder-owned.

Entry: `tests/test_exact_planner_guard.gd`; sibling required: `tests/exact_planner_custom_fan.gd`.
All runtime preloads target `res://scripts/` (actual source project or mounted actual shipped PCK). The fixture is loaded relative to the executing test script's `resource_path`, not `res://tests`, and extends the actual product fan. For actual-package execution, copy both scripts to the same external directory and invoke the test via absolute `--script`; no test dependency has to enter the PCK. Never substitute research runtime modules.

Suggested source command after parent-owned import:
`godot --headless --path /workspace/scratch/778a2592935f/exact-planner-v1321 --script res://tests/test_exact_planner_guard.gd`

Builder: run with actual exported payload mounted as `res://`, then `--script /path/to/external/test_exact_planner_guard.gd`. Keep sibling fixture next to it. Isolate HOME/XDG/user data as usual.

Coverage design:
- Independent full ordered enumeration uses actual public Geometry.measure/separate and actual rig/source artwork. Same floating-point order, neutral early return and strict-less tie retention; no copied geometry implementation.
- Default omitted trust equals explicit false, including cache mutation; trusted true result exact against full oracle for three exact builtin providers.
- Valid externally supplied modified contact pose is honored by default/false, with complete cache equality. This intentionally does not assert safety of a caller lying by passing trusted=true for polluted samples; trust is owned by timeline.
- Stateful custom subclass is rejected by exact script-identity guard; true request still makes identical pose/geometry callback counts.
- Missing/nonobject/unknown provider, nonfinite origin/input, excessive nesting/cycle/freed/unknown object fail-open guards.
- Actual neutral-contact early return must occur. Finite equal-cost external-pose fixture asserts first candidate retained; tie count now excludes nonfinite costs. See final scope below.

This is correctness regression, not native GUI, benchmark, or performance evidence. PASS is bounded to the final source invocation documented below.

## Final author run / freeze

Final source run: `guard-final.log`, exit0 (`guard-final.exit`), **217 checks / 0 failures**, 32 neutral early-return observations and 2 finite equal-best observations. No ERROR/SCRIPT ERROR/leak diagnostic. Prior first/second runs retained (180/0 then186/0); final adds true warm cache reuse.

Finite tie is an explicit external-sample fixture with actual Unarmed provider / actual product measure/separate and real painted body. Identical cached contact poses for opposite aims, neutral arm moved out of vertical reach, force a finite -0.2/+0.2 best-cost tie; result asserts first (-0.2, crouch0) retained. It tests PUBLIC default/explicit-false fallback semantics and cache ordering, NOT the trusted internal prune path under adversarial samples. No synthetic geometry implementation or research runtime is loaded. Trusted true cold/warm parity uses unmodified builtin samples only. Full-oracle code shares the known legacy arithmetic/order; independent static review remains necessary, not an independent geometric implementation.

This focused entry does NOT test missing-art cache or eviction; do not relabel prior research evidence as this run. Actual PCK external execution remains for builder.

Frozen scripts SHA256:
- `tests/test_exact_planner_guard.gd`: `db3a955919b3878ec689468eea1c27efeaf1dc980785a6448f664c491c985fe1`
- `tests/exact_planner_custom_fan.gd`: `01e8f914ff2b822c1e4e497b2698b209963d086a518e08c9987cf1299a7be319`

Cold in this focused test means a fresh per-call samples dictionary, not independent cold global source/pixel caches; the full oracle may warm those shared caches.
