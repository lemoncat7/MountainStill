extends "res://tests/test_battle_resource_host.gd"
## Synthetic geometry/render-state checks; not natural-play or GUI evidence.
var draw_passes:=0
func luminance(c:Color)->float:
	var linear:=c.srgb_to_linear()
	return .2126*linear.r+.7152*linear.g+.0722*linear.b
func contrast(a:Color,b:Color)->float:
	return (maxf(luminance(a),luminance(b))+.05)/(minf(luminance(a),luminance(b))+.05)
func snapshot()->Array:
	var formal:Dictionary=scene.state._snapshot()
	formal.erase("saved_at")
	return [formal,scene.duel.battle_resource_snapshot().duplicate(true),scene.duel.combat_report().duplicate(true),scene.duel._rng.state,scene.duel._enemy_rng.state,scene.state._adventure_rng.state,scene.state._journey_rng.state,scene.state.gear.rng.state,scene.encounter_clock,scene.vitality,scene.enemy_hp,scene.encounter_phase,scene.route_distance,scene._interactive_regions()]
func run():
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path=save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.draw.connect(func():draw_passes+=1)
	fixture("sword",["frost","thunder"],9)
	begin_depleted_duel()
	for color in [Color("394c43"),Color("8e4436"),Color("566a59"),Color("425b58"),Color("456c5d"),scene.HUD_SECONDARY,Color("52634d")]:
		check(contrast(color,scene.HUD_PAPER)>=4.5,"Every small HUD text color meets 4.5:1 on opaque inset: "+color.to_html())
	check(scene.HUD_PAPER.a==1.0,"Text backing cannot inherit PNG or desktop transparency")
	for dimensions in [Vector2(960,320),Vector2(1200,320),Vector2(1200,540),Vector2(1600,900)]:
		scene.size=dimensions
		for phase in ["travel","fight","pickup","opportunity","teleport_return_out","teleport_home_in"]:
			scene.encounter_phase=phase
			for is_paused in [false,true]:
				scene.paused=is_paused
				var rect:Rect2=scene._progress_hud_rect()
				var inset:=rect.grow(-2)
				var label:String=scene._route_hud_label()
				var label_end:float=155+scene.SERIF.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
				check(inset.has_point(Vector2(25,dimensions.y-35)) and inset.has_point(Vector2(label_end,dimensions.y-20)),"Progress and route glyph area lies inside opaque inset")
				check(rect.end.x<dimensions.x-466,"Left HUD leaves gap before maximum three-slot battle strip")
				check(rect.size.x<dimensions.x*.5 and rect.size.y==35,"Local backing never becomes fullwidth footer")
				var before:=snapshot()
				scene.queue_redraw()
				await process_frame
				await process_frame
				check(before==snapshot(),"Rendering preserves saves, combat, RNG and hit regions")
	for label in ["1 / 3","2 / 3","3 / 3"]:
		check(scene.SERIF.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x<=35,"Counter glyph width fits opaque inset")
	check(scene.SERIF.get_ascent(10)<=12 and scene.SERIF.get_descent(10)<=4,"Counter glyph height fits opaque inset")
	check(scene.SERIF.get_ascent(10)<=12 and scene.SANS.get_descent(9)<=10,"Both battle strip baselines fit opaque inset")
	for status in ["兵器不合","战气不足","待疗伤","护体中","99.9s"]:
		check(scene.SANS.get_string_size(status+" · 99气",HORIZONTAL_ALIGNMENT_LEFT,-1,9).x<=100,"Battle strip status fits existing slot width")
	check(draw_passes>=48,"Queued render passes actually execute while simulation is stopped")
	var source:=FileAccess.get_file_as_string("res://scripts/cultivation.gd")
	check(source.find("_draw_scene(_landscape_rect())")<source.find("\t_draw_progress_hud()"),"HUD paints after scene")
	check(source.count('_text(label,Vector2(155,size.y-23)')==1,"Route label is drawn exactly once in post-scene pass")
	scene.queue_free()
	await process_frame
	await process_frame
	for path in [save_path,save_path+".bak",save_path+".tmp"]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("Combat HUD readability: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
