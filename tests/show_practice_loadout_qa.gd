extends SceneTree
## Synthetic maximum-slot visual fixture; not a natural campaign or win-rate test.
var scene
func _initialize(): call_deferred("run")
func run():
 scene = load("res://main.tscn").instantiate()
 scene.state.save_path = "user://practice_loadout_visual_only.json"
 root.add_child(scene)
 await process_frame
 scene.demo = true; scene.state.new_game(); scene.state.auto_advance = false
 scene.world_route = ""; scene.encounter_active = false; scene.paused = true
 scene.state.realm = 15
 var id := 1
 for template in ["weapon_sword", "head_crown", "chest_blue", "legs_blue", "feet_boots", "weapon_fan"]:
  scene.state.gear.inventory.append(scene.state.gear._make_item(id, template, "epic", 15, 5))
  if id < 6: scene.state.gear.equip_item(id)
  id += 1
 for key in scene.state.Content.TECHNIQUES:
  scene.state.technique_levels[key] = int(scene.state.Content.TECHNIQUES[key].max_level)
  if not scene.state.attuned_techniques.has(key): scene.state.attuned_techniques.append(key)
 scene.state.equipped_weapon_art = "mist"; scene.state.equipped_heart = "stillness"
 scene.state.equipped_actives.assign(["mist", "barrier"]); scene.state.equipped_passives.assign(["body"])
 scene.start_practice("bamboo_sprite")
 scene.practice_session.advance(120.0)
 scene.end_practice()
 scene.state.gear.equip_item(6)
 scene.state.equipped_weapon_art = "petal"
 scene.state.equipped_actives.assign(["petal", "barrier"])
 scene.start_practice("bamboo_sprite")
 scene.practice_session.advance(120.0)
 scene.drawer_name = "wardrobe"; scene.drawn_page = "wardrobe"; scene.wardrobe_tab = "equipment"
 scene.set_meta("combat_insight_open", true); scene.set_meta("combat_insight_view", "enemies")
 scene.set_meta("practice_show_loadout", true); scene.set_meta("practice_loadout_page", 0)
 var strip_mode: bool = "--strip-fixture" in OS.get_cmdline_user_args()
 scene.strip = strip_mode; scene.state.settings.ui_scale = 1.25
 scene.get_window().min_size = Vector2i(960,320) if strip_mode else Vector2i(960,540)
 scene.get_window().size = Vector2i(1200,400) if strip_mode else Vector2i(960,540)
 scene._apply_readability()
 await process_frame
 await process_frame
 scene.get_window().position = Vector2i(70,120)
 scene._refresh_drawer(true)
 print("SYNTHETIC PRACTICE LOADOUT GUI READY ", scene.size)
