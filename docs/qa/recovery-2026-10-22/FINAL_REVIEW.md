# Recovery v1.3.11 current verification

New verification only, 2026-10-22. Runtime freeze `runtime-freeze.sha256`.

- Public v1.3.10 source archive SHA confirmed 41713e26b95ff254ea0347669313733550eac6c54f11ea744210386d3a349473; 187 PNG assets remain identical.
- Two UI runtime files recovered byte-exact from retained lawful code context; other new gameplay code reconstructed and re-tested, not claimed identical to yesterday.
- New focused tests: tactics164, report15, host45, state231 checks, all zero failures.
- Current UI suite: insight4647, evasion113, cultivation328, chapter4430, live-loadout119, readability475, all zero failures.
- Independent edge suite105/0; 12 balanced cases, 1760 events byte-identical to actual v1.3.10 baseline.
- Both baseline and recovered earned campaign measurements: 4474 checks / 2 failures. All 180 encounters, 10 campaigns and 10 powered replays exactly identical after removing only new combat_tactic field. Two identical old pacing diagnostics: sword summit gate sentinel 6.82 seconds below 7 second lower bound. No threshold modified, no all-green claim.
- Independent paired tactics: 5 genuine earned builds × 4 seeds × 4 tactics, 80 real fights all terminate/win. Clear speed/damage/qi tradeoffs within sample; no claim of global balance. Evidence `recovery-independent-qa/REVIEW.md` and `tactic-pairs.json`.
- Native Linux fresh-save play: three actual battles, no injected victory; minimum960, wide and desktop strip UI readable, no clipping; uniform/transparency rendering preserved. Evidence `recovery-native-qa/`.
- Initial complete runner interrupted by execution transport loss; 39 recorded completed exits preserved in `full/completed-before-transport.json`; only uncompleted tests rerun. Never counted interrupted test as passed.

Full runner terminal result: 86 executed, 85 exit0 and only the independently confirmed existing encounter_balance pacing diagnostic exit1. Two external-input tests explicitly separate: final release artifact/bootstrap checks passed by build agent; all five real 64-seed sensitivity shards completed, 17450 checks / 0 failures, 1920/1920 full routes and 5760/5760 battles. Metadata matches final runtime across all five shards. Publication not authorized in recovery scope.
