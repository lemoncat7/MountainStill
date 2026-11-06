extends SceneTree
## Real content IDs, legacy aliases and the paused host's cached text/tooltips.
## Synthetic loadouts only; no combat policy, resources or save changes.
const Pages = preload("res://scripts/practice_pages.gd")
const Host = preload("res://scripts/practice_host.gd")
const Content = preload("res://scripts/cultivation_content.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://practice_weapon_requirement_%d.json" % OS.get_process_id()

func _initialize(): call_deferred("run")

func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)

func press(key: String):
	var button = scene.buttons.get(key)
	check(is_instance_valid(button), "real button exists " + key)
	if not is_instance_valid(button): return
	check(not button.disabled, "real button enabled " + key)
	if not button.disabled: button.pressed.emit()

func formal() -> Array:
	var data: Dictionary = scene.state._snapshot(); data.erase("saved_at")
	var disk: Array = []
	for suffix in ["", ".bak", ".tmp"]:
		disk.append(FileAccess.get_file_as_bytes(save_path + suffix) if FileAccess.file_exists(save_path + suffix) else PackedByteArray())
	return [data, disk, scene.state._adventure_rng.state, scene.state._journey_rng.state, scene.state.gear.rng.state]

func combat() -> Array:
	return [scene.duel.battle_resource_snapshot(), scene.duel.combat_report(), scene.duel._rng.state,
		scene.duel._enemy_rng.state, scene.duel._next_skill_index, scene.duel._skill_uses.duplicate(true),
		scene.duel._pending.duplicate(true), scene.duel._lanes.duplicate(true), scene.duel._counter_ready,
		scene.duel._counter_kind, scene.duel._must_basic, scene.duel.elapsed]

func formatter_cases():
	var snapshot := {"qi": 40.0, "max_qi": 40.0, "tactic": "balanced"}
	for pair in [["weapon_sword", "持剑"], ["weapon_fan", "持扇"], ["sword", "持剑"], ["fan", "持扇"],
		["", "相配兵器"], ["weapon_spear", "相配兵器"], ["swordfish", "相配兵器"], [null, "相配兵器"], [17, "相配兵器"]]:
		var row := {"reason": "weapon_mismatch", "required_weapon": pair[0], "name": "测试招式", "qi_cost": 12.0}
		var before := row.duplicate(true)
		var snapshot_before := snapshot.duplicate(true)
		var expected := "兵器不合 · 需" + str(pair[1])
		check(Pages.decision_reason(row, snapshot) == expected, "exact requirement " + str(pair[0]))
		check(Pages.decision_hint(row, snapshot).begins_with("测试招式 · " + expected + "\n"), "tooltip requirement " + str(pair[0]))
		check(row == before and snapshot == snapshot_before, "formatter leaves inputs untouched " + str(pair[0]))
	check(Pages.decision_reason({"reason": "weapon_mismatch"}, snapshot) == "兵器不合 · 需相配兵器", "missing requirement safe fallback")
	check(Pages.decision_reason({"reason": "selected", "required_weapon": "weapon_sword"}, snapshot) == "此刻可选 · 仍须等到实际起手", "compatible reason unchanged")
	check(Pages.decision_reason({"reason": "unknown", "required_weapon": "weapon_fan"}, snapshot) == "当前不可用", "unknown reason unchanged")

func run():
	formatter_cases()
	scene = load("res://main.tscn").instantiate(); scene.state.save_path = save_path
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true; scene.state.new_game(); scene.state.auto_advance = false
	scene.state.realm = 9; scene.state.attuned_techniques.assign(["breath", "mist", "petal"])
	for id in scene.state.attuned_techniques: scene.state.technique_levels[id] = 1
	scene.state.equipped_heart = "breath"; scene.state.equipped_weapon_art = ""
	scene.state.equipped_actives.assign(["mist", "petal"])
	scene.state.gear.inventory.append(scene.state.gear._make_item(1, "weapon_sword", "common", 1))
	scene.state.gear.inventory.append(scene.state.gear._make_item(2, "weapon_fan", "common", 1))
	scene.world_route = ""; scene.encounter_active = false; scene.paused = true
	for weapon in [0, 1, 2]:
		scene.state.gear.unequip_slot("weapon")
		if weapon > 0: scene.state.gear.equip_item(weapon)
		scene.demo = false; check(scene._save_current(), "persist isolated baseline"); scene.demo = true
		var original := formal()
		check(scene.start_practice("bamboo_sprite"), "start real host trial " + str(weapon))
		press("practice_live_pause")
		var frozen := combat()
		press("practice_live_decision")
		check(Host.decision_open(scene), "paused sheet opens")
		for dimensions in [Vector2i(960, 320), Vector2i(960, 540)]:
			root.min_size = Vector2i(960, 320); root.size = dimensions; scene.strip = dimensions.y == 320
			scene.size = Vector2(dimensions); scene._refresh_drawer()
			for frame in range(4): await process_frame
			var snapshot: Dictionary = scene.get_meta("practice_decision_snapshot", {})
			var presentation: Dictionary = scene.get_meta("practice_decision_presentation", {})
			check(snapshot.rows.size() >= 2, "both real active techniques retained")
			for index in range(2):
				var id := "mist" if index == 0 else "petal"
				var required := "weapon_sword" if index == 0 else "weapon_fan"
				var expected := "兵器不合 · 需持剑" if index == 0 else "兵器不合 · 需持扇"
				var row: Dictionary = snapshot.rows[index]
				check(row.id == id and row.required_weapon == required and row.required_weapon == Content.TECHNIQUES[id].required_weapon, "real content requirement reaches snapshot " + id)
				var mismatch: bool = weapon != index + 1
				check((row.reason == "weapon_mismatch") == mismatch, "actual compatibility unchanged " + id)
				if mismatch:
					check(presentation.rows[index].reason == expected, "cached visible requirement " + id + " " + str(dimensions))
					var button = scene.buttons.get("practice_decision_row_%d" % index)
					check(is_instance_valid(button) and button.tooltip_text.contains(expected), "real hotspot requirement " + id)
					check(scene.SANS.get_string_size(expected, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 405, "requirement fits existing reason column")
					check(scene.SANS.get_string_size(str(row.name) + " · " + expected, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 600, "tooltip heading fits existing paper width")
			check(combat() == frozen and formal() == original, "reading and rebuilding preserve battle/save/RNG")
		press("practice_decision_back")
		check(scene.practice_session.status().paused and combat() == frozen, "back preserves same paused battle")
		scene.end_practice()
		check(formal() == original and scene.practice_previous_reports.is_empty(), "cancel restores formal state without reward/report")
		for frame in range(4): await process_frame
	scene.queue_free(); scene = null
	for frame in range(4): await process_frame
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	print("Practice weapon requirement: %d checks, %d failures; real loadouts=3; heights=2" % [checks, failures])
	quit(1 if failures else 0)
