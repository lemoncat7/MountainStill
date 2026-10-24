extends SceneTree
## Same host/save across all cycles. Only weak references escape capture();
## shared registry, Scripts and its pure-pose caches are intentionally excluded.
const SETTLE_FRAMES := 4
var scene
var checks := 0
var failures := 0
var retained_for_negative_control: RefCounted
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func snapshot() -> String:
	var data: Dictionary = scene.state._snapshot()
	data.erase("saved_at")
	return JSON.stringify(data)
func add_weak(out: Dictionary, label: String, value):
	if value != null: out.refs[label] = weakref(value)
func capture() -> Dictionary:
	var out := {"refs": {}, "controls": [scene.practice_controls.get_instance_id()]}
	add_weak(out, "session", scene.practice_session)
	add_weak(out, "duel", scene.duel)
	for field in ["_base_module", "_form_module", "_enemy_module"]:
		add_weak(out, field, scene.duel.get(field))
	for lane in scene.duel._skill_modules:
		add_weak(out, "skill:" + str(lane), scene.duel._skill_modules[lane])
	for child in scene.practice_controls.get_children():
		out.controls.append(child.get_instance_id())
	check(out.refs.has("_base_module") and out.refs.has("_enemy_module"), "live bound providers captured")
	return out
func survivors(witness: Dictionary) -> Array:
	var result: Array = []
	for label in witness.refs:
		if witness.refs[label].get_ref() != null: result.append(label)
	for id in witness.controls:
		if is_instance_id_valid(id): result.append("control:" + str(id))
	return result
func settle():
	for i in range(SETTLE_FRAMES): await process_frame
func restored(formal: WeakRef, formal_id: int, before: String, paused: bool, x: float):
	check(formal.get_ref() != null and scene.duel.get_instance_id() == formal_id, "formal Duel alive and restored")
	check(scene.practice_session == null and scene.practice_snapshot.is_empty(), "host trial aliases cleared")
	check(scene.paused == paused and scene.character_x == x, "formal pause and position restored")
	check(snapshot() == before, "entire formal snapshot unchanged except saved_at")
	check(scene.drawer_name == "wardrobe" and scene.drawn_page == "wardrobe" and scene.wardrobe_tab == "equipment", "return navigation restored")
	check(scene.get_meta("combat_insight_open", false) and scene.get_meta("combat_insight_view", "") == "enemies", "enemy book restored")
	check(not scene.buttons.garden.disabled and not scene.desktop.desired_passthrough, "formal navigation interactive")
func run():
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = "user://practice_object_lifetimes.json"
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true
	scene.state.new_game() # Exactly once; never reset the host/save between cycles.
	scene.world_route = ""; scene.encounter_active = false; scene.state.stage_run = {}
	scene.state.gear.inventory = [scene.state.gear._make_item(1, "weapon_sword", "common", 1), scene.state.gear._make_item(2, "weapon_fan", "common", 1)]
	var formal: WeakRef = weakref(scene.duel)
	var formal_id: int = scene.duel.get_instance_id()
	var x: float = scene.character_x
	var cycles := 0
	for style in ["sword", "fan", "unarmed"]:
		if style == "unarmed": scene.state.unequip_slot("weapon")
		else: scene.state.equip_item(1 if style == "sword" else 2)
		check(scene._attack_style() == style, "fixture actual style " + style)
		for enemy in ["bamboo_sprite", "bamboo_guardian"]:
			for paused in [false, true]:
				scene.paused = paused
				var before := snapshot()
				check(scene.start_practice(enemy), "start " + style + "/" + enemy + "/" + str(paused))
				check(scene.duel.weapon_style == style, "real trial style")
				var completed := capture()
				for tick in range(1400):
					if scene.practice_session.status().finished: break
					scene._process(.1)
				check(scene.practice_session.status().finished, "bounded natural completion")
				check(snapshot() == before, "formal snapshot after completion")
				check(scene.start_practice(enemy), "repeat finished trial on same host")
				await settle()
				check(survivors(completed).is_empty(), "completed trial released: " + str(survivors(completed)))
				var cancelled := capture()
				scene._process(.1)
				# Independently exercise trial pause as well as formal paused state.
				if paused:
					scene.toggle_practice_pause()
					cancelled.controls.append_array(capture().controls)
				check(scene.practice_session.status().active, "early cancel is active")
				check(scene.practice_session.status().paused == paused, "trial pause state verified")
				scene.end_practice()
				await settle()
				check(survivors(cancelled).is_empty(), "cancelled trial released: " + str(survivors(cancelled)))
				restored(formal, formal_id, before, paused, x)
				cycles += 1
				print("PRACTICE_LIFETIME_CASE %s %s paused=%s CHECKED" % [style, enemy, paused])
	# Test-only negative control uses precisely the same survivor oracle.
	var before := snapshot()
	check(scene.start_practice("bamboo_sprite"), "negative control start")
	var negative := capture()
	retained_for_negative_control = scene.practice_session
	scene.end_practice(); await settle()
	var held := survivors(negative)
	check(held.has("session") and held.has("duel") and held.has("_base_module"), "oracle detects deliberately retained session/duel/provider")
	if held.has("session") and held.has("duel") and held.has("_base_module"):
		print("PRACTICE_LIFETIME_NEGATIVE_DETECTED " + str(held))
	retained_for_negative_control = null
	await settle()
	check(survivors(negative).is_empty(), "negative control releases after test reference cleared")
	restored(formal, formal_id, before, scene.paused, x)
	scene.queue_free(); scene = null; await settle()
	check(formal.get_ref() == null, "formal Duel released only after host teardown")
	print("PRACTICE_LIFETIME_RESULT cycles=%d checks=%d failures=%d" % [cycles, checks, failures])
	quit(1 if failures else 0)
