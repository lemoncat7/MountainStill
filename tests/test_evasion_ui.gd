extends SceneTree
## Real equipment/manual callbacks and readable rate/source fields.
const Ink = preload("res://scripts/ink_pages.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://evasion_ui_%d.json" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func press(key: String) -> void:
	check(is_instance_valid(scene.buttons.get(key)), "real button exists: " + key)
	if is_instance_valid(scene.buttons.get(key)): scene.buttons[key].pressed.emit()
func geometry() -> void:
	var controls: Array = []
	for child in scene.drawer.get_children():
		if child is BaseButton:
			check(scene._drawer_rect().encloses(Rect2(child.position, child.size)), "stat and equipment controls stay inside paper")
			controls.append(child)
	for i in range(controls.size()):
		for j in range(i + 1, controls.size()):
			if controls[i] != scene.buttons.evasion_stat and controls[j] != scene.buttons.evasion_stat: continue
			check(not Rect2(controls[i].position, controls[i].size).intersects(Rect2(controls[j].position, controls[j].size)), "distinct controls: " + controls[i].text + " / " + controls[j].text)
func run() -> void:
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.demo = true
	scene.state.new_game()
	scene.state.auto_advance = false
	scene._toggle_drawer("wardrobe")
	press("wardrobe_equipment")
	for width in [1000, 1200, 1360]:
		scene.size = Vector2(width, 320)
		scene._refresh_drawer()
		geometry()
		var hint := str(scene.buttons.evasion_stat.tooltip_text)
		check(hint.contains("5.0%") and hint.contains("0.75%") and hint.contains("15%") and hint.contains("0%"), "new game sheet discloses ready, committed and stagger rates")
		check(hint.contains("基础") and hint.contains("身法") and hint.contains("装备") and hint.contains("经脉"), "all four real source categories disclosed")
		check(hint.contains("零伤害") and hint.contains("格挡减伤") and hint.contains("落空"), "dodge guard and miss meanings are explicit")
	var line1 := "平常闪避 59.2% · 出招 8.88% · 失衡0% · 闪避零伤害 / 格挡减伤"
	var line2 := "基础5.0 + 身法42.2 + 装备5.0 + 经脉7.0 点 · 上限72% · 悬停详解"
	check(Ink.SANS.get_string_size(line1,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x < 493, "maximum legal rate line fits header without ellipsis")
	check(Ink.SANS.get_string_size(line2,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x < 493, "source line fits header without hiding contributions")
	scene.state.realm = 3
	scene.state.technique_levels.petal = 1
	check(scene.state.attune_technique("petal").ok and scene.state.equip_technique("petal", "active").ok, "real slot equips learned movement manual")
	scene.state.gear.inventory.append(scene.state.gear._make_item(1,"weapon_sword","common",1))
	scene.state.gear.inventory.append(scene.state.gear._make_item(2,"feet_boots","common",1))
	check(scene.state.equip_item(1), "sword is really equipped")
	scene.selected_item = 2
	scene.selected_slot = "feet"
	scene._refresh_drawer()
	press("equip_selected")
	check(is_equal_approx(scene.state.stats().evasion_chance,0.44), "real footwear callback updates actual total")
	check(scene.buttons.evasion_stat.tooltip_text.contains("44.0%") and scene.buttons.evasion_stat.tooltip_text.contains("装备 4.0"), "rebuilt tooltip matches equipped boots")
	press("unequip_slot")
	check(is_equal_approx(scene.state.stats().evasion_chance,0.40) and scene.buttons.evasion_stat.tooltip_text.contains("40.0%"), "real removal callback updates rate and tooltip")
	press("wardrobe_technique")
	press("tech_category_movement")
	var row: Dictionary = Ink._technique_selected(scene)
	check(row.id == "petal" and row.movement_active and not row.active, "selected sword manual clearly separates body effect from fan attack")
	check(row.effect.contains("无扇也生效") and row.effect.contains("需持扇"), "manual effect explicitly explains both compatibility rules")
	check(Ink._manual_hint(scene,row).contains("双栏不叠加"), "manual detail explains no duplicate source")
	var before := float(scene.state.stats().evasion_chance)
	scene.encounter_active = true
	scene.encounter_phase = "fight"
	scene.wardrobe_tab = "equipment"
	scene._refresh_drawer()
	press("evasion_stat")
	check(is_equal_approx(before,scene.state.stats().evasion_chance), "stat inspection during combat cannot mutate loadout")
	scene.queue_free()
	await process_frame
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(save_path + suffix)
	print("Evasion UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
