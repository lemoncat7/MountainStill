# Bounded pacing comparison

Compared the final side-proportion and frozen guard/evasion `qa/final-regression/encounter-balance.json` reports. No new simulation, balance adjustment, or threshold change was performed.

Support / cloud_guardian takes **42.3868 s**, versus baseline **37.0589 s**, in both seeds: +5.3279 s and 0.3868 s beyond the unchanged 42 s bound.

| Measure | Baseline | Final |
|---|---:|---:|
| Basic actions | 21 | 26 |
| Barrier casts | 3 | 3 |
| Mending casts | 2 | 3 |
| Sword-pierce casts | 4 | 3 |
| Qi spent | 124 | 132 |
| Ending qi | 15.258421 | 20.045286 |
| Damage received | 35 | 58 |
| Healing | 33 | 57 |
| Hero contacts | 29 | 32 |
| Enemy contacts | 31 | 33 |
| Measured melee contacts | 24 | 26 |
| Landed melee contacts | 21 | 23 |
| Poise breaks | 8 | 7 |
| Hero whiffs | 0 | 0 |
| Enemy whiffs | 3 | 3 |
| Ending HP | 108 | 109 |
| Damage dealt | 550 | 550 |

The combat inputs match: duel seed 4186; starting HP 110/112; attack 24; defense 7; enemy definition, equipment, and battle resources. Starting qi is 53.78528 and barrier cooldown is 0.5708 s. Only a noncombat progress field differs in the hero statistics.

The reports support a genuine geometry-related pacing consequence accompanied by a changed defensive/offensive action mix, rather than added whiffs or lost victories. They contain no event timelines or contact coordinates, so this comparison cannot identify the first changed contact or prove the precise causal sequence leading to extra healing and one fewer sword-pierce.

All 180 encounters remain victories. Bosses finishing within 35 seconds remain 50/60 (83.33%) in both reports, so the aggregate failure is inherited. Total failures increase from one to three through the two newly over-bound support/cloud_guardian rows. Do not present the full balance suite as passing.
