# Chapter → enemy intel navigation: test design

Owned files: tests/test_chapter_practice_navigation.gd and this note only. No runtime edits.

Written against the integration owner's requested API, not yet executed. Wait for runtime/import completion and a free non-performance execution window.

Coverage: real host and chapter_enemies/combat_back buttons; every chapter in a fresh save (locked included), every chapter after explicit unlock fixture, dynamic enemy-row expansion; duplicate old button + original generation; stale generation/chapter/tab/drawer callbacks; ordinary Insight entry return; retained expedition, earned corpse and unresolved checkpoint choice cannot start a trial; cancelled/finished no-reward trials return to chapter and restore formal engine/pause. Comparison-open flag must be cleared.

Snapshots remove saved_at only. Since _snapshot itself updates _clock_high_water, mark captures high-water after snapshot; unchanged tests clock first before another snapshot. This avoids blaming the snapshot reader for a navigation mutation while checking save payload/RNG separately.

Save path is process-unique user://chapter_practice_navigation_PID.json; host processing is disabled and explicitly advanced only inside trial tests. Requires isolated XDG for execution. Realm/unlock/corpse/checkpoint setup is test fixture, not naturally earned campaign progress. No native rendering/font geometry/FPS claim; existing gameplay tests remain required.

## Actual run, 2026-10-23

After owner confirmed successful runtime import and no exclusive performance window, ran Godot 4.6.3 headless with isolated `nav-data`, `nav-config`, `nav-cache` roots.

Final: **338 checks, 0 failures**, process exit **0**. `navigation.log` contains no script/resource/shutdown warnings. Live trial cancellation uses actual Escape input; completed trial uses the real `practice_end` button, then real `combat_back` returns to chapter.

Test frozen SHA256: `da7b2bbd0afb85fa9027b95ec7285cdf25c951c636fa5ce9ae403216d5b80cb5`.
Tested runtime SHA256:
- adventure_pages.gd: `4de97edf2915e86c36b2f9f599889d4513b9bd81585a817311cff2b11e3b6eec`
- combat_insight_pages.gd: `4b188fe9bbb366bfd7b6964d371395dcc894b94981b0177fc3cf986501d4ab73`

Earlier failures retained, not counted as passing:
1. `navigation-initial-parse-failure.log`: production adventure_pages.gd:178 invalid elif due insertion indentation. Owner corrected runtime; this agent did not edit runtime.
2. `navigation-generation-fixture-failure.log`: one test assumption was incorrect: ordinary `_refresh_drawer()` does not advance generation. Corrected to separately verify detached old button after ordinary refresh, and stale generation API after `_refresh_drawer(true)`; no test threshold weakened and no product check removed.

All six chapter rows are tested on fresh locked progress and on explicitly unlocked progress (12 roundtrips). Snapshot equality includes all saved resources/progression/gear/loot RNG, with only saved_at removed; high-water writes checked independently. Retained run/body/choice test setup is isolated fixture. Comparison-open flag false is sufficient per implementation owner's declared contract; unrelated cached UI quote data are not required to be deleted. No claim about native visuals/performance, actual public packaging, full campaign play, or the rest of regression suite.

## Additional lifecycle review regression — supersedes 338-count freeze

Latest final run: **386 checks, 0 failures**, exit **0**, no script/resource/shutdown warnings (`navigation.log`). The original 338-pass log remains `navigation-original338-pass.log`.

Added:
- Chapter enemies → close book → actual R input → journal → explicit `Journey.navigate` equipment / locked route / technique target. All clear chapter return context and its overlays; equipment shows a live `first_chest` control, not detached stale enemy buttons. Route/technique show their requested live controls. Entire State/RNG and independent high-water checks pass. `arrival_seen=true` isolates navigation from the preexisting first-journal persisted acknowledgment.
- Genuine retained opportunity state fixture → chapter enemies → actual `_open_route_opportunity()` entry (bypasses sidebar) → equipment. Pending choice/checkpoint remains intact; chapter source and overlays clear, and clothes do not reopen enemy intel.

This agent only added tests. Owner fixed the scoped lifecycle runtime issue after independent review; earlier ordinary-v18 overlay behavior is not broadened into this change. Gather/meditate actions are deliberately excluded from read-only assertions because changing activity is their documented effect.

Latest test SHA256: `8f4b064434a7050993e571aa14c715eb9d0002288b5f06d848e58c85c33eea91`.
Additional tested runtime hashes:
- ink_pages.gd: `86410e458e88834e8f60f79b18a593a3541b731a0aca9d9c9afafed3d864244b`
- player_journey_pages.gd: `5fffe04a6ba2d497e51045e2e2a59127df4d4c339bcec2e6282579db72c1d634`
Adventure and combat insight hashes remain as recorded above.

Pre-fix lifecycle defect was found by independent review, not rerun on pre-fix source by this test author. Original evidence is retained at `chapter-practice-independent-review/extra.log` with its corresponding probe; the independent review report owns baseline comparisons. Do not treat the new passing regression as a fabricated pre-fix reproduction.
