extends SceneTree
## Instrument the quote entry point; real draw/idle frames must only use its cache.
const State = preload("res://scripts/cultivation_state.gd")
const Pages = preload("res://scripts/equipment_comparison_pages.gd")
class Probe extends State:
	var quote_calls := 0
	func equipment_comparison(id: int) -> Dictionary:
		quote_calls += 1
		return super.equipment_comparison(id)
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: "+label)
func run():
	var scene=load("res://main.tscn").instantiate()
	scene.state.save_path="user://comparison_cache_%d.json" % OS.get_process_id()
	root.add_child(scene)
	await process_frame
	scene.demo=true
	var probe=Probe.new()
	probe.auto_advance=false
	probe.settings.paused=true
	probe.save_path=scene.state.save_path
	scene.state=probe
	scene.paused=true
	var candidate: int=probe.gear.add_item_spec({"template_id":"weapon_fan","rarity":"rare","level":3}).item.id
	for i in range(99):probe.gear.add_item_spec({"template_id":"head_pin","rarity":"common","level":1})
	scene.selected_item=candidate
	scene.wardrobe_tab="equipment"
	scene._toggle_drawer("wardrobe")
	Pages.open(scene)
	var calls: int=probe.quote_calls
	check(calls==1,"opening computes once even with full inventory")
	var quote: Dictionary=scene.get_meta("equipment_comparison_quote").duplicate(true)
	var draws := [0]
	scene.draw.connect(func(): draws[0] += 1)
	var start:=Time.get_ticks_usec()
	for i in range(180):
		scene.queue_redraw()
		await process_frame
	var frame_ms: float = (Time.get_ticks_usec()-start)/1000.0
	check(draws[0] >= 179,"actual CanvasItem draw callbacks observed")
	check(probe.quote_calls==calls,"180 real idle/redraw frames never recompute comparison")
	check(scene.get_meta("equipment_comparison_quote")==quote,"idle/redraw frames preserve quote")
	scene.buttons.comparison_next.pressed.emit()
	check(probe.quote_calls==calls+1,"explicit page rebuild computes once")
	var timing_start:=Time.get_ticks_usec()
	for i in range(100):probe.equipment_comparison(candidate)
	var average_ms: float=(Time.get_ticks_usec()-timing_start)/100000.0
	print("Equipment comparison isolated observation: 180 frames %.2f ms; full inventory quote mean %.3f ms (not a native GPU/frame-budget guarantee)" % [frame_ms,average_ms])
	scene.queue_free()
	await process_frame
	await process_frame
	print("Equipment comparison cache: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
