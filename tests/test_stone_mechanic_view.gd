extends SceneTree
const Duel = preload("res://scripts/duel_timeline.gd")
const Content = preload("res://scripts/cultivation_content.gd")
var checks := 0
var failures := 0
var h
func _initialize(): call_deferred("run")
func check(ok:bool, label:String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: "+label)
func stable_save_snapshot() -> String:
	# _snapshot derives saved_at from wall time on every call. Exclude only
	# that volatile serialization timestamp, not any persistent gameplay field.
	var data:Dictionary = h.state._snapshot()
	data.erase("saved_at")
	return JSON.stringify(data)
func run():
	h = load("res://main.tscn").instantiate()
	h.state.save_path = "user://mechanic_isolated.json"
	root.add_child(h); await process_frame
	h.set_process(false); h.demo = true
	h.encounter_active = true; h.encounter_phase = "fight"; h.world_route = "creek_bridge"
	var p := Vector2(705,246)
	var base := {"hero_hp":100,"enemy_hp":190,"finished":false,"cancelled":false,"mechanic":"river_shell"}
	h.duel_pose = base.duplicate(true)
	check(h._stone_mechanic_view(p).text == "守壳", "initial shell")
	for boss in [false,true]:
		h.route_boss = boss
		for id in ["river_shell","river_exposed"]:
			h.duel_pose.mechanic = id
			var view:Dictionary = h._stone_mechanic_view(p)
			check(view.text == ("守壳" if id == "river_shell" else "露隙"), "exact state text")
			var r:Rect2 = view.plate
			check(r.position.y >= 0 and r.end.x <= 1040 and r.end.y <= 280, "badge in canonical canvas")
			var nameplate := Rect2(p+Vector2(-67,-(174.0 if boss else 112.0)*232.0/256.0-23),Vector2(134,19))
			check(not r.intersects(nameplate), "badge outside nameplate")
			check(not r.intersects(Rect2(p+Vector2(-33,10),Vector2(66,3))), "badge outside hp bar")
			var frozen:Dictionary = view.duplicate(true)
			h.elapsed += 100; h.paused = true
			check(h._stone_mechanic_view(p) == frozen, "no independent clock while paused")
	for phase in ["travel","pickup","teleport_return_out","teleport_home_in",""]:
		h.encounter_phase = phase
		check(h._stone_mechanic_view(p).is_empty(), "no badge in "+phase)
	h.encounter_phase = "fight"
	for field in ["finished","cancelled"]:
		h.duel_pose = base.duplicate(true); h.duel_pose[field] = true
		check(h._stone_mechanic_view(p).is_empty(), "hidden "+field)
	for field in ["enemy_hp","hero_hp"]:
		h.duel_pose = base.duplicate(true); h.duel_pose[field] = 0
		check(h._stone_mechanic_view(p).is_empty(), "hidden zero "+field)
	h.duel_pose = base.duplicate(true); h.world_route = "bamboo_pass"
	check(h._stone_mechanic_view(p).is_empty(), "other species hidden")
	h.world_route = "creek_bridge"; h.duel_pose.mechanic = "unrecognized"
	check(h._stone_mechanic_view(p).is_empty(), "unknown state hidden")
	h.duel_pose = base.duplicate(true); h.encounter_active = false
	check(h._stone_mechanic_view(p).is_empty(), "exit hides badge")
	h.encounter_active = true; h.paused = false
	# Real simulation: the presentation receives exactly the engine's current
	# mechanic on every sample; calling it never mutates pose, save or RNG.
	for boss in [false,true]:
		h.route_boss = boss
		var enemy:Dictionary = Content.STAGES.creek_bridge.monsters[2 if boss else 0].duplicate(true)
		enemy.stage_id = "creek_bridge"
		var hero:Dictionary = h.state.stats().duplicate(true); hero.hp = 10000; hero.max_hp = 10000
		var duel := Duel.new(); duel.start(hero,enemy,"mist","unarmed",377)
		var seen := {}; var enemy_starts := 0
		for i in range(800):
			var events:Array = duel.advance(.025)
			for e in events:
				if e.get("type","") == "turn_started" and e.get("actor","") == "enemy":
					enemy_starts += 1
					if enemy_starts == 1: check(duel.pose().mechanic == "river_exposed", "first enemy windup already exposed")
			h.duel_pose = duel.pose()
			var before:Dictionary = h.duel_pose.duplicate(true)
			var save:String = stable_save_snapshot()
			var clock_high_water:int = h.state._clock_high_water
			var view:Dictionary = h._stone_mechanic_view(p)
			check(h.duel_pose == before and stable_save_snapshot() == save and h.state._clock_high_water == clock_high_water, "read-only presentation")
			if not duel.finished:
				check(view.get("id","") == str(before.mechanic), "real engine state sampled")
				seen[str(before.mechanic)] = true
			else: check(view.is_empty(), "finished real engine hidden")
		check(seen.has("river_shell") and seen.has("river_exposed"), "both real states observed")
		check(enemy_starts >= 3, "at least three real enemy starts")
	h.queue_free(); await process_frame
	print("Stone mechanic view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
