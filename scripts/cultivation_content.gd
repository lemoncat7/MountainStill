class_name CultivationContent
extends RefCounted
## Bounded, offline-first content with an optional finite six-chapter adventure. All durations are simulation seconds.

# One bounded evasion contract shared by the character sheet and combat.
const EVASION_BASE := 0.05
const EVASION_CAP := 0.72
const EVASION_COMMITTED_MULTIPLIER := 0.15
const PETAL_EVASION_PER_RANK := 0.018

const VERSION := 4
const FIRST_MIST_STUDY_HERBS := 6
# Realm numbering expanded once in v3; later schemas must never remap it.
const EXPANDED_REALM_VERSION := 3
const REALM_NAMES := ["炼气初期", "炼气中期", "炼气后期", "筑基初期", "筑基中期", "筑基后期", "金丹初期", "金丹中期", "金丹后期", "元婴初期", "元婴中期", "元婴后期", "化神初期", "化神中期", "化神后期", "归真"]
const QI_RATES := [1.0, 1.35, 1.75, 2.25, 2.85, 3.6, 4.5, 5.6, 7.0, 8.8, 11.0, 13.7, 17.0, 21.0, 26.0, 32.0]
# Meditation durations: 2, 4, 7, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56 min.
# With unassisted gathering the main arc takes about 8.5 hours; optional growth
# and equipment shorten it. No random roll can block a breakthrough.
const QI_COSTS := [120.0, 324.0, 735.0, 1620.0, 2736.0, 4320.0, 6480.0, 9408.0, 13440.0, 19008.0, 26400.0, 36168.0, 48960.0, 65520.0, 87360.0, 0.0]
const HERB_COSTS := [6, 10, 16, 22, 28, 34, 40, 46, 52, 58, 64, 70, 76, 82, 88, 0]
const TECHNIQUE_CATEGORIES := {"heart": "心法", "weapon_art": "兵器功法", "spell": "法术", "defense": "护体", "body": "炼体", "support": "辅助功能"}
const TECHNIQUE_CATEGORY_ORDER := ["heart", "weapon_art", "spell", "defense", "body", "support"]
const TECHNIQUES := {
	"mist": {"attack_module_id": "technique.mist", "tags": ["武技"], "slots": ["weapon_art", "active"], "slot": "weapon_art", "name": "云岚剑诀", "category": "weapon_art", "required_weapon": "weapon_sword", "description": "武式槽持剑时以云岚刺挑普攻；另装主动栏才会穿插云岚三叠。功法槽选用时每重攻击 +3；无剑保留修为加成，剑招暂不生效。", "unlock_realm": 0, "max_level": 6, "rank_realms": [0, 0, 1, 3, 6, 9], "training_seconds": 8.0, "prerequisites": {}, "effect": "剑式普攻 · 三叠耗气12 / 冷却6秒 · 攻击 +3/重", "move": "mist_combo", "qi_cost": 12.0, "cooldown": 6.0, "basic_moves": ["mist_thrust", "mist_lift"], "attack_scale": 1.0},
	"petal": {"attack_module_id": "technique.petal", "tags": ["武技", "身法"], "slots": ["weapon_art", "active"], "slot": "weapon_art", "name": "落英扇诀", "legacy_name": "落英身法", "category": "weapon_art", "required_weapon": "weapon_fan", "description": "装入武式或主动栏即生效身法：首重平常闪避40%，每重再加1.8个百分点，双栏不叠加，持剑或空手也可用。持扇武式才有游扇普攻，持扇主动才会穿插回锋；无扇仅扇招停用。仍保留采集 +12%/重。", "unlock_realm": 1, "max_level": 5, "rank_realms": [1, 1, 3, 6, 9], "training_seconds": 10.0, "prerequisites": {}, "effect": "身法闪避40%起 · 无扇仍生效 · 回锋需扇 / 耗气14", "move": "petal_counter", "qi_cost": 14.0, "cooldown": 8.0, "basic_moves": ["petal_step"], "dodge_chance": 0.40, "attack_scale": 0.92},
	"ember": {"attack_module_id": "technique.ember", "tags": ["术法"], "slots": ["active"], "slot": "active", "name": "照炉炎诀", "legacy_name": "照炉心法", "category": "spell", "description": "旧名「照炉心法」，现归入法术；兵器普攻间穿插双重炎息，发掌时兵器收背。装入主动栏时保留炼丹速度 +15%/重。", "unlock_realm": 4, "max_level": 5, "rank_realms": [4, 4, 6, 9, 12], "training_seconds": 12.0, "prerequisites": {}, "effect": "火焰双击 · 耗气18 / 冷却7秒 · 炼丹 +15%/重", "move": "ember_pulse", "qi_cost": 18.0, "cooldown": 7.0, "attack_scale": 1.13, "effect_style": "fire"},
	"stillness": {"attack_module_id": "technique.stillness", "switch_tier": 2, "switch_style": "guard", "tags": ["心法", "护体"], "slots": ["heart"], "slot": "heart", "name": "止水内功", "category": "heart", "description": "被动护体，基础格挡概率 68%，格挡时承受 42% 伤害，定力 +6 起，每重再加 1。心法槽选用时保留吐纳灵气 +8%/重；不占主动出招。", "unlock_realm": 3, "max_level": 6, "rank_realms": [3, 3, 6, 9, 12, 15], "training_seconds": 12.0, "prerequisites": {}, "effect": "被动护体 · 格挡68% · 定力+6 · 吐纳 +8%/重", "move": "", "qi_cost": 0.0, "cooldown": 0.0, "guard_chance": 0.68, "dodge_chance": 0.04, "guard_multiplier": 0.42, "poise_bonus": 6.0, "effect_style": "water_guard"},
	"breath": {"switch_tier": 1, "switch_style": "flow", "tags": ["心法", "辅助功能"], "slots": ["heart"], "slot": "heart", "name": "归息心法", "category": "heart", "description": "入门行气法，首重增加真气上限 6 点、恢复 0.35/秒；每重再加上限 2 点、恢复 0.05/秒。真气只用于历练技能，与突破用的灵气分开。", "unlock_realm": 0, "max_level": 4, "rank_realms": [0, 1, 3, 6], "training_seconds": 8.0, "prerequisites": {}, "effect": "被动养气 · 真气上限 +6 · 恢复 +0.35/秒", "move": "", "qi_cost": 0.0, "cooldown": 0.0, "combat_qi_max": 6.0, "combat_qi_regen": 0.35, "guard_chance": 0.12, "dodge_chance": 0.05, "guard_multiplier": 0.55, "effect_style": "breath"},
	"frost": {"attack_module_id": "technique.frost", "tags": ["术法", "辅助功能"], "slots": ["active"], "slot": "active", "name": "霜缚诀", "category": "spell", "description": "霜印束住来势，以寒纹命中并短暂拖慢敌人的行动。可装入主动栏，切换仍保留各自冷却。", "unlock_realm": 6, "max_level": 4, "rank_realms": [6, 6, 9, 12], "training_seconds": 16.0, "prerequisites": {"breath": 2}, "training_herbs": 12, "effect": "寒霜缓速 · 耗气16 / 冷却10秒", "move": "frost_seal", "qi_cost": 16.0, "cooldown": 10.0, "effect_style": "frost", "slow_fraction": 0.22, "slow_seconds": 2.8},
	"thunder": {"attack_module_id": "technique.thunder", "tags": ["术法", "武技"], "slots": ["active"], "slot": "active", "name": "鸣雷诀", "category": "spell", "description": "雷纹随掌落下，造成强削韧以震动敌人架势。可与其他招式搭配装入主动栏，各自保留冷却。", "unlock_realm": 9, "max_level": 3, "rank_realms": [9, 12, 15], "training_seconds": 20.0, "prerequisites": {"frost": 1}, "training_herbs": 16, "effect": "落雷破势 · 耗气20 / 冷却12秒", "move": "thunder_strike", "qi_cost": 20.0, "cooldown": 12.0, "effect_style": "thunder", "break_scale": 1.8},
	"barrier": {"attack_module_id": "technique.barrier", "name": "护元诀", "category": "defense", "tags": ["护体", "术法"], "slots": ["active"], "slot": "active", "description": "结起护元屏障，吸收之后实际承受的伤害；屏障耗尽或到时消散。与其他主动招式同栏搭配。", "unlock_realm": 1, "max_level": 5, "rank_realms": [1, 3, 6, 9, 12], "training_seconds": 10.0, "prerequisites": {"breath": 1}, "effect": "护盾吸伤 · 耗气16 / 冷却12秒 · 每重效力 +5%", "move": "barrier_guard", "qi_cost": 16.0, "cooldown": 12.0, "shield_amount": 18.0, "shield_seconds": 5.0, "effect_style": "barrier"},
	"body": {"name": "松骨诀", "category": "body", "tags": ["炼体", "护体"], "slots": ["passive"], "slot": "passive", "description": "被动温养筋骨；第一重气血上限 +20、定力 +4，此后每重再加气血 4、定力 1。筑基初期开启一个辅修位。", "unlock_realm": 3, "max_level": 7, "rank_realms": [3, 3, 6, 6, 9, 12, 15], "training_seconds": 14.0, "prerequisites": {"breath": 1}, "effect": "被动强身 · 气血 +20起 / 定力 +4起", "move": "", "qi_cost": 0.0, "cooldown": 0.0, "max_hp": 20.0, "poise_bonus": 4.0, "effect_style": "body"},
	"mending": {"attack_module_id": "technique.mending", "name": "回春诀", "category": "support", "tags": ["辅助功能", "术法"], "slots": ["active"], "slot": "active", "description": "主动运转回春清息，恢复气血并清去迟缓；满气血且无异常时留住真气，不空放招式。", "unlock_realm": 3, "max_level": 4, "rank_realms": [3, 3, 6, 9], "training_seconds": 16.0, "prerequisites": {"stillness": 1}, "effect": "回春清障 · 耗气18 / 冷却14秒 · 每重效力 +5%", "move": "mending_bloom", "qi_cost": 18.0, "cooldown": 14.0, "heal_amount": 18.0, "effect_style": "mending"},
}
# Battle qi is an encounter resource, separate from cultivation's stored qi.
# Skill cost and cooldown are authored once here; meridian reductions apply at
# runtime. Basic sword/fan/unarmed moves are free and follow real equipment.
const COMBAT_QI_BASE := 40.0
const COMBAT_QI_PER_REALM := 2.0
const COMBAT_QI_LIMIT := 80.0
const COMBAT_QI_REGEN := 2.0
const COMBAT_QI_REGEN_LIMIT := 4.0
const SKILL_COST_REDUCTION_CAP := 0.35
const SKILL_COOLDOWN_REDUCTION_CAP := 0.30
const TECHNIQUE_COOLDOWN_LIMIT := 14.0
const WEAPON_COOLDOWN_LIMIT := 10.0
# Combat consumes these profiles independently of cultivation's established
# utility bonuses. hero_stats.attack already includes mist/gear/meridians.
const COMBAT_PROFILES := {
	"mist": {"name": "云岚剑诀", "description": "兵器普攻间穿插三叠；持剑连锋、持扇借势，空手以指诀发劲。", "attack_scale": 1.0, "dodge_chance": 0.05, "guard_chance": 0.12, "guard_multiplier": 0.55, "moves": ["mist_thrust", "mist_lift", "mist_combo"], "skill_id": "technique_mist", "skill_name": "云岚 · 三叠", "skill_move": "mist_combo", "qi_cost": 12.0, "cooldown": 6.0},
	"petal": {"name": "落英身法", "description": "兵器普攻间穿插闪身回锋，守住破绽再反击。", "attack_scale": 0.92, "dodge_chance": 0.46, "guard_chance": 0.05, "guard_multiplier": 0.65, "moves": ["petal_step", "petal_counter"], "skill_id": "technique_petal", "skill_name": "落英 · 闪身回锋", "skill_move": "petal_counter", "qi_cost": 14.0, "cooldown": 8.0},
	"ember": {"name": "照炉炎诀", "description": "兵器普攻间穿插双重炎息；发掌时兵器收在背后。", "attack_scale": 1.13, "dodge_chance": 0.04, "guard_chance": 0.08, "guard_multiplier": 0.65, "moves": ["ember_palm", "ember_pulse"], "skill_id": "technique_ember", "skill_name": "照炉 · 双重炎息", "skill_move": "ember_pulse", "qi_cost": 18.0, "cooldown": 7.0},
	"stillness": {"name": "止水内功", "description": "兵器普攻间穿插回澜推掌，内息护体稳住架势。", "attack_scale": 0.98, "dodge_chance": 0.04, "guard_chance": 0.68, "guard_multiplier": 0.42, "moves": ["stillness_palm", "stillness_push"], "skill_id": "technique_stillness", "skill_name": "止水 · 回澜推掌", "skill_move": "stillness_push", "qi_cost": 16.0, "cooldown": 9.0},
}

const RECIPES := {
	"qi": {"name": "聚气丹", "description": "立即获得灵气；随境界增长。随心修行会自动服用。", "unlock_realm": 0, "herbs": 3, "dew": 1, "seconds": 20.0},
	"spring": {"name": "回春丹", "description": "采集速度 +50%，持续 5 分钟；重复服用延长时间。", "unlock_realm": 1, "herbs": 5, "dew": 2, "seconds": 30.0},
	"clarity": {"name": "澄心丹", "description": "吐纳灵气 +35%，持续 5 分钟；重复服用延长时间。", "unlock_realm": 3, "herbs": 8, "dew": 3, "seconds": 45.0},
}
const BUFF_SECONDS := 300.0
const BUFF_CAP := 3600.0
const JOURNEYS := {
	"bamboo": {"name": "青竹小径", "description": "灵狐穿过竹影，寻来灵草与山间小物。", "unlock_realm": 0, "seconds": 300.0, "rewards": "灵草 4–8 · 晨露 1–2 · 亲密 +1 · 每 3 游获宝箱", "events": [
		{"text": "小狐循着竹叶上的露光，衔回一叶青竹书签。", "herbs": 4, "dew": 2, "qi": 15.0, "bond": 1, "discovery": "bamboo_leaf"},
		{"text": "松鼠分享了藏在石缝里的灵草。小狐带回一颗圆松果。", "herbs": 8, "dew": 1, "qi": 10.0, "bond": 1, "discovery": "pine_cone"},
		{"text": "小狐在竹亭听了一阵风，带着满爪草香回来。", "herbs": 6, "dew": 1, "qi": 20.0, "bond": 1, "discovery": ""}]},
	"creek": {"name": "听泉溪谷", "description": "沿着溪水走远一些，听见石间的泉声。", "unlock_realm": 3, "seconds": 600.0, "rewards": "灵草 10–16 · 晨露 3–5 · 亲密 +2 · 每 3 游获宝箱", "events": [
		{"text": "溪底的石子映着天光，小狐挑了一枚月纹石。", "herbs": 10, "dew": 5, "qi": 80.0, "bond": 2, "discovery": "moon_pebble"},
		{"text": "萤火引路，旧桥边留着一片会轻鸣的水晶。", "herbs": 16, "dew": 3, "qi": 100.0, "bond": 2, "discovery": "stream_crystal"},
		{"text": "小狐帮白鹭拾回巢枝，换来一篮溪谷灵草。", "herbs": 14, "dew": 4, "qi": 120.0, "bond": 2, "discovery": ""}]},
	"ridge": {"name": "眠云山巅", "description": "云海之上，和灵狐一同收藏远山的回音。", "unlock_realm": 9, "seconds": 1200.0, "rewards": "灵草 24–36 · 晨露 6–10 · 亲密 +3 · 每 3 游获宝箱", "events": [
		{"text": "云缝中飘下一羽雪白的鹤翎，小狐轻轻衔住。", "herbs": 24, "dew": 10, "qi": 400.0, "bond": 3, "discovery": "cloud_feather"},
		{"text": "小狐在废亭遇见一株夜开花，带回星纹花瓣。", "herbs": 36, "dew": 6, "qi": 500.0, "bond": 3, "discovery": "star_petal"},
		{"text": "远山回声像一声问候，小狐带着满袋晨露归来。", "herbs": 30, "dew": 8, "qi": 600.0, "bond": 3, "discovery": ""}]},
}
const DISCOVERIES := {"bamboo_leaf": "青竹书签", "pine_cone": "圆松果", "moon_pebble": "月纹石", "stream_crystal": "鸣泉晶", "cloud_feather": "云鹤翎", "star_petal": "星纹花瓣"}
const QUESTS := [
	{"id": "settle", "name": "一盏清茶", "description": "在山中度过 1 分钟。随心修行会自动吐纳、采集与突破。", "counter": "seconds", "target": 60, "rewards": {"herbs": 3, "dew": 1}},
	{"id": "gather", "name": "识得草木", "description": "累计采得 3 株灵草。手动选择活动会关闭随心修行。", "counter": "gathered", "target": 3, "rewards": {"herbs": 5, "dew": 2}},
	{"id": "first_realm", "name": "气息渐长", "description": "到达炼气中期。突破只有收获，没有失败或损失。", "counter": "realm", "target": 1, "rewards": {"qi": 80.0, "herbs": 6}},
	{"id": "first_chest", "name": "行囊初开", "description": "开启 1 个宝箱。初始宝箱必得装备，可在衣橱穿戴。", "counter": "chests_opened", "target": 1, "rewards": {"herbs": 12, "dew": 3}},
	{"id": "learn", "name": "温故知新", "description": "研习任意功法 1 次。所选功法生效；其他研习等级保留。", "counter": "techniques_trained", "target": 1, "rewards": {"herbs": 8, "dew": 3}},
	{"id": "brew", "name": "炉火初温", "description": "炼成 1 枚丹药。丹药会存入丹囊，不会自动消失。", "counter": "brewed", "target": 1, "rewards": {"herbs": 12, "dew": 4}},
	{"id": "pill", "name": "药香入怀", "description": "服用 1 枚丹药。随心修行也会自动服用聚气丹。", "counter": "pills_used", "target": 1, "rewards": {"qi": 180.0, "herbs": 8}},
	{"id": "fox", "name": "与狐同行", "description": "等待灵狐完成 1 次出游。离线期间也会行进并带回礼物。", "counter": "journeys", "target": 1, "rewards": {"herbs": 18, "dew": 5, "chests": 1}},
	{"id": "golden", "name": "丹心初成", "description": "到达金丹初期，看看一路收藏的草木与旧物。", "counter": "realm", "target": 6, "rewards": {"qi": 800.0, "herbs": 24}},
	{"id": "enhance", "name": "旧物生辉", "description": "温养任意一件装备 1 次。装备最多温养五阶，无失败。", "counter": "enhanced", "target": 1, "rewards": {"herbs": 24, "dew": 8}},
	{"id": "spirit", "name": "山月照心", "description": "到达化神初期。山色依旧，心境已渐宽。", "counter": "realm", "target": 12, "rewards": {"qi": 2400.0, "herbs": 40}},
	{"id": "home", "name": "此心归处", "description": "抵达归真，圆满山居修行篇。六印历练仍可随心继续，之后也能收集、出游与静坐。", "counter": "realm", "target": 15, "rewards": {"herbs": 88, "dew": 18, "chests": 3}},
]

# Each route is a short, finite outing. It never starts from an idle tick.
# Chest and direct equipment rolls are independent and may both succeed.
const STAGE_CHEST_CHANCE := 0.12
const STAGE_EQUIPMENT_CHANCE := 0.03
const OPPORTUNITY_CHANCE := 0.18
const CAMPAIGN_REVISION := 1
const CHAPTER_ORDER := ["bamboo_pass", "creek_bridge", "cloud_slope", "ember_ruins", "moon_marsh", "summit_gate"]
const CAMPAIGN_TITLE := "第一卷 · 山河归心"
const EPILOGUE_TITLE := "终章 · 山河归心"
const EPILOGUE_TEXT := "六枚山印在茶盏旁合为一轮清光。竹林、溪桥、云坡、旧炉、月泽与天门的灵息重新相连，躁动的守灵终于安睡。你推开山居的窗，小狐伏在檐下，远山不再需要守望。走过万重山，归来仍是一盏茶。第一卷完。"
# Fixed first-clear insight funds the next realm threshold through ordinary
# breakthroughs. It is finite, never re-farmable, and independent of drop RNG.
# Reward materials also support a choice of techniques, meridians or upgrades.
# The persisted quiet_cairn ID is stable; stage identity reconstructs these
# canonical authored scenes, labels and bounded outcomes on every load.
const ROUTE_OPPORTUNITIES := {
	"bamboo_pass": {"name": "石龛留香","description": "竹影深处，旧石龛留着一篮山草与一页清心旧诀。草叶尚带晨露，你可以收下山草，也可留步参悟。","choices": [{"id": "gather_gift","name": "收下山草","description": "将竹林灵草与晨露带回药炉。","rewards": {"herbs": 6,"dew": 2}},{"id": "read_inscription","name": "参悟旧诀","description": "循着叶纹读旧诀，气息渐渐澄明。","rewards": {"qi": 40.0}}]},
	"creek_bridge": {"name": "泉眼赠露","description": "旧桥下，一泓被石灵护住的泉眼重新涌出。白鹭留下几株水边草，泉声则像一段尚未读完的口诀。","choices": [{"id": "gather_gift","name": "汲泉携露","description": "多带些晨露回家，供研习与炼丹之用。","rewards": {"herbs": 4,"dew": 8}},{"id": "read_inscription","name": "听泉调息","description": "放下水罐，随泉声理顺内息。","rewards": {"qi": 80.0}}]},
	"cloud_slope": {"name": "鹤亭旧信","description": "风吹开云亭的旧竹函，里面是一包鹤群藏好的药材与一页山志。你可以带走药材，也可把山志中的行气图记在心里。","choices": [{"id": "gather_gift","name": "收好云中药包","description": "灵草与晨露均衡，适合温养装备或继续研习。","rewards": {"herbs": 14,"dew": 6}},{"id": "read_inscription","name": "读山志行气图","description": "依图导引，将一缕云息归入丹田。","rewards": {"qi": 180.0}}]},
	"ember_ruins": {"name": "余火温炉","description": "残炉旁，守炉炎灵留下了一匣耐火药草。炉壁残存的呼吸刻痕仍有温度：带药归家炼丹，或以余温淬炼心神，皆有所得。","choices": [{"id": "gather_gift","name": "取耐火药草","description": "带回草多露少的一匣药材，足够温火炼制数枚丹药。","rewards": {"herbs": 24,"dew": 9}},{"id": "read_inscription","name": "借余火炼心","description": "温养心神，化躁动炉火为澄净灵气。","rewards": {"qi": 720.0}}]},
	"moon_marsh": {"name": "月潭映心","description": "月泽中央的芦苇托着一捧凝月露。水中倒影静静等候：收露可温养经络，观月可辨清心念。此刻没有催促。","choices": [{"id": "gather_gift","name": "收取凝月露","description": "获得露多草少的一份月泽馈赠，留给经脉与温养。","rewards": {"herbs": 10,"dew": 24}},{"id": "read_inscription","name": "照月澄心","description": "让纷乱倒影归一，内息随之清明。","rewards": {"qi": 1800.0}}]},
	"summit_gate": {"name": "天门一盏茶","description": "天门前的小石桌上，一壶山茶仍温着，旁边留有最后一包归山药材。守灵示意你歇一歇：带着药草回家，或喝茶回望来路。","choices": [{"id": "gather_gift","name": "收好归山药材","description": "留一份灵草晨露，回家后继续炼丹、研习与温养。","rewards": {"herbs": 24,"dew": 18}},{"id": "read_inscription","name": "饮茶悟归途","description": "将六程见闻沉入心底；归真后这份感悟化为功德。","rewards": {"qi": 4200.0}}]},
}
const CHAPTERS := {
	"bamboo_pass": {"chapter": 1, "title": "竹影初行", "prerequisite": "", "token": "青竹印", "summary": "山中灵脉忽然失序。循着小狐带回的竹叶，安抚青苔兽王，寻找第一枚山印。", "resolution": "青苔兽王伏下身，将青竹印留在石阶。印中溪声，指向下游听泉桥。", "next_objective": "带着青竹印回家突破炼气中期，再往听泉桥。", "first_clear_reward_text": "青竹印 · 精良青锋剑 · 灵气180 · 灵草40 · 晨露10", "first_clear_reward": {"qi": 180.0, "herbs": 40, "dew": 10, "template_id": "weapon_sword", "rarity": "uncommon", "level": 1}},
	"creek_bridge": {"chapter": 2, "title": "溪声问路", "prerequisite": "bamboo_pass", "token": "听泉印", "summary": "青竹印映出断流的溪脉。渡过两段浅滩，与镇河石灵交手，让泉水重新流向山顶。", "resolution": "镇河石灵让开旧桥，听泉印与青竹印相应。云间传来鹤鸣，第三道灵脉尚未苏醒。", "next_objective": "参悟溪声，突破筑基初期，前往眠云坡寻鹤。", "first_clear_reward_text": "听泉印 · 精良竹影短衫 · 灵气1280 · 灵草70 · 晨露20", "first_clear_reward": {"qi": 1280.0, "herbs": 70, "dew": 20, "template_id": "chest_jade", "rarity": "uncommon", "level": 3}},
	"cloud_slope": {"chapter": 3, "title": "眠云有信", "prerequisite": "creek_bridge", "token": "眠云印", "summary": "白羽鹤王守着一页旧山志。沿眠云坡上行，问清山脉失序的缘由。", "resolution": "鹤王将眠云印与旧山志交给你：山印并非封印敌人，而是相连六处失散的灵息。旧炉余火正在呼唤。", "next_objective": "温养功法与经络，突破金丹初期，进入照炉遗墟。", "first_clear_reward_text": "眠云印 · 稀有踏云靴 · 灵气9900 · 灵草150 · 晨露40", "first_clear_reward": {"qi": 9900.0, "herbs": 150, "dew": 40, "template_id": "feet_boots", "rarity": "rare", "level": 6}},
	"ember_ruins": {"chapter": 4, "title": "旧炉余温", "prerequisite": "cloud_slope", "token": "照炉印", "summary": "照炉遗墟的余火困在断裂的丹炉中。越过守炉炎灵，让失控的火息重回炉心。", "resolution": "炉心炎灵收起火势，照炉印亮起温柔的金红。月泽倒影映出第五道灵脉，仍在等候来人。", "next_objective": "收拢炉火灵息，突破元婴初期，往镜月泽寻最后的倒影。", "first_clear_reward_text": "照炉印 · 稀有竹影下装 · 灵气31500 · 灵草210 · 晨露55", "first_clear_reward": {"qi": 31500.0, "herbs": 210, "dew": 55, "template_id": "legs_jade", "rarity": "rare", "level": 9}},
	"moon_marsh": {"chapter": 5, "title": "月照归途", "prerequisite": "ember_ruins", "token": "镜月印", "summary": "镜月泽中，山与月的倒影迟迟不能重合。拨开迷雾，安抚守着月心的玄灵。", "resolution": "镜月玄灵散去重影，镜月印照见山顶的天门。五处灵息已经相连，只待最后的镇山守灵点头。", "next_objective": "圆融内息，突破化神初期，携五印叩问归真天门。", "first_clear_reward_text": "镜月印 · 稀有莲华冠 · 灵气85800 · 灵草290 · 晨露70", "first_clear_reward": {"qi": 85800.0, "herbs": 290, "dew": 70, "template_id": "head_crown", "rarity": "rare", "level": 12}},
	"summit_gate": {"chapter": 6, "title": "天门归心", "prerequisite": "moon_marsh", "token": "归山印", "summary": "携五枚山印来到归真天门。与守门灵将切磋，向镇山守灵证明六处灵息已重新相连。", "resolution": "镇山守灵垂首，将归山印交到你掌心。六印齐明，群山灵脉复归平静。冒险至此圆满；归家修成归真，写下山居终章。", "next_objective": "六印已齐。回家突破至归真，在山居终章中合印归心。", "first_clear_reward_text": "归山印 · 史诗流云扇 · 灵气212000 · 灵草330 · 晨露90", "first_clear_reward": {"qi": 212000.0, "herbs": 330, "dew": 90, "template_id": "weapon_fan", "rarity": "epic", "level": 15}},
}
const STAGES := {
	"bamboo_pass": {"name": "青竹关", "description": "穿过竹林，遇两只苔兽；岔路石龛偶有奇遇，尽头守着青苔兽王。", "biome": "forest", "unlock_realm": 0, "rewards": "每敌灵草 1 · 晨露 1 · 灵气 8；宝箱 12% / 装备 3% 独立掉落", "reward": {"herbs": 1, "dew": 1, "qi": 8.0}, "monsters": [
		{"id": "bamboo_sprite", "name": "幼苔兽", "visual_type": "moss_beast", "attack_module_id": "enemy.moss_beast", "boss": false, "hp": 90, "attack": 2, "defense": 0},
		{"id": "moss_sprite", "name": "林间苔兽", "visual_type": "moss_beast", "attack_module_id": "enemy.moss_beast", "boss": false, "hp": 105, "attack": 2, "defense": 0},
		{"id": "bamboo_guardian", "name": "青苔兽王", "visual_type": "moss_beast", "attack_module_id": "enemy.moss_beast", "boss": true, "boss_move": "charge", "hp": 220, "attack": 2, "defense": 0}]},
	"creek_bridge": {"name": "听泉桥", "description": "沿溪前行，与两尊石灵交手；听泉歇步后，迎战桥畔镇河石灵。", "biome": "river", "unlock_realm": 1, "rewards": "每敌灵草 2 · 晨露 1 · 灵气 14；宝箱 12% / 装备 3% 独立掉落", "reward": {"herbs": 2, "dew": 1, "qi": 14.0}, "monsters": [
		{"id": "stream_sprite", "name": "浅溪石灵", "visual_type": "river_stone", "attack_module_id": "enemy.river_stone", "boss": false, "hp": 190, "attack": 3, "defense": 1},
		{"id": "pebble_sprite", "name": "渡口石灵", "visual_type": "river_stone", "attack_module_id": "enemy.river_stone", "boss": false, "hp": 210, "attack": 4, "defense": 1},
		{"id": "bridge_guardian", "name": "镇河石灵", "visual_type": "river_stone", "attack_module_id": "enemy.river_stone", "boss": true, "boss_move": "sweep", "hp": 500, "attack": 3, "defense": 1}]},
	"cloud_slope": {"name": "眠云坡", "description": "沿云坡渐上，与两只灵鹤切磋；云亭偶留机缘，山巅白羽鹤王静候。", "biome": "cloud", "unlock_realm": 3, "rewards": "每敌灵草 3 · 晨露 2 · 灵气 24；宝箱 12% / 装备 3% 独立掉落", "reward": {"herbs": 3, "dew": 2, "qi": 24.0}, "monsters": [
		{"id": "cloud_sprite", "name": "流云灵鹤", "visual_type": "cloud_crane", "attack_module_id": "enemy.cloud_crane", "boss": false, "hp": 240, "attack": 8, "defense": 2},
		{"id": "ridge_sprite", "name": "山岚灵鹤", "visual_type": "cloud_crane", "attack_module_id": "enemy.cloud_crane", "boss": false, "hp": 245, "attack": 9, "defense": 2},
		# Its evasive aerial bodywork already extends effective durability.
		# Keep the agile boss below the stone guardian's raw vitality budget;
		# retain the full attack rhythm, evasion, armor and three move families.
		{"id": "cloud_guardian", "name": "白羽鹤王", "visual_type": "cloud_crane", "attack_module_id": "enemy.cloud_crane", "boss": true, "boss_move": "burst", "hp": 450, "attack": 9, "defense": 2}]},

	"ember_ruins": {"name": "照炉遗墟", "description": "越过残炉与金红余烬，安抚两名守炉炎灵，重整炉心炎灵守护的火脉。", "biome": "ember", "unlock_realm": 6, "rewards": "每敌灵草6 · 晨露3 · 灵气120；宝箱12% / 装备3%独立掉落", "reward": {"herbs": 6, "dew": 3, "qi": 120.0}, "monsters": [
		{"id": "ember_spark", "name": "余烬炎灵", "visual_type": "ember_guardian", "attack_module_id": "enemy.ember_guardian", "boss": false, "hp": 250, "attack": 12, "defense": 4},
		{"id": "kiln_keeper", "name": "守炉炎灵", "visual_type": "ember_guardian", "attack_module_id": "enemy.ember_guardian", "boss": false, "hp": 290, "attack": 13, "defense": 4},
		{"id": "furnace_heart", "name": "炉心炎灵", "visual_type": "ember_guardian", "attack_module_id": "enemy.ember_guardian", "boss": true, "boss_move": "burst", "hp": 625, "attack": 12, "defense": 5}]},
	"moon_marsh": {"name": "镜月泽", "description": "穿行银蓝芦苇与沉静月潭，拨开两团月影，迎战倒影中的镜月玄灵。", "biome": "moon", "unlock_realm": 9, "rewards": "每敌灵草8 · 晨露4 · 灵气300；宝箱12% / 装备3%独立掉落", "reward": {"herbs": 8, "dew": 4, "qi": 300.0}, "monsters": [
		{"id": "reed_moon", "name": "苇间月灵", "visual_type": "moon_wisp", "attack_module_id": "enemy.moon_wisp", "boss": false, "hp": 420, "attack": 17, "defense": 6},
		{"id": "mist_reflection", "name": "迷雾月灵", "visual_type": "moon_wisp", "attack_module_id": "enemy.moon_wisp", "boss": false, "hp": 430, "attack": 18, "defense": 6},
		{"id": "moon_mirror", "name": "镜月玄灵", "visual_type": "moon_wisp", "attack_module_id": "enemy.moon_wisp", "boss": true, "boss_move": "sweep", "hp": 960, "attack": 19, "defense": 7}]},
	"summit_gate": {"name": "归真天门", "description": "沿金云石阶登临天门，与两位守门灵将切磋，再与镇山守灵完成最后一场问心。", "biome": "summit", "unlock_realm": 12, "rewards": "每敌灵草12 · 晨露5 · 灵气800；宝箱12% / 装备3%独立掉落", "reward": {"herbs": 12, "dew": 5, "qi": 800.0}, "monsters": [
		{"id": "gate_sentinel", "name": "叩门灵将", "visual_type": "summit_keeper", "attack_module_id": "enemy.summit_keeper", "boss": false, "hp": 460, "attack": 22, "defense": 8},
		{"id": "cloud_sentinel", "name": "承云灵将", "visual_type": "summit_keeper", "attack_module_id": "enemy.summit_keeper", "boss": false, "hp": 495, "attack": 24, "defense": 8},
		{"id": "mountain_warden", "name": "镇山守灵", "visual_type": "summit_keeper", "attack_module_id": "enemy.summit_keeper", "boss": true, "boss_move": "charge", "hp": 800, "attack": 24, "defense": 22}]},
}

# The first six are the exact legacy v4 prefix. Never reorder this list for migration.
const LEGACY_ACUPOINT_IDS := ["qihai", "guanyuan", "shenque", "shanzhong", "baihui", "yongquan"]
const MERIDIAN_REVISION := 1
const MERIDIAN_BRANCH_ORDER := ["central", "edge", "ward", "flow", "quiet"]
const MERIDIAN_BRANCHES := {
	"central": {
		"name": "任督",
		"title": "任督 · 根基绵长",
		"description": "旧六穴原位保留，吐纳与攻防渐进。气海贯通后，四条支脉可各自选择。",
		"style": "根基 · 吐纳 · 草露",
		"color": "74866d"
	},
	"edge": {
		"name": "劲锋",
		"title": "劲锋 · 破势连锋",
		"description": "增强削韧并提快出手，合谷节省技能真气；破开架势后衔接追击。",
		"style": "破势 · 连锋 · 节奏",
		"color": "a17448"
	},
	"ward": {
		"name": "镇岳",
		"title": "镇岳 · 守中有进",
		"description": "提升定力与格挡，间使加快战中回气；减少收势空隙，受压时稳住招式。",
		"style": "定力 · 格挡 · 收势",
		"color": "668579"
	},
	"flow": {
		"name": "游风",
		"title": "游风 · 避实击隙",
		"description": "增强闪避与由防守赢得的反击，悬钟缩短技能冷却。反击须真正避开来招。",
		"style": "闪避 · 反击 · 轻身",
		"color": "68859a"
	},
	"quiet": {
		"name": "归藏",
		"title": "归藏 · 山居养息",
		"description": "温养吐纳、采药与炼丹，命门扩充战斗真气。无需交锋也能修满，不影响突破资格。",
		"style": "吐纳 · 草露 · 炉火",
		"color": "8b7c9a"
	}
}

const ACUPOINTS := [
	{"id": "qihai", "name": "气海", "description": "气息沉入丹田，吐纳渐趋绵长。", "effect": "吐纳 +5%", "unlock_realm": 0, "cost_qi": 30.0, "cost_herbs": 3, "cost_dew": 1, "bonuses": {"qi_rate": 0.05}, "position": {"x": 0.5, "y": 0.62}, "branch": "central", "prerequisites": [], "map_position": {"x": 42, "y": 139}},
	{"id": "guanyuan", "name": "关元", "description": "温养根基，步履稳健，采露更轻盈。", "effect": "防御 +1 · 采集 +4%", "unlock_realm": 0, "cost_qi": 60.0, "cost_herbs": 5, "cost_dew": 2, "bonuses": {"defense": 1, "gather": 0.04}, "position": {"x": 0.5, "y": 0.69}, "branch": "central", "prerequisites": ["qihai"], "map_position": {"x": 120, "y": 139}},
	{"id": "shenque", "name": "神阙", "description": "内息循行，温炉时更能掌握火候。", "effect": "炼丹 +6%", "unlock_realm": 1, "cost_qi": 120.0, "cost_herbs": 8, "cost_dew": 3, "bonuses": {"brew": 0.06}, "position": {"x": 0.5, "y": 0.55}, "branch": "central", "prerequisites": ["guanyuan"], "map_position": {"x": 198, "y": 139}},
	{"id": "shanzhong", "name": "膻中", "description": "胸中清气舒展，剑意也随之通明。", "effect": "攻击 +2 · 吐纳 +3%", "unlock_realm": 3, "cost_qi": 360.0, "cost_herbs": 16, "cost_dew": 5, "bonuses": {"attack": 2, "qi_rate": 0.03}, "position": {"x": 0.5, "y": 0.36}, "branch": "central", "prerequisites": ["shenque"], "map_position": {"x": 198, "y": 220}},
	{"id": "baihui", "name": "百会", "description": "山月照顶，心神愈发澄明。", "effect": "攻击 +2 · 吐纳 +5%", "unlock_realm": 6, "cost_qi": 900.0, "cost_herbs": 28, "cost_dew": 8, "bonuses": {"attack": 2, "qi_rate": 0.05}, "position": {"x": 0.5, "y": 0.06}, "branch": "central", "prerequisites": ["shanzhong"], "map_position": {"x": 120, "y": 220}},
	{"id": "yongquan", "name": "涌泉", "description": "足下生泉，周身气脉圆融贯通。", "effect": "防御 +2 · 采集 +8% · 炼丹 +6%", "unlock_realm": 9, "cost_qi": 2400.0, "cost_herbs": 48, "cost_dew": 12, "bonuses": {"defense": 2, "gather": 0.08, "brew": 0.06}, "position": {"x": 0.43, "y": 0.95}, "branch": "central", "prerequisites": ["baihui"], "map_position": {"x": 42, "y": 220}},
	{"id": "shangyang", "name": "商阳", "branch": "edge", "prerequisites": ["qihai"], "unlock_realm": 0, "cost_qi": 45.0, "cost_herbs": 4, "cost_dew": 1, "bonuses": {"break_bonus": 0.08}, "effect": "削韧 +8%", "description": "指端凝锋，命中时更易动摇对手架势。", "map_position": {"x": 120, "y": 129}},
	{"id": "hegu", "name": "合谷", "branch": "edge", "prerequisites": ["shangyang"], "unlock_realm": 1, "cost_qi": 100.0, "cost_herbs": 7, "cost_dew": 2, "bonuses": {"combat_haste": 0.04, "skill_cost_reduction": 0.06}, "effect": "出招 +4% · 技能耗气 -6%", "description": "真气贯掌，前摇与衔接更轻捷，主动招式少耗真气。", "map_position": {"x": 47, "y": 180}},
	{"id": "quchi", "name": "曲池", "branch": "edge", "prerequisites": ["shangyang"], "unlock_realm": 3, "cost_qi": 280.0, "cost_herbs": 12, "cost_dew": 4, "bonuses": {"break_bonus": 0.1}, "effect": "削韧 +10%", "description": "沉劲循臂，掌与剑的每次接触更能破势。", "map_position": {"x": 193, "y": 180}},
	{"id": "jianjing", "name": "肩井", "branch": "edge", "prerequisites": ["hegu", "quchi"], "unlock_realm": 6, "cost_qi": 820.0, "cost_herbs": 24, "cost_dew": 7, "bonuses": {"counter_bonus": 0.1}, "effect": "得势反击伤害 +10%", "description": "轻快与沉劲汇合，在破势或防守后把握反击。", "map_position": {"x": 120, "y": 231}},
	{"id": "lieque", "name": "列缺", "branch": "ward", "prerequisites": ["qihai"], "unlock_realm": 0, "cost_qi": 45.0, "cost_herbs": 4, "cost_dew": 1, "bonuses": {"poise_bonus": 4}, "effect": "定力上限 +4", "description": "稳住架势，需要更多削韧才会被打断。", "map_position": {"x": 120, "y": 129}},
	{"id": "neiguan", "name": "内关", "branch": "ward", "prerequisites": ["lieque"], "unlock_realm": 1, "cost_qi": 100.0, "cost_herbs": 7, "cost_dew": 2, "bonuses": {"guard_bonus": 0.04}, "effect": "格挡概率 +4 个百分点", "description": "守住中门，格挡会真实减少来袭伤害。", "map_position": {"x": 47, "y": 180}},
	{"id": "jianshi", "name": "间使", "branch": "ward", "prerequisites": ["lieque"], "unlock_realm": 3, "cost_qi": 280.0, "cost_herbs": 12, "cost_dew": 4, "bonuses": {"recovery_bonus": 0.04, "combat_qi_regen": 0.25}, "effect": "收势 -4% · 真气恢复 +0.25/秒", "description": "吐息收招，少留空隙；活动历练中恢复真气更快。", "map_position": {"x": 193, "y": 180}},
	{"id": "daling", "name": "大陵", "branch": "ward", "prerequisites": ["neiguan", "jianshi"], "unlock_realm": 9, "cost_qi": 1800.0, "cost_herbs": 38, "cost_dew": 10, "bonuses": {"poise_bonus": 6, "guard_bonus": 0.04}, "effect": "定力 +6 · 格挡 +4 个百分点", "description": "定力与护体相合，受压时也能稳守再进。", "map_position": {"x": 120, "y": 231}},
	{"id": "taixi", "name": "太溪", "branch": "flow", "prerequisites": ["qihai"], "unlock_realm": 1, "cost_qi": 90.0, "cost_herbs": 6, "cost_dew": 2, "bonuses": {"dodge_bonus": 0.03}, "effect": "闪避概率 +3 个百分点", "description": "侧身借步，真正闪过的接触不受伤害。", "map_position": {"x": 120, "y": 129}},
	{"id": "zhaohai", "name": "照海", "branch": "flow", "prerequisites": ["taixi"], "unlock_realm": 3, "cost_qi": 260.0, "cost_herbs": 12, "cost_dew": 4, "bonuses": {"counter_bonus": 0.08}, "effect": "得势反击伤害 +8%", "description": "避开来招后，借对手空隙回身追击。", "map_position": {"x": 47, "y": 180}},
	{"id": "xuanzhong", "name": "悬钟", "branch": "flow", "prerequisites": ["taixi"], "unlock_realm": 6, "cost_qi": 720.0, "cost_herbs": 22, "cost_dew": 6, "bonuses": {"combat_haste": 0.04, "skill_cooldown_reduction": 0.08}, "effect": "出招 +4% · 技能冷却 -8%", "description": "周身轻灵，起势与连段更快接上，功法与兵器招式更早可用。", "map_position": {"x": 193, "y": 180}},
	{"id": "fengchi", "name": "风池", "branch": "flow", "prerequisites": ["zhaohai", "xuanzhong"], "unlock_realm": 12, "cost_qi": 3000.0, "cost_herbs": 44, "cost_dew": 13, "bonuses": {"dodge_bonus": 0.04, "recovery_bonus": 0.04}, "effect": "闪避 +4 个百分点 · 收势 -4%", "description": "轻身与回锋相融，进退之间不失连贯。", "map_position": {"x": 120, "y": 231}},
	{"id": "laogong", "name": "劳宫", "branch": "quiet", "prerequisites": ["qihai"], "unlock_realm": 0, "cost_qi": 40.0, "cost_herbs": 3, "cost_dew": 1, "bonuses": {"brew": 0.04}, "effect": "炼丹速度 +4%", "description": "掌心温热，控火更稳，不增加每炉耗材。", "map_position": {"x": 120, "y": 129}},
	{"id": "zhongwan", "name": "中脘", "branch": "quiet", "prerequisites": ["laogong"], "unlock_realm": 1, "cost_qi": 90.0, "cost_herbs": 6, "cost_dew": 2, "bonuses": {"qi_rate": 0.03}, "effect": "吐纳灵气 +3%", "description": "调息归中，静坐时多积一缕清气。", "map_position": {"x": 47, "y": 180}},
	{"id": "zusanli", "name": "足三里", "branch": "quiet", "prerequisites": ["laogong"], "unlock_realm": 3, "cost_qi": 240.0, "cost_herbs": 11, "cost_dew": 4, "bonuses": {"gather": 0.05}, "effect": "草露采集速度 +5%", "description": "山路步履从容，采草与凝露同得助益。", "map_position": {"x": 193, "y": 180}},
	{"id": "mingmen", "name": "命门", "branch": "quiet", "prerequisites": ["zhongwan", "zusanli"], "unlock_realm": 9, "cost_qi": 1600.0, "cost_herbs": 34, "cost_dew": 10, "bonuses": {"qi_rate": 0.04, "brew": 0.04, "combat_qi_max": 8.0}, "effect": "吐纳/炼丹 +4% · 真气上限 +8", "description": "炉火与内息互养，增厚战斗气海，山居也有圆满归处。", "map_position": {"x": 120, "y": 231}},
]


static func evasion_breakdown(base: float, movement_rate: float, equipment_bonus: float, meridian_bonus: float) -> Dictionary:
	# Movement replaces the base stance odds, never adds a second evade roll.
	base = clampf(base if is_finite(base) else EVASION_BASE, 0.0, 1.0)
	var movement := maxf(0.0, movement_rate - base) if is_finite(movement_rate) else 0.0
	var equipment := maxf(0.0, equipment_bonus) if is_finite(equipment_bonus) else 0.0
	var meridian := maxf(0.0, meridian_bonus) if is_finite(meridian_bonus) else 0.0
	var raw := base + movement + equipment + meridian
	var chance := clampf(raw, 0.0, EVASION_CAP)
	return {"base": base, "movement": movement, "equipment": equipment, "meridian": meridian,
		"raw": raw, "chance": chance, "cap": EVASION_CAP,
		"committed_chance": chance * EVASION_COMMITTED_MULTIPLIER}


static func evasion_for_phase(chance: float, phase: String) -> float:
	var bounded := clampf(chance if is_finite(chance) else 0.0, 0.0, EVASION_CAP)
	if phase == "stagger": return 0.0
	return bounded * EVASION_COMMITTED_MULTIPLIER if phase in ["strike", "contact"] else bounded
