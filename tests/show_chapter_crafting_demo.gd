extends SceneTree
## Native render from a checkpoint earned by prepare_chapter_crafting_demo.gd.
## Directed production UI buttons only; no inventory, damage or timing fixtures.
const Sans = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
const Plan = preload("res://tests/campaign_build_plan.gd")
class AuditDuel extends "res://scripts/duel_timeline.gd":
	var observed_events: Array[Dictionary] = []
	func advance(delta: float) -> Array[Dictionary]:
		var result := super.advance(delta)
		observed_events.append_array(result)
		return result
var scene
var output := "/tmp/chapter-crafting-demo"
var checkpoint := "/tmp/chapter-crafting-checkpoints/before-crafting.json"
var metadata: Dictionary
var actions: Array = []
var events: Array = []
var captures: Dictionary = {}
var initial: Dictionary = {}
var final_state: Dictionary = {}
var clock := 0.0
var step := 0
var failed := false
var finished := false
var crafted_id := -1
var banner: Label
var detail: Label
var search_seen := false
var claim_seen := false
func _initialize() -> void: call_deferred("start")
func start() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--checkpoint="): checkpoint = arg.trim_prefix("--checkpoint=")
	DirAccess.make_dir_recursive_absolute(output)
	metadata = Plan.measurement_metadata()
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = "user://chapter_craft_native_demo_only.json"
	root.add_child(scene)
	await process_frame
	scene._reset_presentation()
	scene.state.save_path = checkpoint
	var loaded: Dictionary = scene.state.load_game()
	if not loaded.get("loaded", false): fail("earned checkpoint unavailable"); return
	scene.state.save_path = "user://chapter_craft_native_demo_only.json"
	scene.state.settings.paused = false; scene.paused = false
	scene.demo = true; scene.get_window().size = Vector2i(1200, 320); scene.size = Vector2(1200, 320)
	scene.get_window().transparent_bg = false; scene.strip = true; scene.desktop.transparent_enabled = true
	scene.show_combat_move_labels = true
	RenderingServer.set_default_clear_color(Color("#e8e7df"))
	scene.duel = AuditDuel.new()
	banner = Label.new(); banner.position = Vector2(18, 3); banner.add_theme_font_override("font", Sans); banner.add_theme_font_size_override("font_size", 11); banner.add_theme_color_override("font_color", Color("#354e43")); banner.mouse_filter = Control.MOUSE_FILTER_IGNORE; scene.add_child(banner)
	detail = Label.new(); detail.position = Vector2(18, 20); detail.add_theme_font_override("font", Sans); detail.add_theme_font_size_override("font_size", 10); detail.add_theme_color_override("font_color", Color("#506356")); detail.mouse_filter = Control.MOUSE_FILTER_IGNORE; scene.add_child(detail)
	banner.text = "真实新档所得 · 三章搜寻 → 百工制扇 → 穿戴淬炼 → 下一章实战"
	detail.text = "展示从实际九战所得存档继续；未注入材料、装备或功法，普通稀有掉落无保底。"
	initial = snap_state()
	scene.wardrobe_tab = "expedition"; scene.set_meta("ink_stage_id", "cloud_slope"); scene.set_meta("ink_stage_page", 0)
	scene._toggle_drawer("wardrobe"); scene._refresh_drawer()
func press(id: String) -> void:
	var button = scene.buttons.get(id)
	if not is_instance_valid(button) or button.disabled: fail("Unavailable control " + id); return
	actions.append({"time": clock, "button": id, "before": snap_state()})
	button.pressed.emit()
	actions[-1].after = snap_state()
func capture(id: String) -> void:
	if captures.has(id): return
	captures[id] = clock
	# The existing last-drawn frame is the page the player just inspected.
	# Capture it before the next directed button changes the page.
	root.get_texture().get_image().save_png(output.path_join(id + ".png"))
func snap_state() -> Dictionary:
	return {"materials": scene.state.materials.to_dict(), "gear": scene.state.gear.to_dict(), "stats": scene.state.stats(), "realm": scene.state.realm, "victories": scene.state.total_victories, "chapter": scene.state.stage_status(), "manual": scene.state.equipped_weapon_art, "actives": scene.state.equipped_actives.duplicate()}
func _process(delta: float) -> bool:
	if finished or not is_instance_valid(scene) or initial.is_empty(): return false
	clock += delta
	for event in scene.duel.observed_events:
		var copy: Dictionary = event.duplicate(true); copy.capture_time = clock; events.append(copy)
	scene.duel.observed_events.clear()
	if step == 0 and clock >= 2.0: press("stage_cloud_slope"); step = 1
	elif step == 1 and clock >= 3.0: press("chapter_guide"); step = 2
	elif step == 2 and clock >= 5.5: capture("chapter-guide"); press("chapter_recipe"); step = 3
	elif step == 3 and clock >= 8.0:
		capture("fan-ingredients-before")
		press("craft_prev"); press("craft_recipe_refine_stone"); step = 4
	elif step == 4 and clock >= 10.0: press("craft_selected"); step = 5
	elif step == 5 and clock >= 11.5: press("craft_selected"); step = 6
	elif step == 6 and clock >= 13.0: press("craft_selected"); capture("three-earned-stones"); step = 7
	elif step == 7 and clock >= 14.5: press("craft_next"); press("craft_recipe_bind_cloud_fan"); step = 8
	elif step == 8 and clock >= 17.0: capture("fan-cost-and-comparison"); press("craft_selected"); crafted_id = scene.selected_item; step = 9
	elif step == 9 and clock >= 19.0: capture("owned-fan-not-equipped"); press("craft_to_equipment"); step = 10
	elif step == 10 and clock >= 21.0: press("equip_selected"); step = 11
	elif step == 11 and clock >= 23.0: capture("crafted-fan-equipped"); press("enhance_item"); step = 12
	elif step == 12 and clock >= 25.0:
		capture("same-fan-strengthened")
		banner.text = "实际制成流云扇 +1 · 落英武式 / 主动回锋 · 照炉遗墟原生敌人"
		detail.text = "四枚云羽、两枚淬炼石制扇；余下一石淬炼原物。接下来手动出发，真气与技能冷却真实结算。"
		scene.wardrobe_tab = "expedition"; scene.set_meta("ink_stage_page", 1); scene._refresh_drawer(); step = 13
	elif step == 13 and clock >= 27.0: press("stage_ember_ruins"); step = 14
	elif step == 14 and clock >= 29.0: press("depart_stage"); scene._close_drawer(); step = 15
	elif step == 15:
		if scene.encounter_phase == "fight" and scene.duel.elapsed > 3.0: capture("crafted-fan-live-combat")
		if scene.encounter_phase == "pickup":
			if scene.pickup_collect_started >= 0.0 and scene.pickup_claimed_at < 0.0 and float(scene.pickup_status.get("search_seconds", 0.0)) > 0.65:
				search_seen = true; capture("next-chapter-real-search")
			if scene.pickup_claimed_at >= 0.0:
				claim_seen = true
				if scene.encounter_phase_age - scene.pickup_claimed_at > 1.0:
					capture("next-chapter-materials-earned"); final_state = snap_state(); step = 16; scene._retreat_encounter()
		elif not scene.encounter_active and clock > 32.0: fail("new chapter ended before expected searched victory")
	elif step == 16 and not scene.encounter_active:
		finish()
	if clock > 105.0: fail("native recording exceeded expected gameplay window")
	return false
func fail(label: String) -> void:
	failed = true; push_error(label); finish()
func finish() -> void:
	if finished: return
	finished = true
	var same_source := metadata == Plan.measurement_metadata()
	if not same_source: failed = true
	if not search_seen or not claim_seen: failed = true
	var paid_moves: Dictionary = {}; var basics := 0
	for event in events:
		if str(event.get("type", "")) == "turn_started" and str(event.get("actor", "")) == "hero":
			if float(event.get("qi_cost", 0.0)) > 0.0: paid_moves[str(event.get("skill_id", event.get("move", "")))] = true
			else: basics += 1
	var result := {"failed": failed, "seconds": clock, "source_frozen": same_source, "metadata": metadata, "initial": initial, "after_search": final_state, "crafted_id": crafted_id, "events": events, "actions": actions, "captures": captures, "basic_count": basics, "paid_moves": paid_moves, "search_seen": search_seen, "claim_seen": claim_seen, "note": "Normal-speed native Godot render. Starting checkpoint earned from new game through nine real native-stat fights, durable two-second searches and lawful paid preparation. The recording presses production UI controls, then plays the next chapter normally; no damage, HP, speed, inventory or drop fixtures. Earlier preparation is omitted from the short film and preserved in companion provenance."}
	var file := FileAccess.open(output.path_join("chapter-crafting-demo.json"), FileAccess.WRITE); file.store_string(JSON.stringify(plain(result), "\t")); file.close()
	print("CHAPTER_CRAFTING_DEMO_DONE seconds=%.4f failed=%s" % [clock, failed])
	if is_instance_valid(scene): scene.queue_free(); scene = null
	await process_frame; await process_frame
	quit(1 if failed else 0)
func plain(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			if str(key) in ["pose_provider", "strike_provider"] or typeof(value[key]) == TYPE_OBJECT: continue
			result[key] = plain(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			if typeof(item) != TYPE_OBJECT: result.append(plain(item))
		return result
	return value
