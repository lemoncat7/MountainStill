extends SceneTree
## Run with -- <frozen-v8-duel-script> <output.json> to quantify intended changes.
## All actions, hit results, resources and geometry use the real encounter path.
const Duel = preload("res://scripts/duel_timeline.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=2:
		printerr("Expected frozen baseline script path and output JSON path")
		quit(1)
		return
	var baseline: Script = load(args[0])
	var report := {"baseline_speed":100,"minimum_speed":65,"maximum_speed":160,
		"fixed_real_time":["opening_ai_wait","skill_cooldown","hitstop","guard_recoil","stun","slow_duration"],
		"rows":[]}
	for style in ["unarmed","sword","fan"]:
		for haste in [0.0,0.04,0.08,0.35]:
			var row := {"style":style,"earned_haste":haste,"effective_speed":100.0*(1.0+haste)}
			row.before = sample(baseline,style,haste,false)
			row.after = sample(Duel,style,haste,true)
			row.hold_seconds_saved = float(row.before.hold)-float(row.after.hold)
			row.interval_seconds_saved = float(row.before.ready_interval)-float(row.after.ready_interval)
			report.rows.append(row)
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("COMBAT_SPEED_MEASUREMENT "+args[1])
	quit()

func sample(factory: Script, style: String, haste: float, current: bool) -> Dictionary:
	var hero := {"hp":100000,"max_hp":100000,"attack":10,"defense":2,"combat_haste":haste,
		"combat_qi_max":40.0,"combat_qi_regen":0.0,"heart_method":{},"weapon_art":{},"weapon_skill":{},"active_skills":[]}
	if current:hero.speed=100.0*(1.0+haste)
	var enemy := {"hp":100000,"max_hp":100000,"attack":8,"defense":1,"boss":true,"route_id":"cloud_slope"}
	var d = factory.new()
	d.start(hero,enemy,"stillness",style,17)
	var action: Dictionary = d._lanes.hero.action
	var row := {"windup":action.windup,"strike":action.strike,"hold":action.hold,"recovery":action.recovery,
		"first_contact":action.contacts[0].time,"action_duration":action.duration,
		"ready_interval":0.07/(1.0+haste) if current else 0.07,"hero_starts_45s":0,"hero_contacts_45s":0,"hero_damage_45s":0,"enemy_damage_45s":0}
	for event in d.advance(45.0):
		if event.type=="turn_started" and event.actor=="hero":row.hero_starts_45s+=1
		if event.type=="contact":
			if event.actor=="hero":
				row.hero_contacts_45s+=1
				row.hero_damage_45s+=int(event.damage)
			else:row.enemy_damage_45s+=int(event.damage)
	return row
