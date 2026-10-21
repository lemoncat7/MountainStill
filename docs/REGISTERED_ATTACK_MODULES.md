# Registered attack modules

The attack pipeline resolves trusted module IDs when an encounter/loadout starts. A weapon or manual owns its choreography, authored phase timings, local strike geometry and presentation cues. The timeline still owns qi, cooldowns, RNG, damage, guard/dodge outcomes, event scheduling and persistence.

## Runtime flow

1. Project bootstrap registers preloaded `Script` factories in `attack_module_registry.gd`.
2. A loadout references an `attack_module_id`, for example `weapon.sword`, `technique.mist` or `enemy.moss_beast`.
3. `registry.bind(id, context)` constructs a fresh `RefCounted`, supplies a copied context and validates its definition. Every combat slot has its own mutable selection state.
4. Action commits invoke the already-bound provider's `select_action(state)`. No weapon/manual switch in the timeline is needed to select a new module.
5. Live transient motion carries direct `pose_provider` and `strike_provider` references. Pose sampling invokes `pose_track`; physical contact invokes `geometry_points`. The module ID is also available for diagnostics.
6. Events and persistable resource snapshots carry data and IDs, never provider objects. Synthetic practice/preview calls without a direct provider use the registry's cached pure pose adapter.

This is a structural dispatch improvement, not by itself a performance claim. Measure before/after using the same scene, seeds, actions and sample counts. The registry is absent from the live per-frame provider call path. Script-specific move/phase sampling and universal combat-state checks remain legitimate work.

## Module contract

Extend `res://scripts/combat_modules/attack_module.gd`. Register a project-owned, preloaded Script. A module is not a Node, a simulator, a user-supplied script path or an evaluated expression.

- `configure(context: Dictionary)`: called once per binding. Context is copied; mutable state stays on this instance.
- `_build_definition(context) -> Dictionary`: returns a data-only description. `definition()` caches it and returns deep copies to callers.
- `select_action(state = {}) -> Dictionary`: returns a copied action, including its stable `move` and `module_id`. The base implementation rotates the sequence, validates a requested move and supports `kind = "weapon"` for an innate weapon art. `use_count` can make selection explicitly deterministic; the instance also has an isolated `selection_count`.
- `modify_basic(action, context = {}) -> Dictionary`: optional compatible-form transformation. The base implementation applies data-driven phase multipliers and a form tag without mutating the input. The host checks equipment compatibility first.
- `pose_track(motion, gather, extend, stance) -> Dictionary`: a pure sample containing the complete base joint-track keys. It must not advance selection, mutate the motion, spend resources or generate outcomes.
- `geometry_points(motion, rig_pose, grip) -> PackedVector2Array`: pure painted contact points. The host supplies the actual sampled joints/grip, so modules do not import the renderer. Technique melee attacks use their equipped weapon's strike provider.

Enemy modules also expose a finite enemy-specific sampling/metadata API; their shared implementation is in `enemy_attack_module.gd`. The host remains responsible for choosing/spending the RNG roll and stamina, and for applying defensive outcomes.

## Definition and action data

Required definition fields are `id`, `kind` (`weapon`, `technique`, `enemy`), `moves`, `sequence`, `resources`, `action_cues` and `strike_geometry`. Authored moves provide numeric nonnegative `windup`, `strike`, `hold`, `recovery`, `gap` and nonempty finite `hits`. Additional fields include:

- `style`, `default_move`, `weapon_move`
- `action_kind`: `weapon`, `weapon_art`, `spell`, `defense`, `utility`
- `attack_scale`
- `resources`: default `qi_cost`, `cooldown`
- `basic_modifiers`: optional `form`, `strike_scale`, `recovery_scale` and other phase scales
- Per-move `basic_range`, `lunge`, `trail_kind`, `sound_kind`, `armor_factor`
- Geometry descriptors such as `kind`, `attachment`, `weapon_key`, `needs_grip`, `range`

The three built-in weapon modules preserve their original timings and joint coefficients. Their painted blade/rim samples are precomputed in local grip space. Hand geometry still follows the active near/far hand and the actual palm/fist silhouette.

## Adding an attack module

1. Add a trusted Script under `scripts/combat_modules/` extending the base contract (or a suitable existing module).
2. Supply its own definition and pure pose/geometry methods. Reuse base helpers rather than copying scheduling/outcome logic.
3. Register it once, for example `registry.register_module("weapon.spear", preload("res://scripts/combat_modules/weapon_spear.gd"))`.
4. Reference `"attack_module_id": "weapon.spear"` in the equipped config. A new manual uses the same mechanism with a technique module ID and its own `action_kind` and resources.
5. Add module tests, including finite pose samples, contact geometry, resource-cost integration and continuity at phase boundaries. No central attack-loop modification is required.

### Explicit heart-method basic override

A heart method normally remains passive. Its `attack_module_id` does not replace the equipped weapon's ordinary attacks. A heart method may deliberately provide `basic_attack_module_id` to replace the free basic provider, but only while the heart is active and `required_weapon` is compatible with the equipped weapon. The replacement is still scheduled as a zero-qi basic attack; qi/cooldown responsibilities do not move into the heart module. Incompatible and inactive overrides are ignored.

### Save, pause and restart semantics

A battle-resource snapshot persists stable module IDs plus qi and keyed cooldowns, including custom ability IDs. It contains no live providers. Loading the same selected loadout with those resources creates fresh provider instances and preserves the remaining resource deadlines; it starts a new encounter action sequence rather than restoring an in-progress animation. The selected config remains authoritative. Starting without saved resources resets selection, qi and cooldowns. Merely sampling poses or not calling `advance` does not advance time or spend resources. Separate duels may share the factory registry, but not mutable provider or resource state.

Legacy weapon/manual/route IDs are still accepted through setup adapters. Existing save IDs are not renamed. New extensions should explicitly reference module IDs.

## Validation and fallback

- Duplicate IDs are rejected; an existing registration is never silently replaced.
- IDs are bounded and limited to lowercase letters, digits, periods, underscores and hyphens. Paths and expressions are not IDs.
- A factory must inherit the finite `RefCounted` contract. Registration probes its definition and complete neutral pose.
- Definitions reject non-finite data, objects/callables, invalid contact budgets, missing phase fields and unknown sequence moves.
- Definitions, contexts and actions are copied; mutating a caller's dictionary cannot alter another duel.
- Unknown or invalid-context module bindings resolve to the validated `weapon.unarmed` safe fallback. Diagnostics retain the latest 64 errors for inspection. The host must still enforce compatibility and category/resource authorization for the selected slot.
- Cached pose providers are for pure sampling only. Never call `select_action` on them, never serialize them and never reuse them as live combat bindings.

## Tests

Run with a writable Godot user-data directory:

```
XDG_DATA_HOME=/tmp/mountain-data XDG_CONFIG_HOME=/tmp/mountain-config XDG_CACHE_HOME=/tmp/mountain-cache \
  godot --headless --path . --script tests/test_attack_module_registry.gd
```

The registry suite covers all 17 built-in registrations, deterministic per-instance state, deep-copy isolation, duplicate/unknown/invalid definitions, non-finite and incomplete-pose rejection, all declared move tracks, exact legacy painted strike geometry and a genuinely new custom module. The custom module is equipped in a real `DuelTimeline`, drives real actions and rig samples, and verifies that events/snapshots contain no provider objects. The enemy module suite separately compares its adapter against the previous authored behavior.

The same registry suite also checks a brand-new active ability supplied only through an injected registry, module-defined default qi/cooldown spending, explicit compatible heart basic overrides, passive/inactive/incompatible heart behavior, pause/restart, JSON snapshot roundtrips, custom cooldown restoration, independent sibling duels and legacy configurations without module IDs. The optional `-- --enemy-fallback` argument additionally checks malformed/wrong-category enemy loadouts. The timeline validates the enemy category and rebinds the trusted route species when the generic registry fallback is unsuitable for an enemy slot. This check passed 2,529 assertions including the normal suite.

## Outcome response presentation

`combat_response_cues.gd` is a pure shared outcome-presentation adapter, independent of attack selection and module registries. New registered weapon/manual attacks automatically receive earned-counter anticipation and contact cues through `counter`, `counter_source` and `counter_earned_at`. No weapon-name switch or additional per-frame registry lookup is required. The counter anticipation overlay is exactly zero at every contact and recovery endpoint; the bound module still owns the strike pose and painted reach.

Actual guard events provide `counter_earned` and their real `contact_id`. Counter contact events retain the original source contact ID, so a successful punish can be distinguished from a counter attempt that whiffed, was blocked or was dodged. `poise_broken` remains the only authorization for a mechanical posture break. The attacker's short post-guard rigid render transform is keyed by `deflected_contact_id` and does not alter collision geometry, action lanes, root spacing or interruption.

The active barrier is a separate state-driven protective field. `draw_barrier(canvas, body_feet, state, cast_amount, impacts)` paints a transparent broken luminous rim, reads real absorption/depletion from impact records, and fades when the actual shield expires or is spent. `barrier_status(state)` exposes the technique, remaining points and seconds for the host. Ordinary guarding never activates this field. All event/resource records remain data-only.
