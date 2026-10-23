# Mountain Still v1.3.22 — Linux GUI short smoke

**PASS within the scoped smoke.** Real Linux desktop interaction, 2026-10-23 20:11–20:18 UTC, Godot 4.6.3 official. Both native processes closed normally (`NATIVE_EXIT=0`). No `SCRIPT ERROR` or parse error. This is not Windows/macOS testing, an FPS benchmark, a long soak, or evidence of an ordinary player triggering the freed-provider boundary.

## Frozen input and isolation

- Candidate: `provider-lifecycle-v1322`; independent GUI copy: `provider-lifecycle-native-qa/MountainStill`.
- Freeze manifest SHA256: `c1594174562a1ef246b5313084694ec4b24342912d6a06c9b8e53f4cb78097b2`.
- All 70 runtime/config files and 5 test/driver files matched before launch; final verification matches both the GUI copy and candidate. All 464 asset/import-sidecar files compare byte-identical between them.
- Only separate `unarmed/` and `fan/` XDG data/config/cache directories were used. `res://main.tscn` was launched directly to avoid an updater path. No production save was opened or changed, and no candidate runtime was modified.
- Fixture is the previously completed natural-growth sword-route final snapshot, SHA256 `48ec671124fa110139adcfcd886b88099477f5636a01c063986da8e074c554ad`: realm 15, all six chapters completed, 18 victories, no pending stage run. The fan is already legally owned; no equipment, currency, attributes, or combat values were granted.
- Explicit setup adjustments: fresh save timestamp; paused mountain time; disable auto-advance; arrival already seen; game UI scale 1.25; initial 960×540 window. External `seed.gd` calls real APIs to clear active-technique slots, unequip weapon for unarmed or equip the owned fan, and select creek-bridge/cloud-slope. Weapon art is retained, so the fan can still spend qi. The small headless setup is not GUI evidence. `run.py`, `seed.gd`, source fixture and pre/post saves are included.

## Actual operations and observations

| Scenario | Real desktop route and outcome |
|---|---|
| Unarmed, 960×540, UI 125% | Wardrobe confirms empty weapon → 历练/听泉桥 → 本章敌情 → 浅溪石灵 (4/18) → 镜中试招. Clicked pause (label becomes 继续试招), resumed, and completed naturally. Result: 6.5 s, damage 190, taken 3, qi 0.0, HP 177/180, control 0/1. Clicked 同敌再试, then Esc; returned to the same enemy. 返回山路 returned to chapter 2. Normal Alt+F4 close. |
| Fan, 1200×400 strip, UI 125% | Opened real F2 strip mode; wardrobe shows owned 流云扇 → 历练/眠云坡 → 本章敌情 → browsed to 白羽鹤王 (9/18) → 镜中试招. Completed naturally: 7.9 s, damage 450, taken 9, qi 11.3, HP 171/180, control 0/1. 同敌再试 → pause → visible 结束试招 returned to same enemy; 返回山路 returned to chapter 3. Normal Alt+F4 close. |

The short observed combat/paused/result samples retained character/enemy proportions, contact presentation, and desktop transparency; no new visible black block, malformed character, or stuck scene was observed during these operations. Single-window capture APIs render alpha as black; the persisted PNGs are unedited full-desktop captures, not those alpha-to-black previews. The transient paper-opening/fade animation was allowed to finish before stable-state inspection.

Both window sizes have readable result text, control counters and navigation/action buttons without clipping. Root independently opened the two original result PNGs and confirmed these layout observations and retained transparency; the 960×540 result also shows normal character/enemy proportions. This is sampled visual review, not proof that every animation frame is glitch-free.

## Exit, state and log evidence

- Desktop window inventory after both exits contained no game; no Godot process remained when the builder was released at 20:18 UTC. `10-desktop-after-exit.png` records the desktop.
- Complete pre/post JSON comparison: unarmed changes only `saved_at` and normal-window coordinates. Fan changes only `saved_at`, window dimensions/mode/coordinates. All gameplay resources, inventory/equipment, progression, formal combat reports, mountain-time counters and 18-victory total remain unchanged; both formal `adventure.stage_run` values remain `{}`. Exact changes and hashes are in `verification.json`.
- Both logs contain zero `SCRIPT ERROR` and zero parse errors. They are **not entirely error-free**: this cloud Linux session reports unsupported V-Sync switching and PulseAudio/ALSA device failure (`ERR_CANT_OPEN`, fallback audio), so audible playback was not validated. These environmental messages also occurred in prior runs; no audio success claim is made.
- The externally freed-object case belongs to the separate focused lifecycle tests/independent review. It was deliberately not injected here; this report only verifies ordinary practice/UI smoke on the frozen candidate.

## Original screenshot index

1. `01-unarmed-wardrobe.png` — legally empty weapon.
2. `02-unarmed-paused-960.png` — paused stone-spirit contact and transparent desktop.
3. `03-unarmed-result-960.png` — completed result; **root inspected**.
4. `04-unarmed-escape-enemy.png` — same enemy after retry/Esc.
5. `05-unarmed-return-chapter.png` — original chapter 2 restored.
6. `06-fan-wardrobe-1200.png` — owned fan and strip layout.
7. `07-fan-result-1200.png` — completed strip result; **root inspected**.
8. `08-fan-paused-1200.png` — fan/crane and transparency; pause tooltip appears beneath its control.
9. `09-fan-return-chapter-1200.png` — original chapter 3 restored.
10. `10-desktop-after-exit.png` — final desktop.

All paths are relative to this evidence directory. The accompanying ZIP contains these ten raw PNGs, two full logs, four pre/post saves, the source snapshot, setup scripts, freeze manifest, verification JSON/script, this report and a SHA256 inventory. No project/assets copy is duplicated in the evidence ZIP.
