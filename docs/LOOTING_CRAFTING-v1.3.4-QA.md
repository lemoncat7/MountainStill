# v1.3.4 — Counter, ward, body search and crafting

This revision addresses the user's rejected guard-counter readability, chalky protective dome, immediate monster disappearance and lack of useful material progression. It is a bounded gameplay-loop revision, not a claim that the full game's animation is finished or accepted.

## Actual gameplay flow

1. The existing duel resolves a genuine zero-HP victory using its original damage, defense, qi and cooldown rules.
2. `begin_stage_corpse` freezes the earned item/material/chest rolls in the active run. It grants no currency, material, item, victory count or chapter clear.
3. The defeated creature no longer attacks. Its body collapses and remains opaque while the hero walks close.
4. The hero bends knees and reaches into a two-second search. Only this close-range, unpaused host phase calls `advance_stage_search`; travel and offline simulation cannot progress it.
5. `complete_stage_search` validates the entire payload's capacity, commits it once, advances the route checkpoint and only then handles a boss clear/first-clear gift. A visible receipt identifies actual gains. The body stays another two seconds, then fades for one second before travel/return resumes.

The body and frozen payout live in `stage_run.pending_corpse`. Its elapsed search seconds and reward roll are saved after creation, at quarter-second search checkpoints, at ordinary saves, and immediately after claim. Existing atomic save-file replacement is reused. Loading remains inactive at home; explicit departure resumes the body. Pausing/canceling a run with an unsearched body preserves it. Duplicate and stale claims are rejected. Full material, chest, equipment or currency storage retains the whole payload without consuming or silently discarding any part.

The old `defeat_stage_monster` adapter is retained for legacy model/import fixtures. The real host never uses it. Existing host tests were updated to assert an unpaid body at zero HP and payment after two actual search seconds rather than the obsolete immediate-reward behavior. Seed-search fixtures now include the new independent treasure roll.

## Materials and meaningful use

Nine trusted material IDs are validated and cached in `material_registry.gd`; `material_ledger.gd` stores bounded stacks (9,999 per material). Six species/route pools yield distinct raw materials plus a common spirit shard. The prior independent chest 12% and equipment 3% rolls remain; a rare spirit jade independently rolls at 1%, without a guarantee.

The catalog is a bounded extension point: add trusted material rows to `MaterialRegistry.MATERIALS`, map the existing route/species pair in `ROUTES`, and add a data-only `combine` or `manufacture` recipe plus its display order. Validation runs once and caches canonical records; saves contain only validated IDs/counts and canonical item specifications, never executable module paths. The host calls `begin_stage_corpse` → `advance_stage_search` → `complete_stage_search`; UI calls quotes before craft/enhance transactions. This does not add weapon-specific branches to the attack core.

Four recipes expose exact current costs, stock and output before commitment:

- Three spirit shards combine into one refinement stone.
- Three of one displayed route material combine into one refinement stone; one rare spirit jade yields three.
- Two moss fibers plus two refinement stones manufacture an uncommon sword.
- Three moss fibers plus one refinement stone manufacture an uncommon chest garment.

Manufactured gear is a canonical owned item, uses the existing equipment visuals and attack-module binding, and requires deliberate equipping. Old equipment is retained. A material enhancement path spends `next enhancement rank` refinement stones, keeps the original instance, and increases it through +5 with no failure or destruction. The old herbs/dew enhancement path remains available for peaceful play and old saves. Costs and before/after attack, defense and evasion are available in the quote. Capacity or insufficient stock fails before mutation.

A pending corpse also blocks abandoning its chapter: the chapter UI returns to the owning chapter with a truthful “遗物尚未搜取” action, preserves the search, and never starts it automatically.

UI: 行装 → 行囊 → 材料 / 百工 / 随身. Material tooltips identify source and use; workshop previews show the actual owned counts and resulting stats. The equipment cost line switches between herb/dew and material enhancement, and its button tooltip shows before/after values.

## Counter and protective field

`combat_response_cues.gd` is a pure event-to-presentation helper. Actual guard contacts preserve contact IDs; earned counters carry their source ID through action, motion and hit events. A guard that breaks does not display a successful deflection. The defender catches and turns outward; the attacker's follow-through redirects briefly without inventing a stagger or interrupting the rules. A counter chambers and releases, with its overlay exactly zero at contact. Only a successful counter hit receives the sharper real-hit cue and label.

Ordinary guard has no field. An actual active barrier/cast creates a transparent softly glowing outline with the body visible inside. Actual absorption produces a localized pulse; the last absorbed hit drives small dissolving fragments. The strength and remaining duration are shown. Both old duplicate shield ellipses were removed from the host.

Headless exact v6/v7 comparisons matched all 1,231 mechanics event rows across nine fixed-seed 45-second scenarios (moss/crane/fire × sword/fan/unarmed). This verifies the sampled action/contact/outcome/damage/HP/qi/timestamp sequence, not subjective motion quality. New guard/counter hitstop is local presentation time and can lengthen native wall time slightly. No enemy HP, damage coefficient or balance threshold was reduced to produce this result.

## Verification status

Model coverage includes pending ordinary and boss saves, half-complete searches, no offline search, duplicate/stale/paused claims, route cancellation, all six species, malformed save IDs and values, atomic storage-capacity failures, crafted equipment stats/visuals/module binding, same-instance enhancement and legacy saves. 179 focused assertions passed. A deterministic 60,000-roll sample produced 12.07% chests, 2.94% gear and 1.02% rare spirit jade, including simultaneous chest/equipment awards.

Combat-focused checks passed for response cues, all 17 modules, action joins, accepted proportions, ordinary guard/evasion, rig anatomy, impact profiles, monster rendering and root continuity. Final frozen-source aggregate and native visual results are recorded in the final verification section below.

### Known inherited balance issues

v1.3.3 had 180/180 victories but five pacing-threshold failures: fire crane 44.6955s (>42) for two seeds; support crane 49.4725s (>42) for two seeds; and the under-35s boss aggregate 48/60 (80%, below the required 85%). The baseline already failed both support-crane seeds at 42.3868s and the aggregate at 50/60 (83.33%); both fire-crane failures are new in v1.3.3. Exact authoritative values and baseline attribution remain in `COMBAT-v1.3.3-QA.md` and its regression data. Do not interpret victory coverage or the focused event comparison as a clean balance pass.

### Scope and limitations

The moss and crane bosses have new genuinely painted, closed-eye fallen keyposes, uniformly registered by the unchanged shell medallion / primary wing-body landmark. Native transition review caught an initial face-box calibration that enlarged the torso; the folded face projects smaller, so body registration takes precedence and the entire source is still scaled uniformly. Their sequence buckles into the low resting silhouette without flattening a standing sprite. Other species and ordinary variants use a bounded rigid collapse/settling transform of existing painted assets; a full per-species death animation library remains outside this revision. The model/search/claim path covers all six routes. Material crafting presently has four recipes, not an open-ended economy. No new desktop installers are exported in this revision. Native playback, UI legibility and user subjective acceptance are separate from the model checks.

## Final verification

The full regression completed 55 ordinary suites with zero failures, including real host search/crafting, all six route transitions, chapter navigation, original proportions/guard, module registration and painted contact geometry. The 180-battle balance run won all 180 encounters and reproduced the same five inherited pacing failures (4,524 checks, 5 failures); the test is correctly marked failed.

During that run, native transition review found a whole-body enlargement at the newly painted fallen-pose swap. Only three measured files changed afterward: `scripts/corpse_presentation.gd`, `assets/cultivation/beasts/fallen-body-landmarks.json` and `tests/test_corpse_presentation.gd`. This was a uniform body-landmark presentation correction, with no attack, HP, contact geometry, scheduler, reward, save or crafting change. The full-run report deliberately retains this source-change flag and is **not** represented as a final frozen-tree pass.

After that correction, nine affected suites were rerun on the final frozen tree: corpse presentation (27), actual loot host/UI (103), campaign combat/art (68,050), route/body continuity (3,935), scene framing (913), accepted side proportions (51,380), sword/guard rendering (6,841), inventory preview (61), and adventure UI (180). All passed; the before/after SHA-256 manifests show zero source changes. Exact full and affected-run records are in `looting-crafting-regression/`.

Independent persistence audit also exercised actual combine → forge → equip → material +1 → save → load, then reopened the save 30 times without changing stacks, owned item identity, equipment or enhancement. Pending-corpse chapter navigation (3,315 checks) preserves the body and returns to its owning chapter without automatic continuation.

### Native proof and reproducibility

The final movie is captured in the existing cloud desktop's native Godot/OpenGL session at 1200×320, 60 recorded frames per second, normal game simulation time. It is a controlled demonstration, not a manually played full campaign. Both boss checkpoints were prepared through legal native-HP battles, real search receipts, paid learning/heart-switching and saved timers. The first segment has no active barrier equipped; the second equips only the existing barrier active, with owned chest gear deliberately removed so actual absorption is visible. Travel and departure portals before the boss arena are omitted; both complete boss fights, collapses, approaches and two-second searches remain continuous.

The workshop section presses the production UI controls using only earned stocks: combine refinement stones, manufacture a real owned chest item, equip it, and enhance the same item with materials. No materials, guaranteed treasures, currency or equipment are injected. A separately labeled final 8.5-second original-strength ember-opponent fixture demonstrates actual shield depletion using the earned light loadout; it grants no campaign/material rewards. Its fixture status is visible in the movie and logged.

The recorder and checkpoint-preparation scripts are included under `tests/`; they accept `--output=` and `--checkpoints=` paths. Runtime source hashes, actual guard-source/counter-hit links, shield absorption/depletion events, search durations and before/after item/stocks are independently verified. Native visual acceptance remains subjective; this deliverable does not claim that the game's full action library is finished.

Final native release: **115.717 seconds**, 200 engine events, 6,943 sampled frame records; recorder reported `failed=false`, `source_frozen=true`, `Engine.time_scale=1.0`, no runtime script errors. Five ordinary guards produced four damaging counters, all linked to their actual guard source; no active shield was equipped in that segment. The active segment/fixture recorded 11 actual absorptions and one real depletion at 114.267s. Both corpse searches took 2.000 seconds and granted one spirit shard plus three route materials exactly once. Crafted chest instance #4 was equipped and enhanced to +1; item defense 6→8, live total defense 2→10. Native logs contain an expected unsupported V-Sync warning from the cloud Mesa driver, not a runtime script failure.

Native proof, media hash, source map and compact audit are in `looting-crafting-regression/native-release/`. The standalone MP4 is delivered separately rather than embedded in the source archive. Both final fallen-pose transitions were visually reviewed after body-landmark correction: the torso no longer expands at the keypose swap. These are bounded authored keyposes, not a complete per-species death animation library.

Delivery encoding: the same final native movie is supplied as 1200×320 / 30fps H.264 with 96 kbps AAC, **8,050,895 bytes**, below the 8,388,608-byte delivery ceiling. Container duration is 115.767s (native simulation evidence remains 115.717s). A full decode passed. SHA-256: `852753bd096363a3aee11a1d1a728e1a8b742700126fb0e7624c628eb3a5ea23`. The original 60fps, 19,350,579-byte capture is retained separately; its hash is recorded without another user attachment.

Example reproduction from the project directory (choose writable output paths):

```sh
mkdir -p /tmp/loot-checkpoints /tmp/loot-native
godot --headless --path . --script tests/prepare_looting_crafting_demo.gd -- --output=/tmp/loot-checkpoints
godot --path . --audio-driver Dummy --script tests/show_looting_crafting_demo.gd --write-movie /tmp/loot-native/loot-loop.avi --fixed-fps 60 -- --demo --checkpoints=/tmp/loot-checkpoints --output=/tmp/loot-native
python docs/looting-crafting-regression/native-release/analyze_loot_capture.py /tmp/loot-native
```

The movie command requires an ordinary available native graphical session. It does not require changing display-server, operating-system security or network settings. The proof checkpoint preparation runs real simulation but is not an unattended production save progression feature.
