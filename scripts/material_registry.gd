class_name MaterialRegistry
extends RefCounted
## Trusted, finite, data-only crafting catalog. Validated once, then cached.
## Save files carry IDs and counts, never scripts, texture paths or item stats.
const Equipment = preload("res://scripts/equipment_ledger.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const MAX_STACK := 9999
const TREASURE_CHANCE := 0.01
const MATERIALS := {
	"spirit_shard": {"icon": "crystal", "name": "灵息碎屑", "rarity": "common", "source": "六章守灵", "use": "三枚合成一枚淬炼石", "color": "92aca4"},
	"moss_fiber": {"icon": "leaf", "name": "青苔灵纤", "rarity": "common", "source": "青竹关 · 苔兽", "use": "制造青锋剑、竹影短衫，或合成淬炼石", "color": "849c66"},
	"river_ore": {"icon": "ore", "name": "溪纹灵矿", "rarity": "common", "source": "听泉桥 · 石灵", "use": "制清竹发簪，或三枚炼成一枚淬炼石", "color": "809eae"},
	"cloud_feather": {"icon": "feather", "name": "流云灵羽", "rarity": "common", "source": "眠云坡 · 灵鹤", "use": "扎制流云扇，或三枚炼成一枚淬炼石", "color": "bfcac8"},
	"ember_cinder": {"icon": "cinder", "name": "余火晶砂", "rarity": "common", "source": "照炉遗墟 · 炎灵", "use": "三枚合成一枚淬炼石", "color": "c29062"},
	"moon_thread": {"icon": "thread", "name": "凝月丝", "rarity": "common", "source": "镜月泽 · 月灵", "use": "织月白云衫，或三枚炼成一枚淬炼石", "color": "a1a3c8"},
	"summit_jade": {"icon": "crystal", "name": "镇山玉屑", "rarity": "common", "source": "归真天门 · 守灵", "use": "三枚合成一枚淬炼石", "color": "c0aa70"},
	"refinement_stone": {"icon": "ore", "name": "淬炼石", "rarity": "uncommon", "source": "材料合成", "use": "制造装备或强化原有装备至 +5", "color": "b89761"},
	"spirit_jade": {"icon": "crystal", "name": "灵髓玉", "rarity": "rare", "source": "搜尸独立 1% 概率，无保底", "use": "一枚合成三枚淬炼石", "color": "b4a1cb"},
}
const ROUTES := {
	"forest": {"species": "moss_beast", "material_id": "moss_fiber"},
	"river": {"species": "river_stone", "material_id": "river_ore"},
	"cloud": {"species": "cloud_crane", "material_id": "cloud_feather"},
	"ember": {"species": "ember_guardian", "material_id": "ember_cinder"},
	"moon": {"species": "moon_wisp", "material_id": "moon_thread"},
	"summit": {"species": "summit_keeper", "material_id": "summit_jade"},
}
const RECIPE_ORDER := ["refine_stone", "refine_route", "forge_sword", "weave_armor", "carve_river_pin", "bind_cloud_fan", "weave_moon_robe"]
const RECIPES := {
	"refine_stone": {"name": "凝炼灵息", "kind": "combine", "description": "三枚灵息碎屑凝成一枚淬炼石。必定成功。", "materials": {"spirit_shard": 3}, "output_materials": {"refinement_stone": 1}},
	"refine_route": {"name": "炼化山材", "kind": "combine", "description": "三枚同种山材炼成一石。亲选灵髓玉才可一玉炼三石；不会自动改用别的材料。", "materials": {}, "output_materials": {"refinement_stone": 1}, "alternatives": ["moss_fiber", "river_ore", "cloud_feather", "ember_cinder", "moon_thread", "summit_jade", "spirit_jade"]},
	"forge_sword": {"name": "铸造青锋剑", "kind": "manufacture", "description": "精良兵器，等级随当前境界确定。收入行囊后亲手装备。", "materials": {"moss_fiber": 2, "refinement_stone": 2}, "template_id": "weapon_sword", "rarity": "uncommon"},
	"weave_armor": {"name": "织造竹影短衫", "kind": "manufacture", "description": "精良上衣，等级随当前境界确定。收入行囊后亲手装备。", "materials": {"moss_fiber": 3, "refinement_stone": 1}, "template_id": "chest_jade", "rarity": "uncommon"},
	"carve_river_pin": {"name": "琢制清竹发簪", "kind": "manufacture", "description": "听泉桥通关后识得琢玉法。补足头饰，守势与吐纳并修；成物需亲手穿戴。", "unlock_stage": "creek_bridge", "materials": {"river_ore": 4, "refinement_stone": 1}, "template_id": "head_pin", "rarity": "uncommon"},
	"bind_cloud_fan": {"name": "扎制流云扇", "kind": "manufacture", "description": "眠云坡通关后学会扎扇。持扇可用回风扇；搭配落英扇诀可施展游扇与回锋。", "unlock_stage": "cloud_slope", "materials": {"cloud_feather": 4, "refinement_stone": 2}, "template_id": "weapon_fan", "rarity": "uncommon"},
	"weave_moon_robe": {"name": "织造月白云衫", "kind": "manufacture", "description": "镜月泽通关后领悟月丝织法。稀有上衣，换下旧衫前可比较攻御，原物仍保留。", "unlock_stage": "moon_marsh", "materials": {"moon_thread": 5, "refinement_stone": 3}, "template_id": "chest_blue", "rarity": "rare"},
}
static var _materials: Dictionary = {}
static var _recipes: Dictionary = {}
static var _validated := false
static var _errors: Array[String] = []

static func _prepare() -> void:
	if _validated: return
	_validated = true
	for id in MATERIALS:
		var row: Dictionary = MATERIALS[id]
		if not valid_id(id) or not row.get("name") is String or String(row.name).is_empty():
			_errors.append("invalid material: " + str(id))
			continue
		_materials[id] = row.duplicate(true)
		_materials[id].id = id
		_materials[id].max_stack = MAX_STACK
	for id in RECIPE_ORDER:
		var row: Dictionary = RECIPES[id]
		var valid: bool = valid_id(id) and row.get("name") is String and row.get("description") is String and row.get("kind") in ["combine", "manufacture"]
		if row.has("unlock_stage"):
			valid = valid and row.unlock_stage is String and Content.STAGES.has(row.unlock_stage)
		if row.has("template_id"):
			valid = valid and row.template_id is String and Equipment.TEMPLATES.has(row.template_id) and row.get("rarity") in Equipment.RARITIES
		for key in ["materials", "output_materials"]:
			for material_id in row.get(key, {}):
				valid = valid and _materials.has(material_id) and int(row[key][material_id]) > 0 and int(row[key][material_id]) <= MAX_STACK
		for material_id in row.get("alternatives", []): valid = valid and _materials.has(material_id)
		if valid:
			_recipes[id] = row.duplicate(true)
			_recipes[id].id = id
		else: _errors.append("invalid recipe: " + id)
	for route in ROUTES:
		if not _materials.has(ROUTES[route].material_id): _errors.append("invalid route: " + route)

static func valid_id(value: Variant) -> bool:
	if not value is String or value.length() < 1 or value.length() > 48: return false
	for code in value.to_utf8_buffer():
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95: return false
	return true

static func has_material(id: String) -> bool:
	_prepare()
	return _materials.has(id)

static func material(id: String) -> Dictionary:
	_prepare()
	return _materials.get(id, {}).duplicate(true)

static func material_ids() -> Array:
	_prepare()
	return _materials.keys()

static func recipe(id: String) -> Dictionary:
	_prepare()
	return _recipes.get(id, {}).duplicate(true)

static func validation_errors() -> Array[String]:
	_prepare()
	return _errors.duplicate()

static func route_material(biome: String, species: String) -> String:
	_prepare()
	var row: Dictionary = ROUTES.get(biome, {})
	return String(row.get("material_id", "")) if String(row.get("species", "")) == species else ""
