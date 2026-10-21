extends SceneTree
## Six-route contact, motion and texture contract; no save mutation.
const Duel = preload("res://scripts/duel_timeline.gd")
const Walk = preload("res://scripts/character_sidewalk.gd")
var checks := 0
var failures := 0
func check(ok:bool,label:String)->void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize()->void:
	var signatures := {}
	for route in Duel.SPECIES_BY_ROUTE:
		var d := Duel.new()
		d.start({"hp":9999,"max_hp":9999,"attack":6,"defense":4}, {"hp":9999,"max_hp":9999,"attack":10,"route_id":route,"boss":true,"dodge_chance":0.0,"guard_chance":0.0}, "stillness", "sword", 77)
		var seen := {};var contacts := {};var mechanics := {};var old_hero:=d.hero_hp;var old_enemy:=d.enemy_hp
		for step in range(1800):
			var events := d.advance(0.02)
			var hp_events := events.filter(func(e:Dictionary)->bool:return str(e.type)=="contact")
			check((old_hero==d.hero_hp and old_enemy==d.enemy_hp) or not hp_events.is_empty(), route+": HP changes only on contact")
			old_hero=d.hero_hp;old_enemy=d.enemy_hp
			for e in hp_events:
				check(not contacts.has(e.contact_id),route+": no duplicate contact")
				contacts[e.contact_id]=true
				check(int(e.pre_hp)-int(e.post_hp)==int(e.damage),route+": rendered HP delta is damage")
				if not str(e.mechanic).is_empty():mechanics[e.mechanic]=true
			var p:=d.pose();check(p==d.pose(),route+": paused pose pure")
			check(str(p.enemy_visual_type)==Duel.SPECIES_BY_ROUTE[route],route+": exact species")
			check(Vector2(p.enemy.visual_scale)==Vector2.ONE,route+": painted creature never stretches")
			check(Vector2(p.enemy.visual_offset).is_finite(),route+": finite offset")
			if p.actor=="enemy":
				seen[str(p.move)+"/"+str(p.phase)]=true
				if p.phase=="windup":check(p.enemy.pose_key=="windup",route+": authored windup sprite")
				if p.phase=="contact":check(p.enemy.pose_key=="attack",route+": actual contact sprite")
		var signature:=str(seen.keys());check(not signatures.has(signature),route+": distinct choreography")
		signatures[signature]=true
		check(seen.size()>=10,route+": all three moves have anticipation/contact/recovery")
		if route in ["creek_bridge","cloud_slope","ember_ruins","moon_marsh","summit_gate"]:check(not mechanics.is_empty(),route+": mechanics modify actual combat event")
		for suffix in ["idle","windup","attack","boss_idle","boss_windup","boss_attack"]:
			var path:String="res://assets/cultivation/beasts/"+str(route)+"_"+suffix+".png"
			check(ResourceLoader.exists(path),"sprite exists "+path)
			var image:Image=(load(path) as Texture2D).get_image()
			check(image.get_size()==Vector2i(256,256),"shared sprite canvas")
			check(image.get_pixel(0,0).a<0.01,"transparent sprite corner")
		var panorama:Image=(load("res://assets/cultivation/routes/"+str(route)+"_panorama.png") as Texture2D).get_image()
		check(panorama.get_size()==Vector2i(2080,280),route+": finite two-screen panorama")
		for x in range(0,2080,13):check(panorama.get_pixel(x,246).a>0.90,route+": no ground gaps")
	for move in Duel.HERO_MOVES:
		for phase_name in ["windup","strike","contact","recovery"]:
			for step in range(21):
				var motion:={"blend":0.0,"combat_move":move,"combat_phase":phase_name,"phase_progress":float(step)/20.0,"attack_amount":1.0,"actor_lunge":float(Duel.HERO_MOVES[move].lunge),"attack_style":"sword"}
				var p:=Walk.sample_pose(motion)
				for key in ["near_arm","far_arm"]:
					var arm:Dictionary=p[key]
					check(absf(Vector2(arm.shoulder).distance_to(arm.elbow)-42.0)<0.001,"upper arm fixed")
					check(absf(Vector2(arm.elbow).distance_to(arm.wrist)-Vector2(10,36).length())<0.001,"forearm fixed")
					var source_grip:=Walk.EquipmentTemplate.ARM_WRIST_GRIP
					check(Walk._skin_arm(source_grip,arm).distance_to(arm.wrist)<0.001,"painted fist and weapon share exact pivot")
				for key in ["near_leg","far_leg"]:
					var leg:Dictionary=p[key]
					check(absf(Vector2(leg.hip).distance_to(leg.knee)-Walk.UPPER_LENGTH)<0.001,"fixed thigh")
					check(absf(Vector2(leg.knee).distance_to(leg.ankle)-Walk.LOWER_LENGTH)<0.001,"fixed shin")
	print("Campaign combat/art: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
