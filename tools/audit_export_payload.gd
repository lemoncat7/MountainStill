extends SceneTree
## Use the editor with --headless --path EMPTY_DIRECTORY --main-pack EXPORTED.pck
## --script /absolute/path/to/this/file. Release templates lack --script support.

func _initialize() -> void:
	var expected := [
		"main.tscn", "default_bus_layout.tres", "icon.svg",
		"scripts/readability_layout.gd",
		"scripts/scene_art_layout.gd",
		"assets/cultivation/routes/sources/bamboo_panorama-source.png",
		"assets/cultivation/routes/sources/creek_bridge_panorama-source.png",
		"assets/cultivation/routes/sources/cloud_slope_panorama-source.png",
		"assets/cultivation/routes/sources/ember_ruins_panorama-source.png",
		"assets/cultivation/routes/sources/moon_marsh_panorama-source.png",
		"assets/cultivation/routes/sources/summit_gate_panorama-source.png",
		"assets/cultivation/sources/sanctuary-diorama-source.png",

		"scripts/practice_session.gd", "scripts/practice_host.gd", "scripts/practice_pages.gd", "scripts/cultivation.gd", "scripts/cultivation_state.gd", "scripts/equipment_ledger.gd",
		"scripts/desktop_mode.gd", "scripts/quiet_button.gd", "scripts/ink_hotspot.gd", "scripts/ink_paper.gd", "scripts/ink_pages.gd", "scripts/adventure_pages.gd", "scripts/journal_pages.gd", "scripts/cultivation_content.gd", "scripts/character_walk.gd", "scripts/character_meditation.gd", "scripts/character_preview.gd",
		"assets/fonts/NotoSansCJK-Regular.ttc", "assets/fonts/NotoSerifCJK-Regular.ttc", "assets/fonts/DejaVuSans.ttf", "assets/fonts/MaShanZheng-Regular.ttf",
		"assets/cultivation/sanctuary-warm.png", "assets/cultivation/sanctuary-diorama.png",
		"assets/ui/ink/rice-paper.png", "assets/ui/ink/soot-brush.png",
	]
	for name in ["sword", "fan", "mist_slash", "petal"]:
		expected.append("assets/cultivation/avatars/" + name + ".png")
	for name in ["base", "head_pin", "head_crown", "chest_blue", "chest_jade", "legs_blue", "legs_jade", "feet_cloth", "feet_boots"]:
		expected.append("assets/cultivation/equipment/" + name + ".png")
	for name in ["fox_idle", "fox_attack", "boar_idle", "boar_attack", "chest_closed", "chest_open"]:
		expected.append("assets/cultivation/encounters/" + name + ".png")
	for name in ["music", "equip", "level", "loot"]:
		expected.append("assets/audio/" + name + ".wav")
	for name in ["character_sidewalk.gd", "duel_timeline.gd", "character_projection.gd", "portal_dissolve.gdshader"]:
		expected.append("scripts/"+name)
	for name in ["head","torso","arm","leg","head_pin","head_crown","chest_blue","chest_jade","sleeve_blue","sleeve_jade","legs_blue","legs_jade","feet_cloth","feet_boots"]:
		expected.append("assets/cultivation/sidewalk/"+name+".png")
	for route in ["bamboo_pass","creek_bridge","cloud_slope","ember_ruins","moon_marsh","summit_gate"]:
		expected.append("assets/cultivation/routes/"+route+".png")
		expected.append("assets/cultivation/routes/"+route+"_scroll.png")
		expected.append("assets/cultivation/routes/"+route+"_panorama.png")
		for pose in ["idle","windup","attack","boss_idle","boss_windup","boss_attack"]:expected.append("assets/cultivation/beasts/"+route+"_"+pose+".png")
	expected.append("assets/cultivation/beasts/opportunity_cairn.png")
	expected.append("assets/cultivation/beasts/creek_bridge_boss_settle.png")
	expected.append("assets/cultivation/beasts/creek_bridge_boss_retract.png")
	# Complete release whitelist, including dynamic combat art and nested modules.
	expected.append_array(["assets/audio/equip.wav", "assets/audio/level.wav", "assets/audio/loot.wav", "assets/audio/music.wav", "assets/cultivation/avatars/fan.png", "assets/cultivation/avatars/mist_slash.png", "assets/cultivation/avatars/petal.png", "assets/cultivation/avatars/sword.png", "assets/cultivation/beasts/bamboo_pass_attack.png", "assets/cultivation/beasts/bamboo_pass_authored_charge_a.png", "assets/cultivation/beasts/bamboo_pass_authored_charge_b.png", "assets/cultivation/beasts/bamboo_pass_authored_crouch.png", "assets/cultivation/beasts/bamboo_pass_authored_land.png", "assets/cultivation/beasts/bamboo_pass_authored_pounce.png", "assets/cultivation/beasts/bamboo_pass_authored_rear.png", "assets/cultivation/beasts/bamboo_pass_boss_attack.png", "assets/cultivation/beasts/bamboo_pass_boss_authored_charge_a.png", "assets/cultivation/beasts/bamboo_pass_boss_authored_charge_b.png", "assets/cultivation/beasts/bamboo_pass_boss_authored_crouch.png", "assets/cultivation/beasts/bamboo_pass_boss_authored_fallen_v7.png", "assets/cultivation/beasts/bamboo_pass_boss_authored_land.png", "assets/cultivation/beasts/bamboo_pass_boss_authored_pounce.png", "assets/cultivation/beasts/bamboo_pass_boss_authored_rear.png", "assets/cultivation/beasts/bamboo_pass_boss_idle.png", "assets/cultivation/beasts/bamboo_pass_boss_windup.png", "assets/cultivation/beasts/bamboo_pass_idle.png", "assets/cultivation/beasts/bamboo_pass_windup.png", "assets/cultivation/beasts/cloud_slope_attack.png", "assets/cultivation/beasts/cloud_slope_authored_coil.png", "assets/cultivation/beasts/cloud_slope_authored_dive.png", "assets/cultivation/beasts/cloud_slope_authored_lift.png", "assets/cultivation/beasts/cloud_slope_authored_peck.png", "assets/cultivation/beasts/cloud_slope_authored_wing_back.png", "assets/cultivation/beasts/cloud_slope_authored_wing_sweep.png", "assets/cultivation/beasts/cloud_slope_boss_attack.png", "assets/cultivation/beasts/cloud_slope_boss_authored_coil.png", "assets/cultivation/beasts/cloud_slope_boss_authored_dive.png", "assets/cultivation/beasts/cloud_slope_boss_authored_fallen_v7.png", "assets/cultivation/beasts/cloud_slope_boss_authored_lift.png", "assets/cultivation/beasts/cloud_slope_boss_authored_peck.png", "assets/cultivation/beasts/cloud_slope_boss_authored_wing_back.png", "assets/cultivation/beasts/cloud_slope_boss_authored_wing_sweep.png", "assets/cultivation/beasts/cloud_slope_boss_idle.png", "assets/cultivation/beasts/cloud_slope_boss_windup.png", "assets/cultivation/beasts/cloud_slope_idle.png", "assets/cultivation/beasts/cloud_slope_windup.png", "assets/cultivation/beasts/creek_bridge_attack.png", "assets/cultivation/beasts/creek_bridge_boss_attack.png", "assets/cultivation/beasts/creek_bridge_boss_idle.png", "assets/cultivation/beasts/creek_bridge_boss_windup.png", "assets/cultivation/beasts/creek_bridge_idle.png", "assets/cultivation/beasts/creek_bridge_windup.png", "assets/cultivation/beasts/ember_ruins_attack.png", "assets/cultivation/beasts/ember_ruins_boss_attack.png", "assets/cultivation/beasts/ember_ruins_boss_idle.png", "assets/cultivation/beasts/ember_ruins_boss_windup.png", "assets/cultivation/beasts/ember_ruins_idle.png", "assets/cultivation/beasts/ember_ruins_windup.png", "assets/cultivation/beasts/moon_marsh_attack.png", "assets/cultivation/beasts/moon_marsh_boss_attack.png", "assets/cultivation/beasts/moon_marsh_boss_idle.png", "assets/cultivation/beasts/moon_marsh_boss_windup.png", "assets/cultivation/beasts/moon_marsh_idle.png", "assets/cultivation/beasts/moon_marsh_windup.png", "assets/cultivation/beasts/opportunity_cairn.png", "assets/cultivation/beasts/summit_gate_attack.png", "assets/cultivation/beasts/summit_gate_boss_attack.png", "assets/cultivation/beasts/summit_gate_boss_idle.png", "assets/cultivation/beasts/summit_gate_boss_windup.png", "assets/cultivation/beasts/summit_gate_idle.png", "assets/cultivation/beasts/summit_gate_windup.png", "assets/cultivation/encounters/boar_attack.png", "assets/cultivation/encounters/boar_idle.png", "assets/cultivation/encounters/chest_closed.png", "assets/cultivation/encounters/chest_open.png", "assets/cultivation/encounters/fox_attack.png", "assets/cultivation/encounters/fox_idle.png", "assets/cultivation/equipment/base.png", "assets/cultivation/equipment/chest_blue.png", "assets/cultivation/equipment/chest_jade.png", "assets/cultivation/equipment/feet_boots.png", "assets/cultivation/equipment/feet_cloth.png", "assets/cultivation/equipment/head_crown.png", "assets/cultivation/equipment/head_pin.png", "assets/cultivation/equipment/legs_blue.png", "assets/cultivation/equipment/legs_jade.png", "assets/cultivation/routes/bamboo_pass.png", "assets/cultivation/routes/bamboo_pass_mirror.png", "assets/cultivation/routes/bamboo_pass_panorama.png", "assets/cultivation/routes/bamboo_pass_scroll.png", "assets/cultivation/routes/cloud_slope.png", "assets/cultivation/routes/cloud_slope_mirror.png", "assets/cultivation/routes/cloud_slope_panorama.png", "assets/cultivation/routes/cloud_slope_scroll.png", "assets/cultivation/routes/creek_bridge.png", "assets/cultivation/routes/creek_bridge_mirror.png", "assets/cultivation/routes/creek_bridge_panorama.png", "assets/cultivation/routes/creek_bridge_scroll.png", "assets/cultivation/routes/ember_ruins.png", "assets/cultivation/routes/ember_ruins_panorama.png", "assets/cultivation/routes/ember_ruins_scroll.png", "assets/cultivation/routes/moon_marsh.png", "assets/cultivation/routes/moon_marsh_panorama.png", "assets/cultivation/routes/moon_marsh_scroll.png", "assets/cultivation/routes/summit_gate.png", "assets/cultivation/routes/summit_gate_panorama.png", "assets/cultivation/routes/summit_gate_scroll.png", "assets/cultivation/sanctuary-diorama.png", "assets/cultivation/sanctuary-warm.png", "assets/cultivation/sidewalk/arm.png", "assets/cultivation/sidewalk/chest_blue.png", "assets/cultivation/sidewalk/chest_jade.png", "assets/cultivation/sidewalk/feet_boots.png", "assets/cultivation/sidewalk/feet_cloth.png", "assets/cultivation/sidewalk/head.png", "assets/cultivation/sidewalk/head_crown.png", "assets/cultivation/sidewalk/head_pin.png", "assets/cultivation/sidewalk/leg.png", "assets/cultivation/sidewalk/legs_blue.png", "assets/cultivation/sidewalk/legs_jade.png", "assets/cultivation/sidewalk/normalized/arm.png", "assets/cultivation/sidewalk/normalized/chest_blue.png", "assets/cultivation/sidewalk/normalized/chest_jade.png", "assets/cultivation/sidewalk/normalized/feet_boots.png", "assets/cultivation/sidewalk/normalized/feet_cloth.png", "assets/cultivation/sidewalk/normalized/head.png", "assets/cultivation/sidewalk/normalized/head_crown.png", "assets/cultivation/sidewalk/normalized/head_pin.png", "assets/cultivation/sidewalk/normalized/leg.png", "assets/cultivation/sidewalk/normalized/legs_blue.png", "assets/cultivation/sidewalk/normalized/legs_jade.png", "assets/cultivation/sidewalk/normalized/sleeve_blue.png", "assets/cultivation/sidewalk/normalized/sleeve_jade.png", "assets/cultivation/sidewalk/normalized/torso.png", "assets/cultivation/sidewalk/sleeve_blue.png", "assets/cultivation/sidewalk/sleeve_jade.png", "assets/cultivation/sidewalk/template-arm-blank.png", "assets/cultivation/sidewalk/template-chest-blank.png", "assets/cultivation/sidewalk/template-head-blank.png", "assets/cultivation/sidewalk/template-leg-blank.png", "assets/cultivation/sidewalk/template.gd", "assets/cultivation/sidewalk/torso.png", "assets/fonts/DejaVuSans.ttf", "assets/fonts/MaShanZheng-Regular.ttf", "assets/fonts/NotoSansCJK-Regular.ttc", "assets/fonts/NotoSerifCJK-Regular.ttc", "assets/ui/ink/rice-paper.png", "assets/ui/ink/soot-brush.png", "default_bus_layout.tres", "icon.svg", "main.tscn", "scripts/adventure_pages.gd", "scripts/attack_module_registry.gd", "scripts/beast_presentation.gd", "scripts/chapter_field_guide.gd", "scripts/character_meditation.gd", "scripts/character_preview.gd", "scripts/character_projection.gd", "scripts/character_sidewalk.gd", "scripts/character_walk.gd", "scripts/combat_impact.gd", "scripts/combat_modules/attack_module.gd", "scripts/combat_modules/enemy_attack_module.gd", "scripts/combat_modules/technique_barrier.gd", "scripts/combat_modules/technique_ember.gd", "scripts/combat_modules/technique_frost.gd", "scripts/combat_modules/technique_mending.gd", "scripts/combat_modules/technique_mist.gd", "scripts/combat_modules/technique_petal.gd", "scripts/combat_modules/technique_stillness.gd", "scripts/combat_modules/technique_thunder.gd", "scripts/combat_modules/weapon_fan.gd", "scripts/combat_modules/weapon_sword.gd", "scripts/combat_modules/weapon_unarmed.gd", "scripts/combat_response_cues.gd", "scripts/combat_timing.gd", "scripts/corpse_presentation.gd", "scripts/practice_session.gd", "scripts/practice_host.gd", "scripts/practice_pages.gd", "scripts/cultivation.gd", "scripts/cultivation_content.gd", "scripts/cultivation_state.gd", "scripts/desktop_mode.gd", "scripts/duel_timeline.gd", "scripts/equipment_ledger.gd", "scripts/ink_hotspot.gd", "scripts/ink_pages.gd", "scripts/ink_paper.gd", "scripts/journal_pages.gd", "scripts/material_ledger.gd", "scripts/material_registry.gd", "scripts/melee_contact_geometry.gd", "scripts/monster_move_library.gd", "scripts/monster_pose_renderer.gd", "scripts/player_journey.gd", "scripts/player_journey_pages.gd", "scripts/portal_dissolve.gdshader", "scripts/quiet_button.gd", "scripts/route_motion.gd", "scripts/weapon_grip_hand.gd"])
	for path in expected:
		if not ResourceLoader.exists("res://" + path) or load("res://" + path) == null:
			push_error("Export payload missing or unreadable: " + path)
			quit(1)
			return
	# Dynamic boss recovery must ship its pixels AND matching registration.
	var settle: Texture2D = load("res://assets/cultivation/beasts/creek_bridge_boss_settle.png")
	var settle_pixels := settle.get_image()
	var landmarks = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cultivation/beasts/body-landmarks.json"))
	if settle_pixels == null or settle_pixels.get_size() != Vector2i(256,256) or not landmarks is Dictionary or not landmarks.get("poses",{}).has("creek_bridge_boss_settle"):
		push_error("Exported stone recovery pixels/registration missing or invalid");quit(1);return
	var settle_landmark: Dictionary = landmarks["poses"]["creek_bridge_boss_settle"]
	var anchor: Array = settle_landmark.get("ground_anchor",[])
	if anchor.size() != 2 or float(anchor[0]) != 121.0 or float(anchor[1]) != 232.0:
		push_error("Exported stone recovery anchor differs from reviewed registration");quit(1);return
	var retract: Texture2D = load("res://assets/cultivation/beasts/creek_bridge_boss_retract.png")
	var retract_pixels := retract.get_image()
	var retract_anchor: Array = landmarks.get("poses",{}).get("creek_bridge_boss_retract",{}).get("ground_anchor",[])
	if retract_pixels == null or retract_pixels.get_size() != Vector2i(256,256) or retract_anchor.size() != 2 or float(retract_anchor[0]) != 115.0 or float(retract_anchor[1]) != 232.0:
		push_error("Exported midway retraction pixels/sole registration missing or invalid");quit(1);return
	# A Script resource may load even when its parser failed; reject that false positive.
	for path in expected:
		var resource = load("res://" + path)
		if resource is Script and not resource.can_instantiate():
			push_error("Exported script cannot instantiate: " + path)
			quit(1)
			return
	for path in ["scripts/main.gd", "scripts/game_state.gd", "assets/mushroom.png", "assets/cultivation/sanctuary.png", "assets/cultivation/cultivator-atlas.png", "assets/cultivation/avatars/moon_idle.png", "assets/cultivation/avatars/moon_cast.png", "assets/cultivation/avatars/jade_idle.png", "assets/cultivation/avatars/jade_cast.png"]:
		if ResourceLoader.exists("res://" + path):
			push_error("Unexpected legacy resource in export: " + path)
			quit(1)
			return
	var diorama: Texture2D = load("res://assets/cultivation/sanctuary-diorama.png")
	var pixels := diorama.get_image()
	if pixels == null or pixels.get_size() != Vector2i(1040, 280) or pixels.get_pixel(520, 20).a > 0.01 or pixels.get_pixel(520, 246).a < 0.90:
		push_error("Exported diorama failed canvas/clear-sky/opaque-ground alpha checks")
		quit(1)
		return
	for route in ["bamboo_pass","creek_bridge","cloud_slope","ember_ruins","moon_marsh","summit_gate"]:
		var route_texture:Texture2D=load("res://assets/cultivation/routes/"+route+".png")
		var route_pixels=route_texture.get_image()
		if route_pixels.get_size()!=Vector2i(1040,280) or route_pixels.get_pixel(520,20).a>.01 or route_pixels.get_pixel(520,246).a<.90:
			push_error("Route lost clear sky or grounded foot lane: "+route);quit(1);return
	print("PASS: exported diorama preserves clear sky and opaque character footing.")
	print("PASS: all %d active resources load from the exported payload; legacy prototype resources are absent." % expected.size())
	quit(0)
