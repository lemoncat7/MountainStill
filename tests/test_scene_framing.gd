extends SceneTree
## Independent closeup regressions. Uses isolated saves and real input routing;
## no desktop automation, player save, or native passthrough activation is needed.
## Run: godot --headless --path . --script tests/test_scene_framing.gd

const Desktop = preload("res://scripts/desktop_mode.gd")
const HOTSPOTS = ["wardrobe", "alchemy", "practice", "garden", "companion"]
var scene
var checks := 0
var failures := 0
var save_path := "user://scene_framing_%d.json" % OS.get_process_id()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func advance(seconds: float) -> void:
	# Drive the host and its UI tweens deterministically, including interrupted ones.
	for i in range(ceili(seconds * 60.0)):
		for tween in [scene.drawer_tween, scene.content_tween]:
			if tween != null and tween.is_valid():
				tween.pause()
				tween.custom_step(1.0 / 60.0)
		scene._process(1.0 / 60.0)

func close_page() -> void:
	scene._close_drawer()
	advance(.85)

func resize_to(width: int) -> void:
	root.size = Vector2i(width, 320)
	scene.size = Vector2(width, 320)
	scene._resized()
	scene._sync_character_preview(0.0)
	scene._update_hotspots()

func reset_world(activity: String, paused_value: bool) -> void:
	scene.state.new_game()
	scene.state.auto_advance = false
	scene.state.activity = activity
	scene.state.herbs = 12
	scene.state.dew = 8
	scene.paused = paused_value
	scene.state.settings.paused = paused_value
	scene.character_x = 520.0
	scene.character_y = 230.0
	scene.meditation_amount = 1.0 if activity == "meditate" else 0.0
	scene.meditation_settle = .5 if activity == "meditate" else 0.0
	scene.meditation_clock = 0.0
	scene.practice_time = 0.0
	scene.encounter_active = false
	scene.cast_blend = 0.0
	scene.walker = scene.CharacterWalk.new()

func world_signature() -> Array:
	return [scene.character_x, scene.character_y, scene.meditation_amount,
		scene.meditation_clock, scene.meditation_settle, scene.practice_time,
		scene.encounter_active, scene.cast_blend, scene.paused,
		scene.state.activity, scene.state.auto_advance, scene.state.expedition_auto,
		scene.state.qi, scene.state.herbs, scene.state.dew, scene.state.pills,
		scene.state.lifetime_seconds, scene.state.gear.to_dict()]

func key_event(code: int, pressed_value: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed_value
	Input.parse_input_event(event)

func mouse_event(point: Vector2, pressed_value: bool) -> void:
	point = root.get_final_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed_value
	Input.parse_input_event(event)

func check_world_and_preview(label: String) -> void:
	check(scene._scene_camera_transform().is_equal_approx(Transform2D.IDENTITY), label + ": world camera is identity")
	check(is_equal_approx(scene.rendered_stage_scale, 1.0), label + ": world scale is unchanged")
	var preview: Control = scene.character_preview
	check(preview.get_parent() == scene and preview != scene.drawer, label + ": separate preview canvas")
	check(preview.mouse_filter == Control.MOUSE_FILTER_IGNORE and preview.clip_contents, label + ": preview does not own world input")
	if preview.visible and scene._preview_stage_active():
		check(preview.get_rect().end.x <= scene._drawer_rect().position.x - 10.0, label + ": preview clears right book")
		check(Rect2(Vector2.ZERO, scene.size).encloses(preview.get_rect()), label + ": preview remains in viewport")
		for weapon in ["", "sword", "fan"]:
			var scale_value: float = preview._character_scale(weapon)
			var feet: Vector2 = preview._feet_position(scale_value, weapon)
			check(scale_value > 1.5, label + ": genuine enlarged closeup " + weapon)
			check(feet.x - 38.0 * scale_value >= 11.9, label + ": left silhouette inset " + weapon)
			var extent := 69.0 if weapon == "fan" else (56.0 if weapon == "sword" else 38.0)
			check(feet.x + extent * scale_value <= preview.size.x - 11.9, label + ": weapon clears paper " + weapon)

func check_hotspots_and_passthrough(label: String) -> void:
	var regions: Array = scene._interactive_regions()
	check(regions.size() == HOTSPOTS.size() + 2, label + ": original world regions plus the two dismissible guide controls retained")
	for key in ["guide_note", "guide_dismiss"]:
		check(regions.has(scene.buttons[key].get_rect()), label + ": guide input remains reachable " + key)
	for i in range(HOTSPOTS.size()):
		var name: String = HOTSPOTS[i]
		var button: Control = scene.buttons[name]
		var expected: Rect2 = button.get_meta("scene_rect")
		if name == "wardrobe":
			expected = Rect2(Vector2(scene._world_x(scene.character_x) - 46.0,
				scene._world_y(scene.character_y + (16 if scene._diorama_active() else 0)) - 142.0), Vector2(95, 144))
		check(button.get_rect().is_equal_approx(expected), label + ": untransformed hotspot " + name)
		check(regions[i].is_equal_approx(expected), label + ": passthrough matches hotspot " + name)
		check(not button.tooltip_text.is_empty() and button.get_tooltip(button.size * .5) == button.tooltip_text,
			label + ": tooltip belongs to current hotspot " + name)
	for dpi in [1.0, 1.5, 2.0]:
		var transform_value := Transform2D(0.0, Vector2.ONE * dpi, 0.0, Vector2.ZERO)
		var polygon := Desktop._build_passthrough_polygon(scene.size * dpi, transform_value,
			Rect2(0, 0, scene.size.x, 50), regions)
		check(not polygon.is_empty() and not Geometry2D.triangulate_polygon(polygon).is_empty(), label + ": valid native input polygon at DPI " + str(dpi))
		for region: Rect2 in regions:
			var clipped := region.intersection(Rect2(Vector2.ZERO, scene.size))
			if clipped.has_area():
				check(Geometry2D.is_point_in_polygon(transform_value * clipped.get_center(), polygon), label + ": native input preserves world target")

func run() -> void:
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = save_path
	root.add_child(scene)
	await process_frame
	scene.demo = true
	scene.set_process(false)
	resize_to(1200)
	# Opening any page must leave the same simulation as its closed equivalent.
	for activity in ["meditate", "gather", "brew"]:
		for paused_value in [false, true]:
			close_page()
			reset_world(activity, paused_value)
			advance(1.0)
			var baseline: Array = world_signature()
			for page in ["wardrobe", "alchemy", "practice", "settings"]:
				close_page()
				reset_world(activity, paused_value)
				scene._toggle_drawer(page)
				advance(1.0)
				check(world_signature() == baseline, "Page-independent simulation: %s/%s/%s" % [activity, paused_value, page])
				check_world_and_preview("Simulation " + page)
	close_page()
	reset_world("meditate", true)
	# Local casting stays local even when a paused world encounter already exists.
	scene.encounter_active = true
	scene.state.expedition_auto = true
	scene._toggle_drawer("wardrobe")
	advance(.85)
	var before_world: Array = world_signature()
	var before_state: Dictionary = scene.state._snapshot()
	before_state.erase("saved_at")
	scene._start_practice()
	check(scene.character_preview.cast_time > 0.0, "Technique demo starts in independent preview")
	advance(.8)
	var after_state: Dictionary = scene.state._snapshot()
	after_state.erase("saved_at")
	check(world_signature() == before_world and after_state == before_state, "Preview cast changes no world motion, encounter, resources or saved state")
	check(scene.character_preview._seat_amount < .02 and scene.character_preview._cast_strength > 0.0, "Preview can stand and demonstrate while the world stays paused")
	scene._toggle_drawer("settings")
	advance(.45)
	check(scene.character_preview.cast_time == 0.0 and not scene.character_preview.visible, "Leaving big book cancels and hides its local cast")
	check(is_equal_approx(scene.paper_width, 460.0), "Book width retargets to settings leaf")
	scene._toggle_drawer("wardrobe")
	advance(.85)
	check(scene.character_preview.cast_time == 0.0, "Reopening cannot revive a stale local cast")
	# Interrupted close/open and big/small pages keep the visible paper continuous.
	for i in range(24):
		var old_button = scene.buttons.drawer_close
		scene._close_drawer()
		advance(.08 if i % 2 == 0 else .3)
		var old_width: float = scene.paper_width
		var old_reveal: float = scene.paper_reveal
		var old_alpha: float = scene.drawer_alpha
		var target: String = ["settings", "practice", "desktop", "wardrobe"][i % 4]
		scene._toggle_drawer(target)
		check(is_equal_approx(scene.paper_width, old_width) and is_equal_approx(scene.paper_reveal, old_reveal) and is_equal_approx(scene.drawer_alpha, old_alpha), "Interrupted paper retarget keeps current geometry %d" % i)
		if is_instance_valid(old_button):
			old_button.pressed.emit()
		check(scene.drawer_name == target and is_instance_valid(scene.drawer), "Stale close button cannot affect replacement %d" % i)
		check(scene.buttons.drawer_close.focus_mode == Control.FOCUS_NONE and scene.buttons.drawer_close.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Invisible ink has no keyboard/pointer target %d" % i)
		advance(.85)
		check(scene.buttons.drawer_close.focus_mode != Control.FOCUS_NONE and scene.buttons.drawer_close.mouse_filter == Control.MOUSE_FILTER_STOP, "Visible ink restores interaction %d" % i)
		check_world_and_preview("Retarget %d" % i)
		await process_frame
	# Resize during entry, at rest, and during close; no world-space hit scaling.
	for width in [1000, 1360, 1200]:
		close_page()
		scene._toggle_drawer("practice")
		advance(.2)
		var reveal_before: float = scene.paper_reveal
		resize_to(width)
		check(is_equal_approx(scene.paper_reveal, reveal_before), "Resize preserves unfolding progress at %d" % width)
		advance(.85)
		check_world_and_preview("Resize %d" % width)
		check_hotspots_and_passthrough("Open %d" % width)
		scene._close_drawer()
		advance(.12)
		resize_to(width)
		check(not scene.buttons.wardrobe.visible, "World hotspot stays hidden behind closing paper")
		advance(.85)
		check_hotspots_and_passthrough("Closed %d" % width)
		check(scene.buttons.wardrobe.visible and not scene.character_preview.visible, "Closed UI restores only world controls")
	# Real engine input: preview clicks are isolated, Space never repeats an action.
	scene.encounter_active = false
	scene.state.expedition_auto = false
	scene._toggle_drawer("wardrobe")
	advance(.85)
	var preview_center: Vector2 = scene.character_preview.get_rect().get_center()
	mouse_event(preview_center, true)
	await process_frame
	mouse_event(preview_center, false)
	await process_frame
	check(scene.drawer_name == "wardrobe" and not scene.drag_active, "Preview click neither closes book nor drags window")
	scene._toggle_drawer("settings")
	advance(.85)
	scene.buttons.pause.grab_focus()
	var paused_before: bool = scene.paused
	var serial_before: int = scene.interaction_serial
	key_event(KEY_SPACE, true)
	await process_frame
	key_event(KEY_SPACE, false)
	await process_frame
	check(scene.paused != paused_before and scene.interaction_serial == serial_before, "Space toggles once without activating focused pause button")
	# Regression: the same key formerly spent enhancement resources a second time.
	scene.state.gear.load_data({"inventory":[{"id":1,"template_id":"chest_blue","rarity":"common","level":1,"enhancement":0}],"equipped":{},"chests":1,"starter_chest_unopened":false})
	scene.state.herbs = 1000
	scene.state.dew = 1000
	scene.selected_item = 1
	scene.wardrobe_tab = "equipment"
	scene._toggle_drawer("wardrobe")
	advance(.85)
	scene.buttons.enhance_item.grab_focus()
	scene.buttons.enhance_item.pressed.emit()
	var enhanced_before: Dictionary = scene.state.gear.get_item(1).duplicate(true)
	var herbs_before: int = scene.state.herbs
	key_event(KEY_SPACE, true)
	await process_frame
	key_event(KEY_SPACE, false)
	await process_frame
	check(scene.state.gear.get_item(1) == enhanced_before and scene.state.herbs == herbs_before, "Space never repeats enhancement or spends resources")
	close_page()
	# Tooltip anchoring uses the current world's hit rectangle, never portrait space.
	var tooltip_target: Control = scene.buttons.alchemy
	var hover := InputEventMouseMotion.new()
	hover.position = root.get_final_transform() * tooltip_target.get_global_rect().get_center()
	hover.global_position = hover.position
	Input.parse_input_event(hover)
	await process_frame
	check(root.gui_get_hovered_control() == tooltip_target, "Tooltip hover resolves to original world hotspot after close")
	check(tooltip_target.get_tooltip(tooltip_target.get_local_mouse_position()) == tooltip_target.tooltip_text, "Tooltip text resolves at actual pointer-local anchor")
	var wardrobe_center: Vector2 = scene.buttons.wardrobe.get_rect().get_center()
	mouse_event(wardrobe_center, true)
	await process_frame
	mouse_event(wardrobe_center, false)
	await process_frame
	check(scene.drawer_name == "wardrobe", "Real world-character click reopens book after teardown")
	close_page()
	check(scene.drawer == null and scene.drawer_alpha == 0.0 and scene.preview_blend == 0.0, "Close lifecycle removes drawer and hides independent preview")
	scene.queue_free()
	await process_frame
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)
	print("Scene framing: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
