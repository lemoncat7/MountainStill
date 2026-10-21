# Composable manual book

The technique page keeps the large independent portrait on the left and the existing 605-pixel paper area on the right. It does not reframe, pause, move, or redirect the world actor.

## Reading and choosing

- Ten manuals are filtered by overlapping tags: 心法、武技、术法、护体、身法、炼体、辅助功能. 全部 shows every manual. A book may belong to several tags.
- At most three readable rows appear per page. Pagination is bounded; all buttons fit the existing paper at 1000, 1200 and 1360 window widths.
- Row clicks only inspect. Slot buttons explicitly change 心法、武式、主动 or 辅修, according to the selected book's supported slots. Tags do not stand in for slots.
- The page shows current heart and weapon form, active/passive counts, the equipped weapon's innate skill, attunement capacity, simultaneous training capacity, the selected book's rank/cap, compatibility, battle-qi cost, cooldown, effect, next-rank gate, materials and time. The summary tooltip lists all equipped names.
- A mismatched weapon form remains selected, is marked inactive, and never equips a different weapon. Form and active-slot choices are independent. Free basic attacks and the weapon's innate skill remain separate sources.
- Herb/dew gathering, alchemy and cultivation utility remain documented in the authored book effects. Cultivation energy is called 修为灵气 (功德 after the final realm); battle skills use 战斗真气.

## Finite cultivation and heart changes

- 纳入通习 / 收起通习 changes finite attunement occupancy. Shelving preserves all earned ranks; equipped or training books cannot be shelved.
- Training pays the displayed materials once, runs on the real saved training timer, and shows remaining seconds and progress. Completing training never silently equips a slot. Books have individual rank caps, rank realm gates and prerequisites.
- 换修心法 opens a review before any payment. The review shows old/new names, exact material/energy/time costs, stat changes and old/new effects.
- Only 确认代价 · 开始调息 starts the switch. The first-ever selection is also explicitly confirmed. During paid adjustment the old heart remains effective, and further switches are disabled. Active or paused expeditions must be resolved before switching.
- During a live fight, inspection and local demonstration remain available, while training, attunement and every loadout-changing callback are guarded at execution time.

## Portrait previews

All ten previews are local. Cloud arcs, fan petals, orange flame, frost crystals, lightning strokes, shield outlines and healing leaves are distinct. Heart and body books show restrained passive auras without attack motion. Spells use the palm gesture; weapon arts gesture only with an actually compatible weapon. When incompatible, the demonstration shows the book's energy effect without inventing or swapping equipment. Closing the book cancels the local demonstration.

## Stable automation controls

- Open: `wardrobe_technique`
- Filters: `tech_category_all`, `tech_category_heart`, `tech_category_weapon_art`, `tech_category_spell`, `tech_category_defense`, `tech_category_movement`, `tech_category_body`, `tech_category_support`
- Paging: `tech_prev`, `tech_next`
- Inspect the current page's book: `equip_<id>` (legacy key retained; now inspection only)
- Train: `train_technique`; advance actual state time and wait for the training job to finish before expecting a new rank
- Preview: `practice_preview`
- Attunement: `attune_technique`
- Applicable slots: `manual_slot_heart`, `manual_slot_weapon_art`, `manual_slot_active`, `manual_slot_passive`
- Heart review: `confirm_heart_switch`, `cancel_heart_switch`
- Loadout summary: `manual_loadout_summary`

`tests/test_composable_manual_ui.gd` covers filters, pagination and bounds, all ten local previews, non-mutating inspection, timed training, compatibility, independent slot changes, attunement, heart review and adjustment, and live-loadout guards. `test_campaign_ui.gd` and `test_live_loadout_guard.gd` have been updated to use this explicit workflow.

`tests/test_manual_portrait_grip.gd` checks both real weapon textures against alpha-thresholded opaque hulls at 1000/1200/1360 widths, including cast samples. It verifies the hilt follows the exact skinned wrist once, the held handle sits behind the original fingers, and palm spells use a local behind-torso stow. Minimum-width sword previews reduce only gesture amplitude; portrait scale, feet and the world remain fixed.
