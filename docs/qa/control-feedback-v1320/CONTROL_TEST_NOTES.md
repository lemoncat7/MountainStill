# Independent targeted control-contribution tests

Owned test: `tests/test_practice_control_contribution.gd`. No runtime code is edited by its author.

Synthetic event tests cover unique action/contact identities, duplicate batches, wrong actor/target, idle posture break (`interrupted=false`), a contact marked broken without an actual interruption event, absent IDs, invalid event entries, input immutability, engine report/RNG immutability, deep report detachment, cancellation/retry and invalid-start reset.

Real-engine fixtures use unmodified Content frost/thunder definitions and the canonical summit boss, with explicitly synthetic hero stats (not claimed as earned growth). An independent plain Duel and PracticeSession receive the same copied inputs and seed. Each returned event batch, RNG state, HP and resource snapshot must match. A separate offline reduction derives contributions from returned events without calling the production observer. Both a 0.1s stepping run and a whole-duel 120s call require nonzero slow and interruption counts, covering final-batch observation before report freezing.

An actual bounded 120-second timeout and pause/resume are exercised independently. UI helpers distinguish measured zero, missing/partial legacy data and malformed counts/versions, and must explain the limits of both measurements.

Run with isolated writable XDG directories after import:

```sh
godot --headless --path /workspace/scratch/778a2592935f/control-feedback-v1320 --script res://tests/test_practice_control_contribution.gd
```

This focused test is not native UI acceptance, a complete gameplay regression, or proof of production save/RNG isolation at the host level; the existing host suites remain necessary.

## Executed result

Godot 4.6.3-stable, 2026-10-23 UTC: final targeted run **4,973 checks / 0 failures, exit 0**, with no ERROR, SCRIPT ERROR, WARNING or leaked-resource messages. The stepped and whole-duel real-engine fixtures both produce **6 slow-affected enemy starts and 11 actual action interruptions**, with complete event/HP/resources and both combat/choice RNG trajectories equal to a plain Duel. Defeat and exact numeric version 1.0 acceptance are also covered. Earlier initial targeted pass (4,967 / 0) is retained separately; the final run adds those assertions and explicit enemy-choice RNG equality.

Evidence: `control-test.log`, `control-test.exit`; test SHA256 `615feffcb730d5919b995ea53856362b712b2ac50e278b0acfdd77617e9c052a`.

A pre-execution read-only review identified overly permissive UI version coercion; the runtime owner corrected it before the first test run. No test assertion was relaxed to accommodate the old coercion.
