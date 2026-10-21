# Combat slice revision

This is a focused visual-and-feel revision, not a claim that the whole game has reached finished-game quality. The two revised creature families are the bamboo moss beast and cloud crane. The other four families keep their previous choreography and balance rules.

## What the previous version got wrong

- Most enemy attacks reused three painted states and moved the whole image. Different contact schedules and move names did not create different readable actions.
- Reaction and sound were too uniform. Runtime audio covered only a subset of hero basics, while enemy strikes and many skill contacts were silent.
- The first replacement experiment still stretched the paintings. Native motion review rejected its flattened moss body, elastic crane wing, and sliding recoveries. That experiment is not the delivered renderer.

## Current implementation

- Twenty-four new painted action poses cover normal and boss variants: a compact pounce, grounded two-stride rush and raised-forepaw slam; coiled/extended chain pecks, broad wing sweep and folded downward dive.
- Each revised family uses its new painted neutral during approach, combat and recovery, with a common ground registration. Pose changes do not crossfade silhouettes or elastically deform the creature.
- Enemy choices use distance, the opponent's phase, recent moves and a committed stamina budget. They are seeded for reproducibility, not a fixed three-move rotation.
- Actual contact events carry material, weight and resolution. Light hits, heavy hits, guards and guard breaks drive different local holds, reactions, small contact marks and original synthesized sound.
- Hitstop pauses the duel and its contact effects, while scenery, interface and cultivation clocks continue. A miss does not fabricate damage or a hit flash. Resource commits and cooldowns retain their original event rules.
- Quiet travel footfalls, grounded defeat settling and the last hero recovery connect fighting to pickup and walking. The production world remains transparent; the video uses a neutral recording mat behind it.

## Review and evidence limits

The final review is based on native-rendered, normal-speed footage, dense temporal image inspection, frame timing and decoded audio measurements. The available observation tools do not supply a continuous audiovisual stream to the reviewer. No claim is made that a human listened to the audio mix or watched it uninterrupted.

The demonstration starts from paused checkpoints earned by deterministic production duels and paid progression. It does not inject health, resources, victories, items or skill levels. Departure, travel, combat, reward collection and return then run through the production host at normal speed. A short edited video may show two separately resumed routes; it is not represented as one uninterrupted new-game session.

## Preserved systems

Manual departure, portal transitions, continuous route deceleration, independent book portrait, ten manuals and flexible loadout, twenty-two meridian nodes, paid practice and heart costs, combat qi and stable-ID cooldowns, three physical weapon basics, swept weapon contact and the six-chapter campaign remain in place. No extra progression systems or platform exports were added for this revision.

Final QA results and source identifiers are recorded separately after the source freeze. Visual acceptance is not inferred from test counts.
