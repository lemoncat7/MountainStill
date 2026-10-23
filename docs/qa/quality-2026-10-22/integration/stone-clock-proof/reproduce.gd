extends SceneTree
const State = preload("res://scripts/cultivation_state.gd")
func _initialize(): call_deferred("run")
func differences(a:Dictionary,b:Dictionary)->Array:
	var keys:Array=[]
	for key in a:
		if a[key] != b.get(key): keys.append(key)
	for key in b:
		if not a.has(key): keys.append(key)
	return keys
func run():
	var s=State.new()
	var before:Dictionary=s._snapshot()
	OS.delay_msec(1100)
	var after:Dictionary=s._snapshot()
	var no_view: Array=differences(before,after)
	print("Without any scene/view call: changed=",no_view," timestamps=",[before.saved_at,after.saved_at])
	var h=load("res://main.tscn").instantiate()
	h.state.save_path="user://clock-proof-isolated.json"
	root.add_child(h);await process_frame
	h.set_process(false);h.demo=true;h.encounter_active=true;h.encounter_phase="fight";h.world_route="creek_bridge"
	h.duel_pose={"hero_hp":100,"enemy_hp":190,"finished":false,"cancelled":false,"mechanic":"river_shell"}
	before=h.state._snapshot()
	OS.delay_msec(1100)
	h._stone_mechanic_view(Vector2(705,246))
	after=h.state._snapshot()
	var with_view:Array=differences(before,after)
	print("Across explicit second boundary with view: changed=",with_view," timestamps=",[before.saved_at,after.saved_at])
	before.erase("saved_at");after.erase("saved_at")
	var passed:bool=no_view==["saved_at"] and with_view==["saved_at"] and before==after
	# Mutation sentinel: removing only the timestamp cannot mask a game-state change.
	after.qi=float(after.qi)+1.0
	passed=passed and before!=after
	print("Clock isolation and mutation sentinel: ",passed)
	h.queue_free();await process_frame
	quit(0 if passed else 1)
