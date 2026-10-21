extends SceneTree
## Native preset-combat proof. Real state-derived loadout, normal host update,
## actual qi/cooldowns/contacts; no campaign-earned or route-completion claim.
## --skill=ember|frost|thunder|barrier|mending --capture-prefix=/absolute/prefix
## --headless-sanity runs the same host in fixed 1/60 steps without native capture.

class RecordedDuel:
	extends "res://scripts/duel_timeline.gd"
	var recorded_events:Array[Dictionary]=[]
	var initial_hero:Dictionary={}
	var initial_enemy:Dictionary={}
	var start_count:=0

	func start(hero_stats:Dictionary,enemy_definition:Dictionary,selected_technique:String="mist",weapon:String="unarmed",run_seed:int=1)->void:
		start_count+=1
		initial_hero=hero_stats.duplicate(true)
		initial_enemy=enemy_definition.duplicate(true)
		super.start(hero_stats,enemy_definition,selected_technique,weapon,run_seed)

	func advance(delta:float)->Array[Dictionary]:
		var emitted:Array[Dictionary]=super.advance(delta)
		for event in emitted:recorded_events.append(event.duplicate(true))
		return emitted

const SKILLS:=["ember","frost","thunder","barrier","mending"]
const FIGHT_SECONDS:=22.0
const SEED:=377
var scene
var observer:RecordedDuel
var banner:Label
var skill:="ember"
var capture_prefix:=""
var sanity:=false
var configured:=false
var prepared:=false
var started:=false
var done:=false
var clock:=0.0
var fight_age:=0.0
var last_sample:=-1.0
var event_cursor:=0
var samples:Array[Dictionary]=[]
var captures:Array[Dictionary]=[]
var captured:Dictionary={}
var phase_events:Array[Dictionary]=[]
var previous_phase:=""
var expected_stats:Dictionary={}
var setup_errors:Array[String]=[]


func _initialize():
	call_deferred("start")


func start():
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--skill="):skill=str(argument).trim_prefix("--skill=")
		elif str(argument).begins_with("--capture-prefix="):capture_prefix=str(argument).trim_prefix("--capture-prefix=")
		elif str(argument)=="--headless-sanity":sanity=true
	if skill not in SKILLS:
		printerr("SKILL_CYCLE_ARGUMENT_ERROR: --skill must be one of "+", ".join(SKILLS))
		quit(2)
		return
	if capture_prefix.is_empty():
		capture_prefix=ProjectSettings.globalize_path("user://revision-captures/skill-"+skill)
	if not capture_prefix.is_absolute_path():
		printerr("SKILL_CYCLE_ARGUMENT_ERROR: --capture-prefix must be absolute")
		quit(2)
		return
	if DisplayServer.get_name()=="headless" and not sanity:
		printerr("SKILL_CYCLE_ARGUMENT_ERROR: use --headless-sanity for nonvisual verification")
		quit(2)
		return
	var directory_error:=DirAccess.make_dir_recursive_absolute(capture_prefix.get_base_dir())
	if directory_error!=OK:
		printerr("SKILL_CYCLE_OUTPUT_ERROR: cannot create capture directory")
		quit(2)
		return
	scene=load("res://main.tscn").instantiate()
	# Unique temporary save path is set before _ready, isolating startup too.
	scene.state.save_path="user://skill_cycle_fixture_%d.json"%OS.get_process_id()
	root.add_child(scene)
	await process_frame
	scene.demo=true
	scene.state.new_game()
	scene.state.auto_advance=false
	scene.state.realm=9
	scene.state.equipped_weapon_art=""
	scene.state.equipped_actives.clear()
	scene.state.equipped_passives.clear()
	scene.state._adventure_rng.seed=SEED
	scene.state.gear.rng.seed=SEED
	# Learned ranks and equipment are explicitly preset fixture data. Effective
	# stats, active descriptors and the innate skill are produced by real state.
	scene.state.technique_levels[skill]=1
	scene.state.technique_levels.body=1
	for id in [skill,"body"]:
		var attuned:Dictionary=scene.state.attune_technique(id)
		if not bool(attuned.get("ok",false)):setup_errors.append("Could not attune "+str(id)+": "+str(attuned.get("reason","")))
	var equipped:Dictionary=scene.state.equip_technique(skill,"active")
	if not bool(equipped.get("ok",false)):setup_errors.append("Could not equip selected active: "+str(equipped.get("reason","")))
	var body:Dictionary=scene.state.equip_technique("body","passive")
	if not bool(body.get("ok",false)):setup_errors.append("Could not equip passive body: "+str(body.get("reason","")))
	var heart_quote:Dictionary=scene.state.quote_heart_switch("breath")
	var heart:Dictionary=scene.state.confirm_heart_switch(heart_quote)
	if not bool(heart.get("ok",false)):setup_errors.append("Could not equip initial heart: "+str(heart.get("reason","")))
	for template in ["weapon_sword","chest_blue","legs_jade","feet_boots","head_pin"]:
		var item_id:int=scene.state.gear._allocate_id()
		scene.state.gear.inventory.append(scene.state.gear._make_item(item_id,template,"common",1))
		if not scene.state.equip_item(item_id):setup_errors.append("Could not equip "+str(template))
	expected_stats=scene.state.stats().duplicate(true)
	# The boss checkpoint is a declared fixture, reached through the same state
	# APIs as existing native comparisons. No earned-progression claim is made.
	var route:Dictionary=scene.state.start_stage()
	if not bool(route.get("ok",false)):
		setup_errors.append("Could not prepare fixture route: "+str(route.get("reason","")))
	else:
		for index in range(2):
			var reward:Dictionary=scene.state.defeat_stage_monster(int(route.run_id),index)
			if not bool(reward.get("ok",false)):setup_errors.append("Could not prepare checkpoint "+str(index))
		scene.state.check_route_opportunity(int(route.run_id))
		if scene.state.stage_status().opportunity_pending:scene.state.choose_opportunity("gather_gift")
		scene.state.pause_stage(int(route.run_id))
	observer=RecordedDuel.new()
	scene.duel=observer
	scene.get_window().size=Vector2i(1200,320)
	scene.get_window().transparent_bg=false
	scene.size=Vector2(1200,320)
	scene.strip=true
	scene.desktop.transparent_enabled=true
	Engine.max_fps=60
	RenderingServer.set_default_clear_color(Color("#e8e7df"))
	banner=Label.new()
	banner.position=Vector2(18,8)
	banner.add_theme_font_size_override("font_size",10)
	banner.add_theme_color_override("font_color",Color("#405549"))
	banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
	banner.text="预置战斗配置 · 非自然养成 / "+str(scene.state.Content.TECHNIQUES[skill].name)+" + 青锋兵器技 / 真实耗气冷却 / 正常速度"
	scene.add_child(banner)
	scene.character_x=520.0
	scene.character_y=230.0
	scene.meditation_amount=1.0
	scene.meditation_settle=2.0
	scene.toast_time=0.0
	scene._close_drawer()
	if sanity:scene.set_process(false)
	else:RenderingServer.frame_post_draw.connect(_on_rendered_frame)
	print("SKILL_CYCLE_SETUP "+JSON.stringify({"skill":skill,"preset_fixture":true,"campaign_earned":false,"headless_sanity":sanity,"duration":FIGHT_SECONDS,"seed":SEED,"state_stats":expected_stats,"setup_errors":setup_errors}))
	configured=true
	if not setup_errors.is_empty():
		done=true
		call_deferred("_finish")
		return
	scene._start_encounter()
	scene.toast_time=0.0


func _process(delta:float):
	if done or not configured or not is_instance_valid(scene):return
	if sanity:
		# Wall-time acceleration is confined to headless verification. Each
		# gameplay tick remains the same fixed step used for recorded evidence.
		for frame in range(120):
			if done:break
			_prepare_travel_fixture()
			scene._process(1.0/60.0)
			_observe(1.0/60.0)
	else:
		_prepare_travel_fixture()
		_observe(delta)


func _prepare_travel_fixture():
	if prepared or scene.encounter_phase!="travel":return
	prepared=true
	# All fixture changes happen before the first action. Mana, loadout, stats
	# and cooldowns are never edited or replenished during the fight.
	scene.route_enemy_definition.hp=3000
	scene.route_enemy_definition.max_hp=3000
	scene.route_enemy_definition.attack=14
	scene.route_enemy_definition.defense=1
	scene.enemy_hp=3000
	scene.enemy_max_hp=3000
	scene.encounter_enemy_attack=14
	scene.encounter_enemy_defense=1
	scene.vitality=float(expected_stats.max_hp)*.70
	print("SKILL_CYCLE_PRESET "+JSON.stringify({"hero_start_hp":int(scene.vitality),"hero_max_hp":expected_stats.max_hp,"enemy_hp":3000,"enemy_attack":14,"enemy_defense":1,"preset_checkpoint":2,"resource_mutations_during_fight":false}))


func _observe(delta:float):
	clock+=delta
	if scene.encounter_phase!=previous_phase:
		previous_phase=scene.encounter_phase
		var phase:Dictionary={"time":snappedf(clock,.00001),"phase":previous_phase,"route_distance":scene.route_distance}
		phase_events.append(phase)
		print("SKILL_CYCLE_PHASE "+JSON.stringify(phase))
	if scene.encounter_phase=="fight":
		fight_age=observer.elapsed
		if not started:
			started=true
			print("SKILL_CYCLE_FIGHT_START "+JSON.stringify({"skill":skill,"time":clock,"hero":observer.initial_hero,"enemy":observer.initial_enemy,"seed":SEED}))
		if fight_age-last_sample>=.1:
			last_sample=fight_age
			var pose:Dictionary=observer.pose()
			samples.append({"time":snappedf(clock,.00001),"fight_time":snappedf(fight_age,.00001),"hero_hp":scene.vitality,"enemy_hp":scene.enemy_hp,
				"hero_action":pose.hero.duplicate(true),"enemy_action":pose.enemy.duplicate(true),"resources":observer.battle_resource_snapshot(),
				"shield":pose.shield,"enemy_slow_remaining":pose.enemy_slow_remaining})
	while event_cursor<observer.recorded_events.size():
		var event:Dictionary=observer.recorded_events[event_cursor]
		event_cursor+=1
		if str(event.type) in ["turn_started","contact","finished"]:
			print(("SKILL_CYCLE_CONTACT " if str(event.type)=="contact" else "SKILL_CYCLE_EVENT ")+JSON.stringify(event))
	if fight_age>=FIGHT_SECONDS or clock>=60.0 or (started and scene.encounter_phase!="fight"):
		done=true
		scene.set_process(false)
		call_deferred("_finish")


func _on_rendered_frame():
	if not started or not is_instance_valid(scene) or scene.encounter_phase!="fight":return
	var pose:Dictionary=observer.pose()
	var hero:Dictionary=pose.hero
	var phase:=str(hero.get("combat_phase",""))
	var id:=str(hero.get("skill_id",""))
	if id==skill and phase=="strike" and float(hero.get("phase_progress",0.0))>=.50:
		_capture_frame("skill-strike",pose)
	if id==skill and phase=="contact":
		_capture_frame("skill-contact",pose)
	if str(hero.get("action_kind",""))=="weapon" and phase=="strike" and float(hero.get("phase_progress",0.0))>=.50:
		_capture_frame("weapon-strike",pose)
	if str(hero.get("action_kind",""))=="basic" and phase=="contact":
		_capture_frame("basic-contact",pose)


func _capture_frame(tag:String,pose:Dictionary):
	if captured.has(tag):return
	var path:=capture_prefix+"-"+tag+".png"
	var result:=root.get_texture().get_image().save_png(path)
	if result!=OK:
		setup_errors.append("Screenshot failed: "+path+" (error "+str(result)+")")
		return
	captured[tag]=true
	var metadata:Dictionary={"tag":tag,"path":path,"fight_time":observer.elapsed,"hero":pose.hero.duplicate(true),"resources":observer.battle_resource_snapshot(),"hero_hp":pose.hero_hp,"enemy_hp":pose.enemy_hp}
	captures.append(metadata)
	print("SKILL_CYCLE_CAPTURE "+JSON.stringify(metadata))


func _validation()->Dictionary:
	var errors:Array[String]=setup_errors.duplicate()
	var selected_starts:=0
	var selected_contacts:=0
	var innate_starts:=0
	var basics:=0
	var enemy_damage:=0
	var healing:=0
	var shield_added:=0
	var shield_absorbed:=0
	for event in observer.recorded_events:
		if str(event.type)=="turn_started" and str(event.actor)=="hero":
			if str(event.action_kind)=="basic":basics+=1
			elif str(event.skill_id)==skill:selected_starts+=1
			elif str(event.action_kind)=="weapon":innate_starts+=1
			if str(event.action_kind)!="basic" and float(event.get("qi_cost",0.0))<=0:errors.append("Paid action lacks a positive cost")
		elif str(event.type)=="contact":
			if str(event.get("actor",""))=="enemy":enemy_damage+=int(event.get("damage",0))
			shield_absorbed+=int(event.get("shield_absorbed",0))
			if str(event.get("skill_id",""))==skill and str(event.get("actor",""))=="hero":
				selected_contacts+=1
				healing+=int(event.get("heal",0))
				shield_added+=int(event.get("shield_added",0))
				var expected_target:="hero" if skill in ["barrier","mending"] else "enemy"
				if str(event.get("target",""))!=expected_target:errors.append("Selected skill contacted the wrong target")
	if not started:errors.append("No fight began")
	if observer.start_count!=1:errors.append("Timeline did not start exactly once")
	if fight_age<FIGHT_SECONDS:errors.append("Fight ended before the 22-second observation window")
	if selected_starts<2:errors.append("Fewer than two actual selected-skill casts")
	if selected_contacts<1:errors.append("Selected skill never reached actual contact")
	if innate_starts<1:errors.append("Equipped innate never fired")
	if basics<1:errors.append("No basic attacks were interspersed")
	if enemy_damage<=0:errors.append("Fixture had no actual incoming HP damage")
	if skill=="mending" and healing<=0:errors.append("Mending never restored actual HP")
	if skill=="barrier" and (shield_added<=0 or shield_absorbed<=0):errors.append("Barrier never both added and absorbed actual damage")
	for key in ["attack","defense","max_hp","combat_qi_max","combat_qi_regen","active_skills","weapon_skill","heart_method","passive_methods"]:
		if observer.initial_hero.get(key)!=expected_stats.get(key):errors.append("Effective state stat was changed: "+key)
	if not sanity:
		for tag in ["skill-strike","skill-contact","weapon-strike","basic-contact"]:
			if not captured.has(tag):errors.append("Missing actual rendered "+tag+" screenshot")
	return {"passed":errors.is_empty(),"errors":errors,"selected_starts":selected_starts,"selected_contacts":selected_contacts,
		"innate_starts":innate_starts,"basic_starts":basics,"incoming_hp_damage":enemy_damage,"healed":healing,
		"shield_added":shield_added,"shield_absorbed":shield_absorbed,"fight_seconds":fight_age,"timeline_starts":observer.start_count}


func _finish():
	if not sanity and is_instance_valid(scene):
		await RenderingServer.frame_post_draw
		_capture_frame("final",observer.pose())
	var validation:=_validation()
	var report:Dictionary={"skill":skill,"preset_fixture":true,"campaign_earned":false,"normal_speed_native":not sanity,
		"headless_sanity":sanity,"seed":SEED,"duration_seconds":FIGHT_SECONDS,"validation":validation,
		"state_stats":expected_stats,"initial_hero":observer.initial_hero,"initial_enemy":observer.initial_enemy,
		"events":observer.recorded_events,"samples":samples,"captures":captures,"phases":phase_events,
		"final_resources":observer.battle_resource_snapshot(),"final_hero_hp":observer.hero_hp,"final_enemy_hp":observer.enemy_hp}
	var output:=FileAccess.open(capture_prefix+"-events.json",FileAccess.WRITE)
	if output:
		output.store_string(JSON.stringify(report,"  "))
		output.close()
	else:
		validation.passed=false
		validation.errors.append("Could not write JSON evidence")
	print("SKILL_CYCLE_COMPLETE "+JSON.stringify(validation))
	if not sanity and RenderingServer.frame_post_draw.is_connected(_on_rendered_frame):
		RenderingServer.frame_post_draw.disconnect(_on_rendered_frame)
	var isolated_path:String=scene.state.save_path
	scene.queue_free()
	scene=null
	await process_frame
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(isolated_path+suffix):DirAccess.remove_absolute(isolated_path+suffix)
	call_deferred("quit",0 if bool(validation.passed) else 1)
