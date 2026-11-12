extends SceneTree
## Real Viewport dispatch across equipment comparison navigation.
const Host = preload("res://scripts/practice_host.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://equipment_focus_%d.json" % OS.get_process_id()
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func formal() -> Array:
	var data: Dictionary = scene.state._snapshot(); data.erase("saved_at")
	return [data, scene.state._adventure_rng.state, scene.state._journey_rng.state, scene.state.gear.rng.state]
func settle():
	if scene.drawer_tween: scene.drawer_tween.kill()
	if scene.content_tween: scene.content_tween.kill()
	if not scene.drawer_name.is_empty():
		scene.paper_reveal = 1.0; scene.content_alpha = 1.0; scene.drawer_alpha = 1.0
		scene.content_offset = 0.0; scene._sync_drawer_visuals()
	await process_frame; await process_frame
func event(code: Key, pressed: bool, echo := false):
	var key := InputEventKey.new()
	key.keycode = code; key.pressed = pressed; key.echo = echo
	root.push_input(key, true)
	await process_frame
func tap(code: Key):
	await event(code, true); await event(code, false)
func focused(key: String, label: String):
	var button = scene.buttons.get(key)
	check(is_instance_valid(button) and root.gui_get_focus_owner() == button and not button.disabled and button.is_visible_in_tree() and button.focus_mode != Control.FOCUS_NONE, label)
func run():
	scene = load("res://main.tscn").instantiate(); scene.state.save_path = save_path
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true; scene.state.new_game(); scene.state.auto_advance = false
	scene.world_route = ""; scene.encounter_active = false; scene.state.stage_run = {}
	var sword: int = scene.state.gear.add_item_spec({"template_id":"weapon_sword","rarity":"common","level":1}).item.id
	var fan: int = scene.state.gear.add_item_spec({"template_id":"weapon_fan","rarity":"rare","level":3}).item.id
	scene.state.equip_item(sword); scene.selected_slot = "weapon"; scene.selected_item = fan
	scene.wardrobe_tab = "equipment"; scene._toggle_drawer("wardrobe"); await settle()
	var before := formal()
	scene.buttons.compare_selected.grab_focus()
	await tap(KEY_ENTER); await settle(); focused("comparison_back", "enter comparison keeps safe keyboard focus")
	check(formal() == before, "opening is read only")
	var pages: int = ceili(scene.get_meta("equipment_comparison_rows").size() / 2.0)
	for page in range(1, pages):
		scene.buttons.comparison_next.grab_focus(); await tap(KEY_ENTER); await settle()
		focused("comparison_prev" if page == pages - 1 else "comparison_next", "next focus survives page %d" % page)
	for page in range(pages - 2, -1, -1):
		scene.buttons.comparison_prev.grab_focus(); await tap(KEY_ENTER); await settle()
		focused("comparison_next" if page == 0 else "comparison_prev", "previous focus survives page %d" % page)
	check(formal() == before, "paging is read only")
	scene.buttons.comparison_back.grab_focus(); await tap(KEY_ENTER); await settle()
	focused("compare_selected", "return focuses comparison entry without equipping")
	check(formal() == before, "return is read only")
	scene.buttons.compare_selected.grab_focus(); await tap(KEY_ENTER); await settle()
	scene.buttons.comparison_equip.grab_focus(); await tap(KEY_ENTER); await settle()
	check(scene.state.gear.equipped.weapon == fan, "explicit equip changes selected slot")
	focused("comparison_back", "completed equip focuses safe return instead of disabled action")
	scene.buttons.comparison_back.grab_focus(); await tap(KEY_ENTER); await settle(); focused("compare_selected", "return after equip remains keyboard navigable")
	# Mouse/unfocused activation must not introduce keyboard focus.
	root.gui_release_focus(); scene.buttons.compare_selected.pressed.emit(); await settle()
	check(root.gui_get_focus_owner() == null, "unfocused opening does not steal focus")
	scene.buttons.comparison_back.pressed.emit(); await settle()
	check(root.gui_get_focus_owner() == null, "unfocused return does not steal focus")
	# Newer focus takes precedence while the leaf is rebuilding.
	scene.buttons.compare_selected.grab_focus(); await tap(KEY_ENTER)
	scene.buttons.settings.grab_focus(); await settle(); focused("settings", "newer focus wins")
	scene.queue_free(); await process_frame; await process_frame
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(save_path + suffix)
	print("Equipment comparison focus UI: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
