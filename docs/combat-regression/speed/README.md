# Effective combat speed validation

## Runtime contract

- `speed` is the effective combat stat, with **100 = original authored timing**.
- Setup caches `rate = clamp(speed / 100, 0.65, 1.60)` independently for hero and monster.
- When `speed` is absent or invalid, legacy `combat_haste` supplies `100 × (1 + clamp(haste, 0, .35))`. An explicit effective `speed` already includes earned haste and is never multiplied by it again.
- `CultivationState.stats()` exposes the existing earned meridian haste as this canonical speed. The attribute summary displays the effective value and baseline 100.
- Windup, strike/release, action-owned contact hold, combo spacing, recovery and the between-action interval each use the same reciprocal rate once. Recovery training remains an additional recovery-only modifier.
- Physical approach floors use that same action rate. Each contact is still planned against the moving opponent at its actual projected time. This preserves real geometry rather than guaranteeing a hit by changing damage rules.
- Enemy previews and committed actions share the timing preparation path.
- The opening AI delay, guard/recoil/stagger duration, skill cooldown, stamina/qi regeneration, status duration and hitstop do not use the action rate. Pause continues to stop encounter advancement.
- Speed is cached at encounter/loadout setup. Mutating a stat dictionary while an action is in progress cannot jump its animation phase.

The light/heavy timing dictionaries and their damage coefficients are unchanged. For example, before any range correction, the unarmed jab's authored .93s action becomes .664286s at speed140; the heavier palm's 1.22s becomes .871429s. Both keep their relative timing.

## Authority and fast-frame safeguards

The existing exact-boundary scheduler remains the damage/resource authority. One `contact_id` is resolved per authored contact, and a skill pays once at commitment. A large frame delta consumes all intervening boundaries.

At the maximum rate, some combo intervals are shorter than the normal .16s defensive preparation lead. The lead is bounded by the actual interval since the preceding contact, preventing the clock from stepping backwards. Defense sampling uses the same lead.

Phase sampling uses the scheduler's absolute boundary and epsilon. This fixes floating-point subtraction occasionally reporting the preceding strike at the exact instant a contact had already resolved.

## Verification

| Check | Result |
|---|---|
| Frozen v8 baseline-speed mechanics trace | **1,231 / 1,231 rows exactly equal** |
| `test_combat_speed.gd` | **881 checks, 0 failures** |
| `test_combat_speed_host.gd` | **16 checks, 0 failures** |
| `test_meridian_combat.gd` | **185 checks, 0 failures** |
| Existing continuous duel suite | **44,746 checks, 0 failures** |
| Existing duel timeline suite | **1,109 checks, 0 failures** |
| Existing battle qi suite | **550 checks, 0 failures** |
| Existing combat feedback host suite | **14 checks, 0 failures** |

The focused speed tests cover canonical/legacy precedence, earned +4%, invalid and clipped values, actor-specific phase ratios, physical approach, heavy/light distinction, fast multi-contact authority, one-time qi commitment, exact cooldowns, status duration, pause and large-delta partition determinism. The host test uses actual resolved contacts at both speed100 and speed140 and checks real-time hitstop consumption and resumption.

`baseline100-mechanics.json` is the final baseline-speed trace. `timing-comparison.json` records paired v8/new actual encounters at speeds100,104,108,135 for unarmed, sword and fan.

## Deliberate differences for already-earned haste

The old haste path omitted contact hold and the between-action gap, and its physical approach floor remained unscaled. The new path makes those consistent.

| Earned speed | Jab contact hold, old → new | Hero interval, old → new |
|---|---|---|
| 100 | .090000 → .090000s | .070000 → .070000s |
| 104 | .090000 → .086538s | .070000 → .067308s |
| 108 | .090000 → .083333s | .070000 → .064815s |
| 135 | .090000 → .066667s | .070000 → .051852s |

Real encounter damage is not a direct multiplier of speed. Moving-target approach, action overlap, real defenses, posture interruption and independent cooldowns can change subsequent outcomes. For example, the wide-opening speed104 unarmed fixture retargets the moving crane and has a first-contact time of 1.354861s versus the legacy haste-only path's 1.338645s, while issuing 39 rather than 38 actions over 45s. This is preserved in the report rather than hidden by forcing contact results.

Both complete earned-build balance runs used frozen input trees. Every build won all 18 encounters for both tested seeds. For seed20261020:

| Build | Frozen v8 battle total | New battle total |
|---|---:|---:|
| sword | 259.0765s | 264.9165s |
| fire | 336.8788s | 336.9635s |
| guard | 365.3439s | 364.7807s |
| control | 326.2007s | 326.8138s |
| support | 374.5495s | 373.9100s |

The frozen v8 run had 4,524 checks and five pacing failures. The new run had 4,552 checks and the **same five existing pacing failures**: fire/cloud-guardian 44.70s and support/cloud-guardian 49.47s exceeded the 42s cap for each seed, plus the aggregate 85% typical-boss goal. No balance content was retuned. Both source-freeze assertions passed. The earlier exploratory run's source-freeze failure came from editing while that run was in progress and was superseded by these frozen runs.

## Reproduce

From the project root, with writable Godot data/cache directories:

```sh
godot --headless --path . --script tests/test_combat_speed.gd
godot --headless --path . --script tests/test_combat_speed_host.gd
godot --headless --path . --script tests/counter_mechanics_snapshot.gd -- /tmp/baseline100.json
godot --headless --path . --script tests/measure_combat_speed.gd -- /path/to/frozen-v8/scripts/duel_timeline.gd /tmp/timing-comparison.json
```

For a native same-encounter speed comparison, duplicate the same earned hero stats and enemy definition, change only their `speed` fields to100 versus140 before `DuelTimeline.start`, and use the same seed. Do not multiply `_process` delta or cooldown clocks.
