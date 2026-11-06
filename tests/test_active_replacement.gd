extends SceneTree
## Synthetic authored loadouts; no natural-play, balance or win-rate claim.
const State = preload("res://scripts/cultivation_state.gd")
const Ink = preload("res://scripts/ink_pages.gd")
const Swap = preload("res://scripts/active_replacement_pages.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://active_replacement_%d.json" % OS.get_process_id()

func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func snapshot(state) -> String:
	var data: Dictionary = state._snapshot(); data.erase("saved_at")
	return JSON.stringify(data)
func other_state(state) -> String:
	var data: Dictionary = state._snapshot()
	for key in ["saved_at", "equipped_actives", "technique"]: data.erase(key)
	return JSON.stringify(data)
func prepare(state, realm: int = 9):
	state.new_game(); state.realm = realm; state.auto_advance = false
	state.herbs = 10000; state.dew = 10000; state.qi = 10000
	state.attuned_techniques.clear()
	for id in ["mist", "breath", "petal", "ember", "barrier", "mending", "body"]:
		state.technique_levels[id] = 1; state.attuned_techniques.append(id)
	state.equipped_heart = "breath"; state.equipped_weapon_art = "mist"
	state.equipped_passives.assign(["body"] if realm >= 3 else [])
	state.equipped_actives.assign(["mist", "barrier"] if realm >= 3 else ["mist"])
func press(key: String):
	var b = scene.buttons.get(key)
	check(is_instance_valid(b) and b is BaseButton, "exists " + key)
	if not is_instance_valid(b): return
	check(not b.disabled, "enabled " + key)
	if not b.disabled: b.pressed.emit()
func inspect(id: String):
	scene.drawer_name = "wardrobe"; scene.drawn_page = "wardrobe"; scene.wardrobe_tab = "technique"
	scene.set_meta("ink_manual_filter", "all")
	var rows: Array = scene.state.technique_rows()
	for i in range(rows.size()):
		if str(rows[i].id) == id:
			scene.set_meta("ink_manual_page", i / Ink.MANUALS_PER_PAGE); break
	Ink._manual_inspect(scene, id)
	scene._refresh_drawer(true)
func chooser(id: String = "mending") -> Dictionary:
	inspect(id); press("manual_slot_active")
	check(Swap.is_open(scene, id), "explicit chooser opens " + id)
	return scene.get_meta(Swap.KEY, {}).duplicate(true)
func geometry(label: String):
	var controls: Array = []
	for child in scene.drawer.get_children():
		if child is BaseButton:
			var rect := Rect2(child.position, child.size)
			check(scene._drawer_rect().encloses(rect), label + " inside paper " + child.text)
			for other in controls:
				if not child.text.begins_with("替下") and child.text != "暂不替换" and not other.text.begins_with("替下") and other.text != "暂不替换": continue
				check(not rect.intersects(Rect2(other.position, other.size)), label + " nonoverlap " + child.text + str(rect) + " / " + other.text + str(Rect2(other.position,other.size)))
			controls.append(child)
func files() -> Array:
	var result: Array = []
	for suffix in ["", ".bak", ".tmp"]:
		result.append(FileAccess.get_file_as_bytes(save_path + suffix) if FileAccess.file_exists(save_path + suffix) else PackedByteArray())
	return result

func run():
	# State API matrices: every authored active; one and two slots; preserve exact
	# position and all unrelated formal state. Wrong-role and repeat rejects are atomic.
	for realm in [1, 9]:
		for id in State.Content.TECHNIQUES:
			for index in range(1 if realm < 3 else 2):
				var s = State.new(); prepare(s, realm)
				var expected: Array = s.equipped_actives.duplicate()
				var before := snapshot(s); var rest := other_state(s)
				var eligible: bool = s._manual_eligible(id) and "active" in State.Content.TECHNIQUES[id].slots and not expected.has(id)
				var result: Dictionary = s.replace_active_technique(id, expected[index], expected)
				check(bool(result.ok) == eligible, "authored eligibility %s realm %d slot %d" % [id, realm, index])
				if eligible:
					var wanted := expected.duplicate(); wanted[index] = id
					check(s.equipped_actives == wanted, "index preserved " + id)
					check(other_state(s) == rest, "unrelated state preserved " + id)
					check(s.stats().active_skills[index].id == id and s.technique == id, "stats and legacy selection refreshed " + id)
					var after := snapshot(s)
					check(not s.replace_active_technique(id, expected[index], expected).ok and snapshot(s) == after, "duplicate atomic " + id)
				else: check(snapshot(s) == before, "failed request wholly unchanged " + id)
	var s = State.new(); prepare(s)
	for row in [{"id":"missing", "old":"mist", "expected":["mist","barrier"]}, {"id":"mending", "old":"missing", "expected":["mist","barrier"]}, {"id":"mending", "old":"mist", "expected":["barrier","mist"]}, {"id":"mending", "old":"mist", "expected":[]}]:
		var before := snapshot(s)
		check(not s.replace_active_technique(row.id, row.old, row.expected).ok and snapshot(s) == before, "invalid/stale input atomic " + str(row))
	s.equipped_actives.assign(["mist"])
	var incomplete := snapshot(s)
	check(not s.replace_active_technique("mending", "mist", ["mist"]).ok and snapshot(s) == incomplete, "partial slots use ordinary equip")
	prepare(s); s._heart_quote = {"token":"synthetic-existing-quote"}
	check(s.replace_active_technique("mending", "mist", ["mist","barrier"]).ok and s._heart_quote.is_empty(), "successful replacement invalidates heart quote")

	# Real host controls plus real isolated save. No autosave/process progression.
	scene = load("res://main.tscn").instantiate(); scene.state.save_path = save_path
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true; prepare(scene.state)
	scene.world_route = ""; scene.encounter_active = false; scene.paused = true
	scene.demo = false; check(scene._save_current(), "baseline persisted")
	var before := snapshot(scene.state); var disk := files()
	var draft := chooser()
	check(snapshot(scene.state) == before and files() == disk, "opening does not save or change state")
	for dimensions in [Vector2i(960, 320), Vector2i(960, 540)]:
		root.min_size = Vector2i(960, 320); root.size = dimensions; scene.strip = dimensions.y == 320
		scene.size = Vector2(dimensions); scene._refresh_drawer(); await process_frame; await process_frame; geometry(str(dimensions))
	var stale_button = scene.buttons.replace_active_0
	var stale_callback: Callable = stale_button.pressed.get_connections()[0].callable
	press("cancel_active_replacement")
	check(not scene.has_meta(Swap.KEY) and Ink._technique_selected(scene).id == "mending", "cancel returns to desired manual")
	stale_callback.call(); Swap.commit(scene, draft, "mist")
	check(snapshot(scene.state) == before and files() == disk, "cancelled and detached callbacks do not save")
	await process_frame; check(not is_instance_valid(stale_button), "cancelled controls freed")
	draft = chooser()
	press("replace_active_1")
	check(scene.state.equipped_actives == ["mist","mending"], "real second-slot button preserves first")
	# Host save may capture layout; compare semantic fields separately.
	check(scene.state.equipped_weapon_art == "mist" and scene.state.equipped_passives == ["body"], "weapon form and passive retained")
	check(scene.state.stats().active_skills[1].id == "mending", "host stats expose chosen skill")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(saved.equipped_actives == ["mist","mending"], "save contains complete replacement, no empty intermediate")
	check(FileAccess.get_file_as_bytes(save_path + ".bak") == disk[0], "success saves exactly once: backup is untouched pre-commit main")
	check(not saved.has(Swap.KEY) and not saved.has("active_replacement_serial"), "chooser metadata excluded from save")
	before = snapshot(scene.state); disk = files(); Swap.commit(scene, draft, "barrier")
	check(snapshot(scene.state) == before and files() == disk, "duplicate committed token cannot save again")

	# Every interruption gets a fresh draft, then invokes the old operation.
	for interrupt in ["loadout", "eligibility", "realm", "fight", "practice", "closing", "update", "tree", "inspect", "filter", "page", "tab", "close", "reset"]:
		scene.demo = true; prepare(scene.state); scene.paused = true; scene.encounter_active = false; scene.encounter_phase = "idle"; scene.closing = false
		scene.set_meta("update_transaction", false); root.process_mode = Node.PROCESS_MODE_ALWAYS
		draft = chooser()
		match interrupt:
			"loadout": scene.state.equipped_actives.assign(["petal", "barrier"])
			"eligibility": scene.state.attuned_techniques.erase("mending")
			"realm": scene.state.realm = 1
			"fight": scene.encounter_active = true; scene.encounter_phase = "fight"
			"practice": check(scene.start_practice("bamboo_sprite"), "practice starts for stale chooser check")
			"closing": scene.closing = true
			"update": scene.set_meta("update_transaction", true)
			"tree": paused = true
			"inspect": Ink._manual_inspect(scene, "barrier")
			"filter": press("tech_category_all")
			"page": press("tech_prev")
			"tab": scene.wardrobe_tab = "equipment"; scene._refresh_drawer()
			"close": scene._close_drawer()
			"reset": scene._reset_presentation()
		before = snapshot(scene.state); disk = files()
		Swap.commit(scene, draft, "mist")
		check(snapshot(scene.state) == before and files() == disk, "interrupted chooser atomic: " + interrupt)
		if interrupt == "practice": scene.end_practice()
		paused = false; scene.closing = false; scene.encounter_active = false; scene.encounter_phase = "idle"; scene.set_meta("update_transaction", false)
		Swap.clear(scene)
	# UI refresh removes impossible drafts before another click. Current state
	# still revalidates independently if a refresh has not happened yet.
	for change in ["capacity_growth", "eligibility", "rank", "already_equipped"]:
		prepare(scene.state, 1 if change == "capacity_growth" else 9)
		draft = chooser("petal" if change == "capacity_growth" else "mending")
		match change:
			"capacity_growth": scene.state.realm = 3
			"eligibility": scene.state.attuned_techniques.erase("mending")
			"rank": scene.state.technique_levels.mending = 0
			"already_equipped": scene.state.equipped_actives.assign(["mending", "barrier"])
		before = snapshot(scene.state); disk = files()
		scene._refresh_drawer()
		check(not scene.has_meta(Swap.KEY), "refresh clears impossible draft " + change)
		Swap.commit(scene,draft,"mist")
		check(snapshot(scene.state) == before and files() == disk, "reconciled stale choice remains atomic " + change)
	prepare(scene.state); draft = chooser(); press("cancel_active_replacement")
	var reopened := chooser()
	before = snapshot(scene.state); Swap.commit(scene,draft,"mist")
	check(snapshot(scene.state) == before and scene.get_meta(Swap.KEY,{}) == reopened, "cancelled token cannot commit after reopening same choice")
	press("cancel_active_replacement")
	# Bounded queue-free lifecycle, real controls, not only direct API calls.
	var baseline_children := 0
	for cycle in range(20):
		prepare(scene.state); scene.demo = true
		draft = chooser()
		var old = scene.buttons.replace_active_0
		press("cancel_active_replacement")
		chooser(); press("replace_active_0")
		await process_frame; await process_frame
		check(not is_instance_valid(old) and not scene.has_meta(Swap.KEY), "cycle frees old controls and draft %d" % cycle)
		if cycle == 0: baseline_children = scene.get_child_count()
		check(scene.get_child_count() == baseline_children, "no host child accumulation %d (actual %d baseline %d)" % [cycle, scene.get_child_count(), baseline_children])
		check(scene.state.equipped_actives == ["mending","barrier"], "cycle exact slots %d" % cycle)
	# Single-slot real chooser and closed/role behavior.
	prepare(scene.state, 1); chooser("petal")
	check(is_instance_valid(scene.buttons.get("replace_active_0")) and not scene.buttons.has("replace_active_1"), "one-slot chooser offers one target")
	press("replace_active_0"); check(scene.state.equipped_actives == ["petal"], "one-slot swap complete")
	inspect("body"); check(scene.buttons.manual_slot_passive.disabled, "unopened passive role unchanged")
	prepare(scene.state); inspect("body"); press("manual_slot_passive")
	check(scene.state.equipped_passives.is_empty() and not scene.has_meta(Swap.KEY), "existing passive removal unchanged")
	scene.queue_free(); await process_frame; await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(save_path + suffix)
	print("Active replacement: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
