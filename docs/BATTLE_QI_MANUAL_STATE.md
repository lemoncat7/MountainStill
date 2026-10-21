# Battle qi, manuals, and saved route state

Implementation contract and focused regression results for the composable-manual revision. Save version remains **4**; monster balance, timeline poses, and host/UI rendering are owned by separate modules.

## Authored manuals

The catalog is bounded at ten manuals. Tags describe a manual; legal operating slots are explicit, separate data. Collected ranks survive dormancy and loadout changes.

| Stable ID | Manual | Tags | Operating slot(s) | Max rank | First realm | Active qi / base CD |
|---|---|---|---|---:|---:|---|
| mist | 云岚剑诀 | 武技 | weapon form; independent active | 6 | 0 | 12 / 6 s |
| petal | 落英扇诀, formerly 落英身法 | 武技 / 身法 | weapon form; independent active | 5 | 1 | 14 / 8 s |
| ember | 照炉炎诀, formerly 照炉心法 | 术法 | active | 5 | 4 | 18 / 7 s |
| stillness | 止水内功 | 心法 / 护体 | primary heart | 6 | 3 | passive |
| breath | 归息心法 | 心法 / 辅助功能 | primary heart | 4 | 0 | passive |
| frost | 霜缚诀 | 术法 / 辅助功能 | active | 4 | 6 | 16 / 10 s |
| thunder | 鸣雷诀 | 术法 / 武技 | active | 3 | 9 | 20 / 12 s |
| barrier | 护元诀 | 护体 / 术法 | active | 5 | 1 | 16 / 12 s |
| body | 松骨诀 | 炼体 / 护体 | passive | 7 | 3 | passive |
| mending | 回春诀 | 辅助功能 / 术法 | active | 4 | 3 | 18 / 14 s |

- A new game retains learned mist I and grants basic breath I. Its heart slot remains empty until the user confirms a first choice.
- The starter mist form and active selection remain saved when unarmed but are explicitly inactive. Sword form requires a real owned/equipped `weapon_sword`; fan form requires `weapon_fan`.
- Weapon form selection does not automatically queue its paid technique. The new explicit slot APIs are independent. The legacy `select_technique` adapter may populate an available active slot for an old weapon-art caller.
- Heart manuals cannot be placed in the free passive slot, preventing an alternate route around paid heart replacement.
- Ordinary basics are free. Skill costs and cooldowns come from the authored dictionaries consumed by the timeline.
- Mist's old +3 attack/rank, petal's +12% gathering/rank, ember's +15% brewing/rank, and stillness's +8% cultivation qi/rank remain when that manual occupies an operating slot. Merely collecting or attuning a book grants no effect. The old weapon-art utility remains selected even while its actual combat form is weapon-incompatible.

## Capacity and paid study

Attunement capacity is 3/4/5/6/7/8 at realm indices 0/1/3/6/9/12. Excess restored books retain every learned rank but are dormant. Active slots are one initially, two at realm 3; one passive slot opens at realm 3. There is one simultaneous study job initially and two at realm 6.

Each manual defines its own max rank, rank-by-rank realm gates, prerequisites, material cost, and study duration. Current durations are bounded to 8–24 seconds. A study starts by paying the displayed herbs/dew once; only the completed timer grants the next rank and increments the completion counter. Cancellation is explicit and does not refund materials. A new rank never auto-equips a manual.

`step()` integrates study and heart-change completion at exact event boundaries alongside cultivation, buffs, brewing, gathering, and journeys. Pausing stops the timers. Normal capped offline cultivation can complete paid study or heart adjustment. Clock rollback does not advance either timer. This integration does not advance battle resources.

Public state APIs:

- `attunement_capacity()`, `active_capacity()`, `passive_capacity()`, `training_capacity()`
- `attune_technique(id)`, `unattune_technique(id)` → `{ok, reason}`
- `equip_technique(id, slot)`, `unequip_technique(id, slot)` → `{ok, reason}`; slots are `heart`, `weapon_art`, `active`, `passive`
- `upgrade_technique(id)` → `{ok, reason: "training_started", level, target_level, duration, cost}`
- `cancel_technique_training(id)` → `{ok, reason, refunded: false}`
- `technique_training` contains `{id, target_level, remaining, duration}`
- `technique_rows()` exposes tags, legal slots, equipped slots, compatibility, rank cap, next realm gate, prerequisites, exact cost, training progress, and rejection text

## Confirmed heart replacement

The first confirmed heart choice costs zero and completes immediately. `heart_equipped_once` persists; unequipping cannot restore the free choice. Later replacements require an explicit two-step quote and confirmation, and occur only in the courtyard: any retained `stage_run`, including a paused checkpoint, blocks them.

For a target of rank L at realm R, let T = target switch tier − 1, S = style difference (0 or 1), and G = the absolute rank gap from the previous heart. Breath is authored tier 1 / qi-flow style; stillness is tier 2 / guarding style. The formula is:

- Cultivation qi: 40 + 15L + 8R + 12T + 10S + 3G; at realm 15 use merit instead
- Herbs: 4 + 2L + T
- Dew: 1 + floor(L / 2) + S
- Adjustment: 12 + 4L + 2S + min(G, 3) seconds, currently at most 41 seconds

At realm 6, breath I → stillness I costs 125 cultivation qi, 7 herbs, 2 dew and 18 seconds. Reversing to the lower-tier breath I costs 113 qi, 6 herbs, 2 dew and 18 seconds. With the same target/realm, a larger origin-to-target rank gap adds an explicit further cost.

The previous equipped heart ID persists after clearing the slot and through save/load; clearing it cannot evade the style/rank component. Old saves with a used-but-empty heart and no reliable origin retain the modest style surcharge. The quote includes a `pricing` breakdown and `cost_reason` explanation. An accepted duration is saved unchanged, even if the previous heart later gains a rank during adjustment; loading never reprices or recharges it.

`quote_heart_switch(id)` returns the old/new names and effects, exact costs, duration, first-choice flag, effective stat deltas, and an opaque token. It does not spend or equip. `confirm_heart_switch(quote_or_token)` uses the stored quote, not caller-edited cost/target fields, deducts once, and records `pending_heart_switch`.

The old heart remains effective throughout the adjustment. The new heart commits atomically on completion. Departure, a second switch, removing the old heart, unattuning the target, and starting study on the target are blocked while adjustment is pending. Save/load never charges again. Replaying a quote or changing loadout, learned ranks, realm, or attunement invalidates confirmation. Routine passive qi gain does not invalidate an open quote each frame; affordability is rechecked on confirmation.

## Battle qi and actual item skills

Battle qi is **not** `CultivationState.qi`. That existing resource remains cultivation/breakthrough energy.

Effective stats expose:

- `combat_qi_max`: base 40 + 2 per realm, plus authored bonuses, capped at 80
- `combat_qi_regen`: base 2/s, plus authored bonuses, capped at 4/s
- `skill_cost_reduction`: fraction, capped at 0.35
- `skill_cooldown_reduction`: fraction, capped at 0.30
- `heart_method`, `weapon_art`, `active_skills`, `passive_methods`, `weapon_skill`

Breath I grants +6 max qi and +0.35/s; subsequent ranks add +2 and +0.05/s. Stillness I grants +6 poise, with +1 per additional rank; its guard profile is supplied to the timeline. Body I grants +20 max HP and +4 poise, with +4 HP/+1 poise per additional rank. State folds qi/HP/poise exactly once; the timeline owns action effects and defensive resolution.

Existing meridian node IDs and old effects are preserved. Four branch nodes gain modest combat-resource effects:

- 合谷: skill qi cost −6%, retaining +4% haste
- 间使: battle qi recovery +0.25/s, retaining −4% recovery time
- 悬钟: skill cooldown −8%, retaining +4% haste
- 命门: battle qi max +8, retaining +4% cultivation qi and brewing

Weapon innate definitions belong to canonical equipment templates, not appearance presets or arbitrary instance fields:

- `weapon_sword_pierce`: 青锋 · 破风刺, qi 10, base CD 9 s
- `weapon_fan_return`: 流云 · 回风扇, qi 12, base CD 10 s

Unarmed/cosmetic-only equipment grants no innate skill. All returned descriptors are deep copies.

## Saved route resource contract

`stage_run.battle_resources` contains battle `qi` and a `cooldowns` dictionary keyed by all nine stable paid ability IDs, including unequipped abilities. Derived current-lane aliases and metadata are returned for UI/compatibility, but the per-ability map is authoritative.

- `stage_battle_resources()` returns a deep canonical snapshot.
- `stage_status()` also includes `battle_resources`.
- `update_stage_battle_resources(run_id, resources)` accepts only the matching active route. Stale or paused-route callbacks cannot mutate it. A globally paused host may flush already-observed state before pausing the route.
- The state API never advances resource time. The runtime host explicitly provides combat or permitted active-adventure snapshots. `step()` and offline loading cannot refill qi or advance cooldowns.
- Partial updates retain absent per-ability cooldowns. Switching technique/gear and switching back retains the original ability debt.
- Resume, failure/retry, reload, and monster checkpoints retain these values.
- A legacy v4 route with the entire field absent initializes full qi/ready abilities once. Intermediate old lane fields map to their stable ability IDs. Present malformed fields do not receive legacy full-resource initialization.
- Unknown IDs are discarded; numbers are finite and clamped to current max qi or each ability's authored base CD. Invalid qi types/nonfinite values become zero. Invalid cooldown types/nonfinite values conservatively use the ability's maximum CD.

## Verification

Headless Godot 4.6.3 with isolated writable XDG data/cache/config paths:

| Suite | Checks | Failures |
|---|---:|---:|
| test_battle_qi_state.gd | 272 | 0 |
| test_campaign.gd | 521 | 0 |
| test_campaign_journey.gd | 193 | 0 |
| test_adventure_state.gd | 1,624 | 0 |
| test_cultivation.gd | 189 | 0 |
| test_meridian_branches.gd | 202 | 0 |
| test_equipment.gd | 290 | 0 |
| test_equipment_upgrade.gd | 3,019 | 0 |

The dedicated suite covers the four original selected-manual migrations, preserved ranks/dormancy, wrong-slot save corruption, paid timer persistence and partition equivalence, quote tampering/staleness/replay, first-choice reset prevention, authored tier/style/rank-gap prices, empty-slot surcharge bypass prevention, immutable accepted durations, active-route heart rejection, exact stat effects, real weapon ownership, malformed NaN/infinity/negative resource values, per-ability cooldown persistence, no offline combat progress, and battle/cultivation qi separation.

The unassisted peaceful endpoint remains exactly **30,772 simulated seconds**, with no battles, unsolicited study, or new requirements. Combat balancing, visual evidence, and native UI testing are reported separately.
