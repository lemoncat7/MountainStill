extends SceneTree
## Real host/state/timeline integration. Saves and strong-enemy fixtures are
## isolated; fixtures do not claim naturally earned balance or visual proof.
var scene
var checks:=0
var failures:=0
var save_path:="user://battle_resource_host_%d.json"%OS.get_process_id()


func check(value:bool,label:String):
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: "+label)


func advance(seconds:float):
	for frame in range(ceili(seconds*60.0)):scene._process(1.0/60.0)


func until(predicate:Callable,seconds:float,label:String)->bool:
	for frame in range(ceili(seconds*60.0)):
		if predicate.call():
			check(true,label)
			return true
		scene._process(1.0/60.0)
	check(false,label+" (phase="+str(scene.encounter_phase)+")")
	return false


func resource_equal(a:Dictionary,b:Dictionary)->bool:
	if not is_equal_approx(float(a.get("qi",-1)),float(b.get("qi",-2))):return false
	var ac:Dictionary=a.get("cooldowns",{})
	var bc:Dictionary=b.get("cooldowns",{})
	if ac.keys().size()!=bc.keys().size():return false
	for id in ac:
		if not is_equal_approx(float(ac[id]),float(bc.get(id,-1.0))):return false
	return true


func fixture(style:String="sword",actives:Array=[],realm:int=4):
	scene._close_drawer()
	scene.drawer_alpha=0.0
	scene._reset_presentation()
	scene.state.new_game()
	scene.state.save_path=save_path
	scene.state.auto_advance=false
	scene.state.realm=realm
	scene.state.gear.inventory=[
		scene.state.gear._make_item(1,"weapon_sword","common",1),
		scene.state.gear._make_item(2,"weapon_fan","common",1)]
	if style!="unarmed":scene.state.equip_item(1 if style=="sword" else 2)
	if not actives.is_empty():
		# Explicit learned-book fixture; actual attune/equip APIs still choose
		# the slots. Natural training and earning are covered by state tests.
		for id in scene.state.equipped_actives.duplicate():scene.state.unequip_technique(id,"active")
		for id in actives:
			scene.state.technique_levels[id]=1
			check(bool(scene.state.attune_technique(id).ok),"Fixture attunes its learned book: "+str(id))
			check(bool(scene.state.equip_technique(id,"active").ok),"Actual slot API equips book: "+str(id))
		var heart_quote:Dictionary=scene.state.quote_heart_switch("breath")
		check(bool(heart_quote.get("ok",false)) and bool(scene.state.confirm_heart_switch(heart_quote).get("ok",false)),"Fixture chooses the initial passive heart through confirmation API")
		scene.state.technique_levels.body=1
		check(bool(scene.state.attune_technique("body").ok) and bool(scene.state.equip_technique("body","passive").ok),"Fixture fills actual passive-method slot")
	scene.character_x=520.0
	scene.character_y=230.0
	scene.meditation_amount=0.0
	scene.demo=true
	scene._start_encounter()
	until(func():return scene.encounter_phase=="travel",5.0,"Explicit departure completes portal")


func begin_depleted_duel(enemy_hp:int=100000):
	var depleted:Dictionary=scene.state.stage_battle_resources()
	depleted.qi=0.0
	for id in depleted.cooldowns:depleted.cooldowns[id]=3.0
	var result:Dictionary=scene.state.update_stage_battle_resources(scene.encounter_run_id,depleted)
	check(bool(result.get("ok",false)),"Current active run accepts the depleted fixture")
	scene.battle_resources=scene.state.stage_battle_resources()
	scene.route_distance=scene.route_target_distance
	scene._update_enemy_route_position()
	scene.route_enemy_definition.hp=enemy_hp
	scene.route_enemy_definition.attack=1
	scene.route_enemy_definition.defense=0
	scene._begin_duel()


func _initialize():
	call_deferred("run")


func run():
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path=save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.size=Vector2(1200,320)
	test_real_loadout_and_basics()
	test_pause_retreat_and_save()
	test_checkpoint_flush()
	test_between_encounter_hp_ceiling()
	test_active_field_clock()
	test_dynamic_active_slots()
	test_heart_adjustment_block()
	test_presentation_contract()
	scene.queue_free()
	await process_frame
	await process_frame
	for path in [save_path,save_path+".bak",save_path+".tmp",save_path+".offline",save_path+".offline.bak"]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("Battle resource host: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)


func test_real_loadout_and_basics():
	for style in ["sword","fan","unarmed"]:
		fixture(style)
		check(not scene._battle_strip_visible(),"Travel has no permanent combat dashboard")
		var effective:Dictionary=scene.state.stats()
		begin_depleted_duel()
		check(scene.duel._hero.weapon_skill==effective.weapon_skill,"Duel receives actual equipped innate skill: "+style)
		check(scene.duel._hero.active_skills==effective.active_skills,"Duel receives actual selected active slots: "+style)
		check(scene.duel._hero.heart_method==effective.heart_method,"Duel receives passive heart snapshot: "+style)
		check(scene.duel._hero.weapon_art==effective.weapon_art,"Duel receives basic-form snapshot: "+style)
		var hero:Dictionary=scene.duel.pose().hero
		check(str(hero.get("action_kind",""))=="basic","Zero qi begins a free basic: "+style)
		check(str(hero.get("basic_style",""))==style,"Zero-qi bodywork follows equipped weapon: "+style)
		check(scene._combat_effect_kind(hero)=="basic","Zero-qi basic cannot borrow selected active spell VFX: "+style)
		check(scene._battle_strip_visible(),"Only live fight exposes combat resource strip")
		scene._retreat_encounter()


func test_pause_retreat_and_save():
	fixture()
	begin_depleted_duel()
	advance(.4)
	var before:Dictionary=scene.state.stage_battle_resources()
	check(float(before.qi)>0.0 and float(before.qi)<float(scene.state.stats().combat_qi_max),"Live duel regenerates without filling the pool")
	scene._set_paused(true)
	advance(4.0)
	check(resource_equal(before,scene.state.stage_battle_resources()),"Pause freezes qi and every ability cooldown")
	scene._set_paused(false)
	advance(.2)
	var saved:Dictionary=scene.state.stage_battle_resources()
	check(scene._save_current(),"Actual host save flush succeeds")
	var loaded=scene.State.new()
	loaded.save_path=save_path
	loaded.load_game()
	check(resource_equal(saved,loaded.stage_battle_resources()),"Live-fight save restores remaining qi/CDs")
	check(not bool(loaded.stage_status().active),"Reload retains checkpoint without silently launching combat")
	var offline:Dictionary=scene.state._snapshot()
	offline.saved_at=int(Time.get_unix_time_from_system())-3600
	var file=FileAccess.open(save_path+".offline",FileAccess.WRITE)
	file.store_string(JSON.stringify(offline))
	file.close()
	var after_offline=scene.State.new()
	after_offline.save_path=save_path+".offline"
	after_offline.load_game()
	check(resource_equal(saved,after_offline.stage_battle_resources()),"One offline hour does not recharge battle resources")
	scene._retreat_encounter()
	var retained:Dictionary=scene.state.stage_battle_resources()
	check(resource_equal(saved,retained),"Retreat flushes before cancellation without a refill")
	until(func():return not scene.encounter_active,5.0,"Return portal finishes")
	advance(12.0)
	scene._start_practice()
	check(resource_equal(retained,scene.state.stage_battle_resources()),"Home and practice cannot clear the retained route resources")
	scene.practice_time=0.0
	scene._start_encounter()
	check(resource_equal(retained,scene.state.stage_battle_resources()),"Explicit retry preserves qi and ability-ID cooldowns")
	until(func():return scene.encounter_phase=="travel",5.0,"Retry portal reaches route")
	check(resource_equal(retained,scene.state.stage_battle_resources()),"Departure portal never advances battle resources")


func test_active_field_clock():
	fixture()
	var resources:Dictionary=scene.state.stage_battle_resources()
	resources.qi=1.0
	for id in resources.cooldowns:resources.cooldowns[id]=3.0
	scene.state.update_stage_battle_resources(scene.encounter_run_id,resources)
	scene.battle_resources=scene.state.stage_battle_resources()
	var before:Dictionary=scene.battle_resources.duplicate(true)
	var rate:=float(scene.state.stats().combat_qi_regen)
	scene._update_encounter(.25)
	var after:Dictionary=scene.state.stage_battle_resources()
	check(is_equal_approx(float(after.qi),float(before.qi)+rate*.25),"Only actual travel time restores the configured qi rate")
	for id in before.cooldowns:
		check(is_equal_approx(float(after.cooldowns[id]),maxf(0.0,float(before.cooldowns[id])-.25)),"Travel decrements retained cooldown: "+str(id))
	scene.encounter_phase="opportunity"
	before=scene.state.stage_battle_resources()
	scene._update_encounter(6.0)
	check(resource_equal(before,scene.state.stage_battle_resources()),"Waiting for a route choice adds no resource time")
	scene.encounter_phase="pickup"
	scene.encounter_phase_age=0.0
	scene.pickup_collect_started=-1.0
	scene._update_encounter(.25)
	after=scene.state.stage_battle_resources()
	check(is_equal_approx(float(after.qi),float(before.qi)+rate*.25),"Active pickup time advances the same resource clock")
	scene._retreat_encounter()


func test_checkpoint_flush():
	fixture()
	begin_depleted_duel(18)
	if not until(func():return scene.encounter_phase=="pickup",12.0,"Actual low-HP fixture ends through contact damage"):
		return
	check(int(scene.state.stage_status().kills)==0 and bool(scene.state.stage_corpse_status().get("pending",false)),"True first victory retains unpaid body until search")
	check(resource_equal(scene.duel.battle_resource_snapshot(),scene.state.stage_battle_resources()),"Reward commit flushes final duel qi/CDs before changing phase")
	check(float(scene.state.stage_battle_resources().qi)<float(scene.state.stats().combat_qi_max),"Encounter victory does not refill qi")
	if not until(func():return scene.encounter_phase=="travel",12.0,"Actual pickup advances to next encounter approach"):
		return
	check(int(scene.state.stage_status().kills)==1,"Completed close-range search commits exactly one checkpoint")
	var before:Dictionary=scene.state.stage_battle_resources()
	scene.route_distance=scene.route_target_distance
	scene._update_enemy_route_position()
	scene._begin_duel()
	var after:Dictionary=scene.duel.battle_resource_snapshot()
	check(float(after.qi)<=float(before.qi)+.0001,"Next encounter inherits remaining qi instead of resetting")
	for id in before.cooldowns:
		check(float(after.cooldowns.get(id,0.0))+.0001>=float(before.cooldowns[id]),"Next encounter never erases pending cooldown: "+str(id))
	scene._retreat_encounter()


func test_between_encounter_hp_ceiling():
	fixture()
	scene.vitality=83.0
	begin_depleted_duel(30)
	if not until(func():return scene.encounter_phase=="pickup",12.0,"Wounded fixture completes its real first encounter"):return
	if not until(func():return scene.encounter_phase=="travel",12.0,"Wounded fixture reaches between-encounter travel"):return
	var hp_before:=float(scene.vitality)
	var old_ceiling:=float(scene.vitality_max)
	scene.state.technique_levels.body=1
	check(bool(scene.state.attune_technique("body").ok) and bool(scene.state.equip_technique("body","passive").ok),"Body passive equips legally between encounters")
	var raised_ceiling:=float(scene.state.stats().max_hp)
	check(raised_ceiling>old_ceiling,"Equipped body adds a real state HP bonus")
	scene.route_distance=scene.route_target_distance
	scene._update_enemy_route_position()
	scene._begin_duel()
	check(scene.vitality_max==raised_ceiling and float(scene.duel.hero_max_hp)==raised_ceiling,"Next duel and visible HP bar use the latest higher ceiling")
	check(scene.vitality==hp_before and float(scene.duel.hero_hp)==hp_before,"Higher ceiling preserves wounds and grants no free healing")
	scene._retreat_encounter()

	fixture("sword",["barrier"],4)
	begin_depleted_duel(18)
	if not until(func():return scene.encounter_phase=="pickup",12.0,"Body-equipped fixture completes its real first encounter"):return
	if not until(func():return scene.encounter_phase=="travel",12.0,"Body-equipped fixture reaches between-encounter travel"):return
	hp_before=float(scene.vitality)
	old_ceiling=float(scene.vitality_max)
	check(bool(scene.state.unequip_technique("body","passive").ok),"Body passive removes legally between encounters")
	var lowered_ceiling:=float(scene.state.stats().max_hp)
	check(lowered_ceiling<old_ceiling and hp_before>lowered_ceiling,"Removal fixture has HP above the newly reduced maximum")
	scene.route_distance=scene.route_target_distance
	scene._update_enemy_route_position()
	scene._begin_duel()
	check(scene.vitality_max==lowered_ceiling and float(scene.duel.hero_max_hp)==lowered_ceiling,"Next duel and visible HP bar discard the removed passive ceiling")
	check(scene.vitality==lowered_ceiling and float(scene.duel.hero_hp)==lowered_ceiling,"Removing body clamps existing HP instead of retaining its bonus")
	scene._retreat_encounter()


func test_presentation_contract():
	fixture("fan")
	begin_depleted_duel()
	var snapshot:Dictionary=scene.duel.battle_resource_snapshot()
	var slots:Array=scene._battle_strip_slots(snapshot)
	check(slots.size()==snapshot.active_skills.size()+1,"Strip follows actual active-slot count plus innate")
	check(str(slots.back().id)==str(snapshot.weapon_id),"Strip identifies the actual equipped innate skill")
	check(scene._battle_skill_status({"id":"frost","available":true,"remaining":2.35,"ready":false})=="2.4s","Cooldown label reports real remaining seconds")
	check(scene._battle_skill_status({"id":"frost","available":true,"remaining":0.0,"ready":false})=="战气不足","Unaffordable ready-CD skill explicitly reports qi shortage")
	check(scene._battle_skill_status({"id":"mending","available":true,"remaining":0.0,"qi_cost":18.0,"ready":false},40.0)=="待疗伤","Unneeded healing is standby, not a false qi shortage")
	check(scene._battle_skill_status({"id":"barrier","available":true,"remaining":0.0,"qi_cost":16.0,"ready":false},40.0)=="护体中","Active shield is distinguished from an unavailable attack")
	check(scene._battle_skill_status({"id":"mist","action_kind":"weapon_art","available":false})=="兵器不合","Incompatible form/skill has explicit unavailable label")
	for effect in ["ember","frost","thunder","barrier","mending"]:
		var pose:Dictionary={"action_kind":"utility" if effect=="mending" else ("defense" if effect=="barrier" else "spell"),"skill_id":effect}
		check(scene._combat_effect_kind(pose)==effect,"Renderer selects actual active skill: "+effect)
	var sword:AudioStreamWAV=scene._basic_contact_stream("sword")
	var fan:AudioStreamWAV=scene._basic_contact_stream("fan")
	var hand:AudioStreamWAV=scene._basic_contact_stream("unarmed")
	check(sword.data!=fan.data and fan.data!=hand.data and sword.data!=hand.data,"Basic contact sounds are genuinely weapon-specific samples")
	for stream in [sword,fan,hand]:
		check(stream.get_length()>.04 and stream.get_length()<.15,"Physical contact sound remains a short restrained cue")
	scene.drawer_name="wardrobe"
	check(not scene._battle_strip_visible(),"Book hides combat strip without changing the world layout")
	scene.drawer_name=""
	scene._retreat_encounter()
	check(not scene._battle_strip_visible(),"Retreat removes combat dashboard immediately")


func test_dynamic_active_slots():
	for pair in [["barrier","mending"],["frost","thunder"]]:
		fixture("sword",pair,9)
		scene.route_distance=scene.route_target_distance
		scene._update_enemy_route_position()
		scene.route_enemy_definition.hp=100000
		scene.route_enemy_definition.attack=1
		scene.route_enemy_definition.defense=0
		scene.vitality-=25.0
		scene._begin_duel()
		var snapshot:Dictionary=scene.duel.battle_resource_snapshot()
		check(str(snapshot.heart_method_id)=="breath" and scene.duel._hero.passive_methods.size()==1,"Host captures heart and passive-method slots alongside active abilities")
		var slots:Array=scene._battle_strip_slots(snapshot)
		check(slots.size()==3,"Two chosen active abilities and one innate occupy the compact strip")
		check(str(slots[0].id)==str(pair[0]) and str(slots[1].id)==str(pair[1]),"Strip follows actual selected order, not fixed category lanes")
		var seen:Dictionary={}
		var saw_healing:=false
		var saw_shield:=false
		for frame in range(900):
			scene._process(1.0/60.0)
			var hero:Dictionary=scene.duel.pose().hero
			var id:=str(hero.get("skill_id",""))
			if not id.is_empty():
				seen[id]=true
				if id in pair:check(scene._combat_effect_kind(hero)==id,"Real action selects matching shape-specific VFX")
			if str(scene.hero_support_text).begins_with("+") and scene.hero_support_time>0:saw_healing=true
			if float(scene.duel.pose().get("shield",0.0))>0:saw_shield=true
			if seen.has(pair[0]) and seen.has(pair[1]) and (pair[0]!="barrier" or (saw_healing and saw_shield)):break
		check(seen.has(pair[0]) and seen.has(pair[1]),"Actual host runs both chosen paid abilities around basics")
		if pair[0]=="barrier":
			check(saw_shield,"Actual barrier creates a persistent visible shield value")
			check(saw_healing,"Actual mending creates positive healing feedback")
		check(not seen.has("breath") and not seen.has("body"),"Heart and passive method never occupy queued active actions")
		scene._retreat_encounter()


func test_heart_adjustment_block():
	scene._reset_presentation()
	scene.state.new_game()
	scene.state.auto_advance=false
	scene.state.realm=3
	scene.state.qi=1000
	scene.state.herbs=100
	scene.state.dew=100
	var initial:Dictionary=scene.state.quote_heart_switch("breath")
	check(bool(scene.state.confirm_heart_switch(initial).ok),"First heart fixture equips immediately")
	scene.state.technique_levels.stillness=1
	scene.state.attune_technique("stillness")
	var quote:Dictionary=scene.state.quote_heart_switch("stillness")
	check(bool(scene.state.confirm_heart_switch(quote).ok),"Paid heart replacement starts its actual adjustment")
	scene._start_encounter()
	check(not scene.encounter_active and scene.state.stage_run.is_empty(),"Pending heart adjustment cannot silently begin a route")
	check(scene.toast.contains("心法") and scene.toast.contains("调息"),"Host explains the actual heart-adjustment departure blocker")
