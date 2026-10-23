extends SceneTree
## Real paper controls: navigation, bounded layout, next-encounter choices and evidence.
const Insight = preload("res://scripts/combat_insight_pages.gd")
const Ink = preload("res://scripts/ink_pages.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://combat_insight_ui_%d.json" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)

func press(key: String) -> void:
	var button = scene.buttons.get(key)
	check(is_instance_valid(button), "real button exists: " + key)
	if not is_instance_valid(button): return
	check(not button.disabled, "real button enabled: " + key)
	if not button.disabled: button.pressed.emit()

func geometry(label: String) -> void:
	var paper: Rect2 = scene._drawer_rect()
	var controls: Array = []
	for child in scene.drawer.get_children():
		if child is BaseButton and child.visible:
			var rect := Rect2(child.position, child.size)
			check(paper.encloses(rect), "control inside paper: " + label + " / " + child.name)
			for other in controls:
				check(not rect.intersects(Rect2(other.position, other.size)), "no overlapping controls: " + label + " / " + child.name + " " + str(rect) + " / " + other.name + " " + str(Rect2(other.position,other.size)))
			controls.append(child)

func open_insight() -> void:
	scene.wardrobe_tab = "equipment"
	scene.set_meta("combat_insight_open", false)
	if scene.drawer_name != "wardrobe": scene._toggle_drawer("wardrobe")
	else: scene._refresh_drawer()
	press("evasion_stat")

func run() -> void:
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.demo = true
	scene.state.new_game()
	scene.state.auto_advance = false
	var initial_qi: float = scene.state.qi
	var initial_herbs: int = scene.state.herbs
	for width in [960, 1000, 1200, 1440]:
		scene.size = Vector2(width, 540 if width == 960 else 320)
		open_insight()
		check(Insight.is_open(scene) and Insight._view(scene) == "attributes", "header opens attributes")
		geometry("attributes %d" % width)
		var rows: Array = scene.state.combat_stat_breakdown().rows
		check(not rows.is_empty(), "attribute sources available")
		check(scene.buttons.combat_attribute_prev.disabled, "first attribute page bounded")
		for page in range(1, ceili(rows.size() / float(Insight.ATTRIBUTE_PAGE_SIZE))):
			press("combat_attribute_next")
			geometry("attributes %d page %d" % [width, page])
			check(not scene.buttons.combat_attribute_prev.disabled, "previous attribute page available")
		check(scene.buttons.combat_attribute_next.disabled, "last attribute page bounded")
		while not scene.buttons.combat_attribute_prev.disabled: press("combat_attribute_prev")
		for view in ["tactics", "reports", "attributes"]:
			press("combat_view_" + view)
			geometry(view + " %d" % width)
		check(not scene.encounter_active, "browsing does not start combat")
		press("combat_back")
		check(not Insight.is_open(scene) and is_instance_valid(scene.buttons.get("evasion_stat")), "back returns to equipment")
	check(scene.state.qi == initial_qi and scene.state.herbs == initial_herbs, "browsing spends no resources")
	open_insight()
	press("combat_view_tactics")
	var before_stats: Dictionary = scene.state.stats().duplicate(true)
	for id in Insight.TACTICS:
		if not is_instance_valid(scene.buttons.get("combat_tactic_" + id)): press("combat_tactic_next")
		geometry("tactic " + id)
		press("combat_tactic_" + id)
		check(scene.state.combat_tactic == id, "real tactic callback saves " + id)
		check(not scene.encounter_active, "tactic choice does not depart")
	for key in ["attack", "defense", "max_hp", "speed", "combat_qi_max", "combat_qi_regen", "evasion_chance"]:
		check(scene.state.stats()[key] == before_stats[key], "tactics do not grant stats: " + key)
	press("combat_tactic_prev")
	var stale_button = scene.buttons.combat_tactic_assault
	scene.encounter_active = true
	scene.encounter_phase = "fight"
	stale_button.pressed.emit()
	check(scene.state.combat_tactic == "frugal", "stale callback rechecks live combat")
	scene._refresh_drawer()
	for id in Insight.TACTICS:
		if not is_instance_valid(scene.buttons.get("combat_tactic_" + id)): press("combat_tactic_next")
		check(scene.buttons["combat_tactic_" + id].disabled, "combat locks tactic " + id)
	press("combat_view_reports")
	geometry("reports during fight")
	check(scene.buttons.combat_report_prev.disabled and scene.buttons.combat_report_next.disabled, "empty report paging is disabled")
	scene.encounter_active = false
	scene.encounter_phase = "idle"
	var reports: Array = []
	for i in range(5):
		reports.append({"enemy_name": "守灵%d" % i, "stage_name": "青竹关", "outcome": ["victory", "defeat", "retreat"][i % 3], "elapsed": 12.5 + i, "tactic": Insight.TACTICS[i % 4], "damage_dealt": 41, "damage_taken": 12, "healing": 3, "shield_absorbed": 6, "dodges": 2, "guards": 1, "breaks": 1, "qi_spent": 20.5, "skill_casts": {"云岚三叠": 2, "护元诀": 1}, "hero_hp": 91, "hero_max_hp": 100, "hits": 6, "misses": 2, "enemy_dodges": 1, "enemy_guards": 3, "shield_added": 11})
	scene.state.combat_reports = reports
	scene._refresh_drawer()
	geometry("populated report")
	check(scene.buttons.combat_report_skills.tooltip_text.contains("云岚三叠×2"), "full skill list accessible")
	check(scene.buttons.combat_report_title.tooltip_text.contains("我方命中 6 · 落空 2 · 被闪避 1 · 被格挡 3"), "contact evidence accessible")
	check(scene.buttons.combat_report_details.tooltip_text.contains("护盾生成 11 · 实际吸收 6"), "shield granted and absorbed distinguished")
	check(scene.buttons.combat_report_title.tooltip_text.contains("不是出招次数或命中率"), "no misleading hit rate")
	for i in range(4):
		press("combat_report_next")
		geometry("report %d" % (i + 1))
	check(scene.buttons.combat_report_next.disabled, "oldest report bounded")
	for i in range(4): press("combat_report_prev")
	check(scene.buttons.combat_report_prev.disabled, "newest report bounded")
	press("wardrobe_technique")
	check(not Insight.is_open(scene), "another book tab closes insight")
	press("wardrobe_equipment")
	check(not Insight.is_open(scene), "returning equipment does not reopen insight")
	for id in Insight.TACTICS:
		for line in Insight.TACTIC_LINES[id]:
			check(Ink.SANS.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, Insight.BODY_FONT_SIZE).x <= 483, "tactic line fits: " + id)
	for row in scene.state.combat_stat_breakdown().rows:
		var lines: Array[String] = Ink._wrapped_lines(str(row.source), 597, Insight.BODY_FONT_SIZE, 2)
		check(not lines.is_empty() and not lines[-1].ends_with("…"), "complete attribute source fits: " + str(row.label))
	var scale: float = preload("res://scripts/readability_layout.gd").effective_scale(Vector2i(960, 540), 1.5)
	check(Insight.BODY_FONT_SIZE * scale >= 12, "minimum window body text at least 12 pixels")
	check(Insight.NOTE_FONT_SIZE * scale >= 11, "minimum window notes at least 11 pixels")
	check(scene.state.qi == initial_qi and scene.state.herbs == initial_herbs, "all browsing and choices preserve resources")
	scene.queue_free()
	await process_frame
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(save_path + suffix)
	print("Combat insight UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
