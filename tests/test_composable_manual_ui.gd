extends SceneTree
## Real paper controls: taxonomy is independent from finite loadout slots.
const Ink=preload("res://scripts/ink_pages.gd")
var scene
var checks:=0
var failures:=0
var save_path:="user://composable_manual_ui_%d.json"%OS.get_process_id()

func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)

func press(key:String,force:bool=false):
	var b=scene.buttons.get(key)
	check(is_instance_valid(b),"Button exists: "+key)
	if not is_instance_valid(b):return
	check(force or not b.disabled,"Button enabled: "+key)
	if force or not b.disabled:b.pressed.emit()

func inspect(id:String):
	press("tech_category_all")
	var rows:Array=scene.state.technique_rows()
	var index:=0
	for i in range(rows.size()):
		if str(rows[i].id)==id:index=i;break
	for _i in range(index/Ink.MANUALS_PER_PAGE):press("tech_next")
	press("equip_"+id)

func row(id:String)->Dictionary:
	for entry in scene.state.technique_rows():
		if entry.id==id:return entry
	return {}

func snapshot()->Array:
	return [scene.state.equipped_heart,scene.state.equipped_weapon_art,scene.state.equipped_actives.duplicate(),scene.state.equipped_passives.duplicate(),scene.state.technique_levels.duplicate(),scene.state.gear.equipped.duplicate(),scene.character_x,scene.character_y,scene.world_route,scene.meditation_amount]

func geometry(label:String):
	var paper:Rect2=scene._drawer_rect()
	var count:=0
	for child in scene.drawer.get_children():
		if child is BaseButton:
			check(paper.encloses(Rect2(child.position,child.size)),"Fits paper: "+label+" / "+child.text)
	for id in scene.state.Content.TECHNIQUES:
		if is_instance_valid(scene.buttons.get("equip_"+str(id))):count+=1
	check(count<=3,"At most three readable manual rows: "+label)

func finish_training():
	var duration:=0.0
	for training in scene.state.technique_training:duration=maxf(duration,float(training.remaining))
	scene.state.step(duration+0.05)
	scene._refresh_drawer()

func _initialize():call_deferred("run")

func run():
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path=save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false);scene.demo=true
	scene.state.new_game();scene.state.auto_advance=false
	scene._toggle_drawer("wardrobe");press("wardrobe_technique")
	check(scene.state.Content.TECHNIQUES.size()==10,"Finite ten-manual catalog")
	check(Ink.MANUAL_FILTERS.size()==8,"Seven multi-tags plus all filter")
	for width in [1000,1200,1360]:
		scene.size=Vector2(width,320)
		for filter in Ink.MANUAL_FILTERS:
			press("tech_category_"+filter);geometry(str(width)+" / "+filter)
			var rows:Array=Ink._manual_rows(scene)
			for _i in range(maxi(0,ceili(rows.size()/3.0)-1)):
				press("tech_next");geometry(str(width)+" / "+filter+" next")
			check(scene.buttons.tech_next.disabled,"Final tag page bounded")
	scene.size=Vector2(1200,320)
	var before:=snapshot()
	for id in scene.state.Content.TECHNIQUES:
		inspect(str(id))
		check(snapshot()==before,"Inspection cannot activate any slot: "+str(id))
		check(scene.character_preview.displayed_technique()==id,"Portrait follows inspected book: "+str(id))
		press("practice_preview")
		scene.character_preview.advance(0.75,true)
		check(snapshot()==before and scene._scene_camera_transform()==Transform2D.IDENTITY,"Demonstration never moves world: "+str(id))
		if float(row(str(id)).qi_cost)<=0:
			check(not scene.character_preview._motion.has("attack_phase"),"Passive manual has quiet aura, no repeated attack: "+str(id))
		else:
			check(scene.character_preview._cast_strength>0,"Active manual has visible local effect: "+str(id))
	inspect("petal")
	check(scene.buttons.train_technique.disabled,"Realm lock remains visible on locked book")
	check(scene.buttons.train_technique.tooltip_text.contains("炼气中期"),"Tooltip states unlocking realm")

	# Training has a real duration and never equips by inspecting or finishing.
	scene.state.realm=4;scene.state.herbs=10000;scene.state.dew=10000;scene._refresh_drawer()
	inspect("petal")
	var slots_before:=snapshot().slice(0,4)
	var herbs_before:int=scene.state.herbs
	var cost:int=row("petal").cost_herbs
	press("train_technique")
	check(scene.state.technique_levels.petal==0 and row("petal").training,"Training queues before rank is earned")
	check(scene.state.herbs==herbs_before-cost,"Queue pays the displayed materials once")
	check(scene.buttons.train_technique.disabled,"Duplicate training disabled")
	finish_training()
	check(scene.state.technique_levels.petal==1 and snapshot().slice(0,4)==slots_before,"Training completion preserves explicit slots")
	check(not row("petal").compatible,"Unarmed hero is incompatible with fan book")
	press("manual_slot_weapon_art")
	check(scene.state.equipped_weapon_art=="petal" and not row("petal").active,"Wrong-weapon choice stays selected but inactive")
	check(scene.state.gear.equipped_item("weapon").is_empty(),"Weapon form never auto-equips a weapon")
	check(scene.buttons.manual_slot_weapon_art.text=="卸下武式","Form slot has explicit removal")
	check(scene.buttons.manual_slot_active.text=="装入主动","Form and active selections remain independent")
	press("manual_slot_active")
	check(scene.state.equipped_actives.has("petal") and scene.state.equipped_actives.has("mist"),"Two active slots coexist at realm three")
	press("manual_slot_active")
	check(not scene.state.equipped_actives.has("petal") and scene.state.equipped_weapon_art=="petal","Removing active does not remove form")
	press("manual_slot_weapon_art")
	check(scene.state.equipped_weapon_art.is_empty(),"Form can be independently removed")
	press("attune_technique")
	check(not scene.state.attuned_techniques.has("petal") and scene.state.technique_levels.petal==1,"Shelving retains learned rank")
	press("attune_technique")
	check(scene.state.attuned_techniques.has("petal"),"Shelf book can be attuned again")

	# Quotes are reviewable, cancellation is free, and heart switching is explicit.
	scene.state.realm=9;scene.state.qi=10000;scene.state.merit=10000
	scene.state.technique_levels.stillness=1
	if not scene.state.attuned_techniques.has("stillness"):scene.state.attune_technique("stillness")
	inspect("breath")
	if scene.state.equipped_heart!="breath":
		press("manual_slot_heart")
		check(is_instance_valid(scene.buttons.confirm_heart_switch),"First heart requires explicit confirmation")
		press("confirm_heart_switch")
	inspect("stillness")
	var resources:=[scene.state.qi,scene.state.herbs,scene.state.dew]
	press("manual_slot_heart")
	var quote:Dictionary=scene.get_meta("ink_heart_quote",{})
	check(not quote.is_empty() and quote.to_id=="stillness" and quote.from_id=="breath","Quote identifies actual old/new heart")
	check(resources==[scene.state.qi,scene.state.herbs,scene.state.dew] and scene.state.equipped_heart=="breath","Opening quote is free and keeps old heart")
	check(float(quote.duration)>0 and int(quote.cost.herbs)>0,"Switch quote has real cost and time")
	geometry("Heart cost confirmation")
	press("cancel_heart_switch")
	check(resources==[scene.state.qi,scene.state.herbs,scene.state.dew] and scene.state.pending_heart_switch.is_empty(),"Cancelling review spends nothing")
	press("manual_slot_heart");press("confirm_heart_switch")
	check(not scene.state.pending_heart_switch.is_empty() and scene.state.equipped_heart=="breath","Confirmed paid switch keeps old heart while settling")
	check(scene.state.technique_levels.stillness==1,"Switch preserves ranks")
	scene.state.step(float(scene.state.pending_heart_switch.remaining)+0.1);scene._refresh_drawer()
	check(scene.state.equipped_heart=="stillness" and scene.state.pending_heart_switch.is_empty(),"Paid timer installs chosen heart exactly once")

	# Live-combat callbacks cannot bypass disabled buttons or charge resources.
	inspect("petal")
	scene.encounter_active=true;scene.encounter_phase="fight";scene._refresh_drawer()
	before=snapshot();resources=[scene.state.qi,scene.state.herbs,scene.state.dew]
	for key in ["train_technique","attune_technique","manual_slot_weapon_art","manual_slot_active"]:
		check(scene.buttons[key].disabled,"Live lock disables "+key)
		press(key,true)
	check(snapshot()==before and resources==[scene.state.qi,scene.state.herbs,scene.state.dew],"Forced stale callback cannot mutate live loadout")
	press("practice_preview")
	check(scene.character_preview.cast_time>0 and snapshot()==before,"Live lock still permits local preview")
	scene.encounter_active=false;scene.encounter_phase="idle";scene._close_drawer();scene.character_preview.advance(0.0,false)
	check(scene.character_preview.cast_time==0,"Closing book clears demonstration")
	scene.queue_free();await process_frame;await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	print("Composable manual UI: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
