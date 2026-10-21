Revision note: combat scheduling, route continuity, and meridians were revised in v1.3.1. This file preserves the v1.3 campaign design and historical timing. Current behavior and validation are in COMBAT-v1.3.1-QA.md and MERIDIAN-BRANCHES.md.

# MountainStill: first campaign

## Two compatible ways to play

The peaceful sixteen-realm cultivation arc is unchanged: meditation, gathering, brewing, quests and fox journeys can reach 归真 without one combat victory. Its unassisted simulated duration remains approximately 8.55 hours. Battle never starts from idle time, offline simulation, save loading, auto-cultivation or an ending.

The optional active campaign is a finite six-chapter journey, **第一卷 · 山河归心**. The player follows disturbed mountain spirit channels, earns six permanent mountain seals, restores their connection, then returns home for the explicit epilogue. Every route contains two ordinary encounters, a possible mid-route opportunity and one named boss. Completing a route ends that outing; the next one requires another deliberate departure.

## Authored progression

| Chapter | Route | Realm gate | Required previous clear | Boss | Story seal |
|---|---|---:|---|---|---|
| 1 竹影初行 | 青竹关 / bamboo_pass | 0 炼气初期 | None | 青苔兽王 | 青竹印 |
| 2 溪声问路 | 听泉桥 / creek_bridge | 1 炼气中期 | 青竹关 | 镇河石灵 | 听泉印 |
| 3 眠云有信 | 眠云坡 / cloud_slope | 3 筑基初期 | 听泉桥 | 白羽鹤王 | 眠云印 |
| 4 旧炉余温 | 照炉遗墟 / ember_ruins | 6 金丹初期 | 眠云坡 | 炉心炎灵 | 照炉印 |
| 5 月照归途 | 镜月泽 / moon_marsh | 9 元婴初期 | 照炉遗墟 | 镜月玄灵 | 镜月印 |
| 6 天门归心 | 归真天门 / summit_gate | 12 化神初期 | 镜月泽 | 镇山守灵 | 归山印 |

Each chapter contains an authored opening, resolution, next objective and explicit first-clear reward preview. The third chapter reveals that the seals reconnect displaced spirit channels rather than imprisoning enemies. The final guardian recognizes the reunited channels; the story is resolved as soon as all six routes have been cleared. Reaching realm 15 enables the separate home epilogue, **终章 · 山河归心**. Its final scene returns to tea, the fox and a peaceful mountain home. Free play remains available afterward.

## Finite guaranteed progression, unchanged random drops

| First clear | Guaranteed real gear | Qi | Herbs | Dew |
|---|---|---:|---:|---:|
| 青竹关 | Uncommon level-1 青锋剑 | 180 | 40 | 10 |
| 听泉桥 | Uncommon level-3 竹影短衫 | 1,280 | 70 | 20 |
| 眠云坡 | Rare level-6 踏云靴 | 9,900 | 150 | 40 |
| 照炉遗墟 | Rare level-9 竹影下装 | 31,500 | 210 | 55 |
| 镜月泽 | Rare level-12 莲华冠 | 85,800 | 290 | 70 |
| 归真天门 | Epic level-15 流云扇 | 212,000 | 330 | 90 |

These rewards are one-time insight and equipment, not a debug boost or a faster simulation clock. They do not set the realm directly. Qi and herbs still pay the published cost of each ordinary breakthrough. Each package funds the next chapter's realm gate while leaving materials for a choice of technique training, meridians or item enhancement. The summit package funds the three final breakthroughs: their total cost is 201,840 qi and 246 herbs.

Every gear reward uses the equipment ledger's collision-safe instance allocator and canonical stat factory, enters the real inventory and collection, and requires a normal equip action. It never replaces a worn item silently. At full inventory, material or energy capacity, the entire package remains pending and can be claimed after making room. A seal records the actual clear even while its physical reward is pending. No excess material or unique gear is discarded.

Random rewards remain independent on **every defeated monster**:

- Chest: 12%.
- Direct equipment: 3%.
- Conditional equipment rarity: 60% common, 28% uncommon, 10% rare, 2% epic.
- Mid-route opportunity: 18%, checked once between the second enemy and the boss.

The finite package consumes no random number, does not use the ledger's legacy 35% monster roll and does not consume the tutorial chest guarantee. A completely dry adventure random stream is also verified: seed 61 produces zero random chests, zero direct gear and zero opportunities over all six chapters, yet every tested technique path still completes. Replaying a route pays its normal per-monster rewards but never duplicates its seal or first-clear package.

## Six distinct route opportunities

The midway opportunity probability remains 18% and no choice expires. Its saved ID remains `quiet_cairn`; the stage ID reconstructs the canonical scene, so old saves cannot inject new rewards. The two stable action IDs remain `gather_gift` and `read_inscription`.

| Route | Scene | Material choice | Alternative insight |
|---|---|---|---|
| 青竹关 | 石龛留香 | 收下山草: 6 herbs / 2 dew | 参悟旧诀: 40 qi |
| 听泉桥 | 泉眼赠露 | 汲泉携露: 4 herbs / 8 dew | 听泉调息: 80 qi |
| 眠云坡 | 鹤亭旧信 | 收好云中药包: 14 herbs / 6 dew | 读山志行气图: 180 qi |
| 照炉遗墟 | 余火温炉 | 取耐火药草: 24 herbs / 9 dew | 借余火炼心: 720 qi |
| 镜月泽 | 月潭映心 | 收取凝月露: 10 herbs / 24 dew | 照月澄心: 1,800 qi |
| 归真天门 | 天门一盏茶 | 收好归山药材: 24 herbs / 18 dew | 饮茶悟归途: 4,200 qi |

Each has its own description and meaningful resource emphasis: creek and moon gifts are dew-heavy for training/meridians; the ruined furnace offers more alchemy herbs; the summit offers a return-home reserve. Insight becomes merit after realm 15 through the existing energy invariant. Both branches keep exact capacity checks and one-claim semantics; at capacity the choice remains pending. No opportunity is required to finish a chapter or the campaign.

## Cultivation and combat connection

Effective combat stats now include realm progression:

- Attack: 8 + 2 × realm + actual gear attack + 3 × selected mist technique level + opened-meridian attack.
- Defense: floor(realm / 3) + actual gear defense + opened-meridian defense.
- Maximum vitality: 100 + 4 × realm.

Selected technique profiles retain their different attacks, dodges, counters and guards. The selected learned level is supplied in the effective stat snapshot. Equipment, enhancements, acupoints and breakthroughs all affect the next duel through real owned state. Utility technique bonuses and peaceful timing are unchanged.

A lawful deterministic simulation begins with an entirely new character, wins all 18 duels using the production DuelTimeline, equips earned chapter gear, buys mist training and meridians at their normal cost, consumes normal breakthrough costs, and explicitly completes the epilogue. It uses no fabricated inventory, realm setting or injected resources. Battle-only duration is recorded by the test; walking, presentation, exploration and player decision time are additional. This verifies that the active arc needs no hours of idle waiting merely to finish its story.

## Checkpoints, retries and saves

Defeated enemies are the paid checkpoint. `pause_stage(run_id)` and `fail_stage(run_id)` stop the run and retain its ID, defeated count, opportunity state and all awarded loot. Failure additionally records a failure flag. The host can return home, restore vitality on the next manual departure, and call `start_stage()` to retry the next unbeaten enemy. A retry does not reroll a checked opportunity or repay any defeated enemy. Stale, out-of-order, paused or duplicate callbacks are rejected.

`cancel_stage()` is an explicit abandon action and keeps all loot already earned. Selecting another route retains the existing deliberate abandon semantics for compatibility; the UI prevents accidental replacement by browsing route metadata independently while a paused checkpoint exists.

Loading never starts a battle. Offline simulation cannot defeat monsters, create first-clear packages or choose opportunities. The persisted schema version remains **4**. The optional adventure payload adds `campaign_revision`, first-clear claim flags, narrowly scoped legacy route unlocks and ending timestamps. All optional values are type/range checked; reward contents and monster stats always reconstruct from canonical content.

Existing pre-campaign saves retain previously unlocked original routes (the first three only) and valid partial-route checkpoints. Legacy clears retain their counts and create a claimable deterministic package without granting it during loading. New later chapters still require their preceding clear. Saved chapter reward flags cannot claim an uncleared route; malformed ending flags cannot complete a story without all six actual clear records and realm 15. Existing peaceful completion stays separate.

## UI and host interfaces

- `stage_rows()` / `chapter_rows()`: all six canonical routes plus `chapter`, `title`, `summary`, `resolution`, `next_objective`, `prerequisite`, `locked_reason`, `unlocked`, `clears`, `first_clear_reward`, `first_clear_reward_text`, `first_clear_claimed`, `reward_pending`, `token_owned` and `selected`.
- `chapter_status()`: `completed`, `total`, `current_chapter`, `current_stage_id`, `story_resolved`, `epilogue_ready`, `ending_complete`, `ending_title`, `title`, `summary`, `next_objective`, permanent `tokens`, `pending_rewards`, `story_resolved_at`, `finished_at` and independent `peaceful_complete`.
- `claim_chapter_reward(stage_id)`: atomic retry of an earned pending package. Returns `ok`, `reason`, `stage_id`, actual `herbs` / `dew` / `qi`, and `item`; successful results also provide `token` and `text`. Reasons include `not_cleared`, `already_claimed`, `inventory_full` and `resource_full`.
- `complete_home_epilogue()`: explicit idempotent finish with `ok`, `reason`, `title` and `text`. Never pays another reward.
- `start_stage()`: manually creates or resumes the same checkpoint, clears failure status, and returns the current stage status.
- `stage_status()`: existing fields preserved; adds `failed`, `retry_available` and `locked_reason`.
- `pause_stage(run_id = -1)` / `fail_stage(run_id)`: retain checkpoints. Successful pause returns full status. `cancel_stage()` explicitly abandons.
- `defeat_stage_monster(run_id, index)`: existing per-monster gains remain their own values. The final victory additionally returns `first_clear`, `chapter_reward` and, on first clear, `chapter_resolution`. Consumers must display/apply no additional rewards themselves: all returned gains were already applied exactly once.
- `stats()`: adds `max_hp`, `realm_attack`, `realm_defense`, `technique_level`, `story_resolved` and `ending_complete`. Existing `campaign_complete` continues to mean peaceful realm-15 completion.

## Verification

`tests/test_first_campaign.gd` covers six-route content/gates, real-duel new-game completion, ordinary upgrade payments, real item ownership, first-clear and ending idempotence, pause/failure persistence and retry, resource/inventory caps, v4 legacy unlock migration, malformed optional data, and battle-free peaceful completion. It writes isolated test saves only. Existing cultivation, peaceful campaign journey, equipment and enhancement suites remain applicable. Older three-route and flat-combat-stat assertions need corresponding six-route/realm-bonus expectations; no probability or ownership safeguard is relaxed.

## Exact fresh-save recording play plan

Use a new game through its ordinary reset/start UI. Leave **随心修行** enabled and the starting **云岚剑诀 I** selected. Do not seed inventory, give resources, change the realm, or advance the clock faster than real simulation. The tutorial chest is optional; the verified path does not need to open it. Every departure begins at full current maximum vitality. Carry remaining vitality between the three encounters in that outing.

1. Open the adventure book and deliberately depart for **青竹关**. Resolve its two normal enemies, make either offered no-cost opportunity choice, then defeat 青苔兽王. Collect the automatic first-clear package and return home.
2. Open the wardrobe and equip the actual **精良青锋剑** just received. Let normal auto-breakthrough reach 炼气中期. Train 云岚剑诀 once to II; open **气海** once. Depart for 听泉桥.
3. After 听泉桥, equip **精良竹影短衫**. Normal auto-breakthrough reaches 筑基初期. Train 云岚剑诀 to III; open **关元**. Depart for 眠云坡.
4. After 眠云坡, equip **稀有踏云靴**. Reach 金丹初期 through ordinary breakthroughs. Train 云岚剑诀 to IV; open **神阙**. Depart for 照炉遗墟.
5. After 照炉遗墟, equip **稀有竹影下装**. Reach 元婴初期 normally. Train 云岚剑诀 to V; open **膻中**. Depart for 镜月泽.
6. After 镜月泽, equip **稀有莲华冠**. Reach 化神初期 normally. Keep 云岚剑诀 V; open **百会**. Depart for 归真天门.
7. Defeat 镇山守灵. Show the six-seal story resolution. Equip the earned **史诗流云扇** if desired, receive the final insight, let the last three ordinary breakthroughs reach 归真, and open **涌泉** with earned merit if desired.
8. At home, explicitly choose the ready **合印归心** epilogue action. Show **终章 · 山河归心**, the six seals and peaceful return. The campaign ending is not the older realm-only peaceful completion page.

The exact six-route starting builds in the verified mist path are:

| Route | Selected technique | Attack | Defense |
|---|---|---:|---:|
| 青竹关 | 云岚剑诀 I | 11 | 0 |
| 听泉桥 | 云岚剑诀 II | 23 | 0 |
| 眠云坡 | 云岚剑诀 III | 30 | 7 |
| 照炉遗墟 | 云岚剑诀 IV | 39 | 14 |
| 镜月泽 | 云岚剑诀 V | 50 | 22 |
| 归真天门 | 云岚剑诀 V | 58 | 31 |

The production host combat seed is `run_id * 1337 + monster_index * 79 + 17`. `tests/test_campaign_builds.gd` tests that exact seed rule on five fresh earned-state campaigns. It also verifies petal, stillness and ember paths: train the chosen style as soon as its realm gate is available, retain mist until then, equip only the six guaranteed items, and re-check each selected meridian’s current prerequisites and affordability before buying, including independent branches. A fifth tour switches petal → stillness → ember → mist → stillness between successive routes, training only as resources permit. No path obtains a free learned level or fabricated gear. These variants make all four techniques demonstrably viable; the recording can use the simple mist path for the complete story and brief technique inserts if useful.

With the final six-species boss mechanics, battle-only timing is about 3.4–4.8 minutes depending on style (mist 201.4 seconds; petal 265.9; stillness 286.5; ember 240.8; mixed tour 277.5). All five styles complete both the ordinary reward seed and completely dry seed 61. This excludes travel, portals, pauses, book interactions and narration. Record real complete play, then edit repeated travel and menu time for the requested final video; do not present a prefilled save or accelerated clock as natural progression.
