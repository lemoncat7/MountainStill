extends RefCounted
## Read-only preparation notes beside the six existing chapter entries.
## Every mechanic refers to a registered enemy rule; hints grant no bonuses.
const Content = preload("res://scripts/cultivation_content.gd")
const Materials = preload("res://scripts/material_registry.gd")
const NOTES := {
	"bamboo_pass": {"identity": "苔兽以冲撞、短扑接震地，重招前先伏身蓄势。", "preparation": "先穿上已有衣冠。云岚剑诀的剑招须持剑；首通青锋剑需亲手装备。", "crafting_goal": "可织短衫，也能炼石淬炼旧物", "recipe_id": "weave_armor"},
	"creek_bridge": {"identity": "石灵守势较重，石壳坚守与露出破绽交替。", "preparation": "青锋破风刺与云岚三叠穿插普攻；归息心法帮助维持本程真气。", "crafting_goal": "通关学琢发簪，补足头饰", "recipe_id": "carve_river_pin"},
	"cloud_slope": {"identity": "灵鹤连啄、翼扫与俯冲交替，身轻善避。", "preparation": "止水可稳住守势，护元能吸伤。先打通此路，再用鹤羽制扇配落英。", "crafting_goal": "通关学扎流云扇，四羽二石", "recipe_id": "bind_cloud_fan"},
	"ember_ruins": {"identity": "炎灵连爆的末击能削弱护甲作用，半血后招式加强。", "preparation": "霜缚拖慢来势，护元抵挡实伤。把前章做出的扇与落英搭配，也可沿用剑。", "crafting_goal": "三枚炼一石，用于原物淬炼", "recipe_id": "refine_route"},
	"moon_marsh": {"identity": "月灵追击连响，后段更重，半血后攻势增强。", "preparation": "回春在受伤时恢复，鸣雷削韧破势。主动各耗真气，留意本程余量。", "crafting_goal": "通关学织月白云衫，五丝三石", "recipe_id": "weave_moon_robe"},
	"summit_gate": {"identity": "镇山守灵护甲厚，金印镇击会削弱格挡减伤。", "preparation": "护元吸伤、落英避招与鸣雷破势各有用途；出发前先比较衣冠与淬炼。", "crafting_goal": "三枚炼一石，温养已用顺手的装备", "recipe_id": "refine_route"},
}

static func entry(id: String) -> Dictionary:
	if not NOTES.has(id) or not Content.STAGES.has(id): return {}
	var stage: Dictionary = Content.STAGES[id]
	var row: Dictionary = NOTES[id].duplicate(true)
	var boss: Dictionary = stage.monsters[-1]
	var material_id := Materials.route_material(String(stage.biome), String(boss.visual_type))
	row.merge({"id": id, "monster_name": String(boss.name), "material_id": material_id,
		"material_name": String(Materials.material(material_id).get("name", ""))})
	return row
