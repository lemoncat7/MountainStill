extends SceneTree
const Pages = preload("res://scripts/equipment_comparison_pages.gd")
const Ink = preload("res://scripts/ink_pages.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://comparison_ui_%d.json" % OS.get_process_id()
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+label)
func press(key: String):
	var button=scene.buttons.get(key)
	check(is_instance_valid(button),"button exists "+key)
	if not is_instance_valid(button):return
	check(not button.disabled,"button enabled "+key)
	if not button.disabled:button.pressed.emit()
func button_key(button) -> String:
	for key in scene.buttons:
		if scene.buttons[key]==button:return str(key)
	return str(button.name)
func geometry(label: String):
	var paper: Rect2=scene._drawer_rect()
	var controls: Array=[]
	for child in scene.drawer.get_children():
		if child is BaseButton and child.visible:
			var rect:=Rect2(child.position,child.size)
			check(paper.encloses(rect),"inside paper "+label+" "+child.name)
			for other in controls:check(not rect.intersects(Rect2(other.position,other.size)),"no overlap "+label+" "+button_key(child)+str(rect)+" "+button_key(other)+str(Rect2(other.position,other.size)))
			controls.append(child)
func open_comparison(id: int):
	scene.wardrobe_tab="equipment"
	scene.selected_item=id
	scene.set_meta("combat_insight_open",false)
	scene.set_meta("equipment_comparison_open",false)
	if scene.drawer_name!="wardrobe":scene._toggle_drawer("wardrobe")
	else:scene._refresh_drawer()
	geometry("equipment")
	press("compare_selected")
func run():
	check(Pages._delta(0.002,2)=="微增<0.01","small gain never prints positive zero")
	check(Pages._delta(-0.002,2)=="微降<0.01","small loss never prints negative zero")
	check(Pages._delta(0.0,2)=="不变","zero truly unchanged")
	var tiny = preload("res://scripts/cultivation_state.gd").new()
	var cloth: int = tiny.gear.add_item_spec({"template_id":"feet_cloth","rarity":"common","level":1}).item.id
	var boots: int = tiny.gear.add_item_spec({"template_id":"feet_boots","rarity":"common","level":1}).item.id
	tiny.equip_item(cloth)
	check(Pages.rows(tiny.equipment_comparison(boots))[3].value.contains("微增<0.01"),"real shoes tiny qi gain visible")
	tiny.equip_item(boots)
	check(Pages.rows(tiny.equipment_comparison(cloth))[3].value.contains("微降<0.01"),"real shoes tiny qi loss visible")
	for template in ["head_crown","chest_jade","legs_jade","feet_boots","weapon_fan"]:
		var capped_id: int = tiny.gear.add_item_spec({"template_id":template,"rarity":"epic","level":100}).item.id
		for rank in range(5):tiny.gear.enhance_item(capped_id)
		tiny.equip_item(capped_id)
	var capped_quote: Dictionary = tiny.equipment_comparison(int(tiny.gear.equipped.weapon))
	check(is_equal_approx(float(capped_quote.after_gear.qi_bonus),0.35),"equipment qi cap actually reached")
	check(Pages.rows(capped_quote)[3].source.contains("装备吐纳") and Pages.rows(capped_quote)[3].source.contains("封顶35%"),"cap clearly belongs to equipment bonus")
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path=save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.demo=true
	scene.state.new_game()
	scene.state.auto_advance=false
	var sword: int=scene.state.gear.add_item_spec({"template_id":"weapon_sword","rarity":"common","level":1}).item.id
	var fan: int=scene.state.gear.add_item_spec({"template_id":"weapon_fan","rarity":"rare","level":3}).item.id
	scene.state.equip_item(sword)
	var original: Dictionary=scene.state.gear.to_dict().duplicate(true)
	var qi: float=scene.state.qi
	var herbs: int=scene.state.herbs
	for width in [960,1000,1200,1440]:
		scene.size=Vector2(width,540 if width==960 else 320)
		open_comparison(fan)
		check(Pages.is_open(scene),"opened comparison")
		check(scene.buttons.comparison_prev.disabled,"first page bounded")
		var rows: Array=scene.get_meta("equipment_comparison_rows")
		for i in range(ceili(rows.size()/2.0)):
			geometry("comparison %d page %d" % [width,i])
			if i+1<ceili(rows.size()/2.0):press("comparison_next")
		check(scene.buttons.comparison_next.disabled,"last page bounded")
		for row in rows:
			var wrapped: Array=Ink._wrapped_lines(str(row.source),597,Pages.BODY_FONT_SIZE,2)
			check(not wrapped[-1].ends_with("…"),"source complete "+str(row.label))
			check(Ink.SANS.get_string_size(str(row.value),HORIZONTAL_ALIGNMENT_LEFT,-1,Pages.BODY_FONT_SIZE).x<=390,"value fits "+str(row.label))
			check(Ink.SANS.get_string_size(str(row.label),HORIZONTAL_ALIGNMENT_LEFT,-1,Pages.BODY_FONT_SIZE).x<=205,"label fits "+str(row.label))
		press("comparison_back")
		check(not Pages.is_open(scene),"back closes")
	check(scene.state.gear.to_dict()==original,"browsing no gear/RNG mutation")
	check(scene.state.qi==qi and scene.state.herbs==herbs,"browsing no spending")
	open_comparison(fan)
	var stale=scene.buttons.comparison_equip
	scene.encounter_active=true
	scene.encounter_phase="fight"
	stale.pressed.emit()
	check(scene.state.gear.equipped_item("weapon").id==sword,"stale equip rechecks fight lock")
	scene._refresh_drawer()
	check(scene.buttons.comparison_equip.disabled,"fight locks equip")
	press("comparison_next")
	geometry("fight may browse")
	scene.encounter_active=false
	scene.encounter_phase="idle"
	scene._refresh_drawer()
	check(scene.state.gear.equipped_item("weapon").id==sword,"no queued auto equip after fight")
	press("comparison_equip")
	check(scene.state.gear.equipped_item("weapon").id==fan,"explicit equip changes same slot")
	check(scene.buttons.comparison_equip.disabled,"same item disabled")
	var quote: Dictionary=scene.get_meta("equipment_comparison_quote")
	check(quote.before==quote.after,"same item has no changes")
	press("wardrobe_technique")
	press("wardrobe_equipment")
	check(not Pages.is_open(scene),"tab dismissal does not reopen")
	test_method_variants(sword,fan)
	scene.state.unequip_slot("weapon")
	open_comparison(sword)
	check(scene.get_meta("equipment_comparison_quote").equipped_item.is_empty(),"empty slot supported")
	press("comparison_back")
	open_comparison(sword)
	scene.state.gear.remove_item(sword)
	scene._refresh_drawer()
	check(not scene.get_meta("equipment_comparison_quote").ok,"removed item gracefully invalid")
	geometry("removed item")
	press("comparison_back")
	check(scene.buttons.compare_selected.disabled,"missing candidate entry disabled")
	var scale: float=preload("res://scripts/readability_layout.gd").effective_scale(Vector2i(960,540),1.5)
	check(Pages.BODY_FONT_SIZE*scale>=12,"minimum readable body")
	check(Pages.NOTE_FONT_SIZE*scale>=11,"minimum readable note")
	scene.queue_free()
	await process_frame
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	print("Equipment comparison UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)


func readable_rows(label: String) -> Array:
	var rows: Array=scene.get_meta("equipment_comparison_rows")
	check(not rows.is_empty(),label+" has rows")
	for row in rows:
		var wrapped: Array=Ink._wrapped_lines(str(row.source),597,Pages.BODY_FONT_SIZE,2)
		check(not wrapped.is_empty() and not str(wrapped[-1]).ends_with("…"),label+" complete source "+str(row.label))
		check(Ink.SANS.get_string_size(str(row.value),HORIZONTAL_ALIGNMENT_LEFT,-1,Pages.BODY_FONT_SIZE).x<=390,label+" value fits "+str(row.label))
		check(Ink.SANS.get_string_size(str(row.label),HORIZONTAL_ALIGNMENT_LEFT,-1,Pages.BODY_FONT_SIZE).x<=205,label+" label fits "+str(row.label))
	for i in range(ceili(rows.size()/2.0)):
		geometry(label+" page %d"%i)
		if i+1<ceili(rows.size()/2.0):press("comparison_next")
	check(scene.buttons.comparison_next.disabled,label+" bounded final page")
	return rows

func row_starting(rows: Array, prefix: String) -> Dictionary:
	for row in rows:
		if str(row.label).begins_with(prefix):return row
	return {}

func test_method_variants(sword: int,fan: int):
	scene.size=Vector2(960,540)
	scene.state.realm=12
	scene.state.technique_levels.petal=5
	scene.state.attuned_techniques.assign(["mist","petal","breath"])
	scene.state.equipped_heart="breath"
	scene.state.equipped_weapon_art="petal"
	scene.state.equipped_actives.assign(["mist","petal"])
	scene.state.equip_item(sword)
	open_comparison(fan)
	var rows:=readable_rows("two active petal")
	var quote: Dictionary=scene.get_meta("equipment_comparison_quote")
	check(quote.before.weapon_art.movement_active and quote.after.weapon_art.movement_active,"petal movement stays active with either weapon")
	check(not quote.before.weapon_art.active and quote.after.weapon_art.active,"petal weapon form becomes available with fan")
	check(str(row_starting(rows,"武式").value)=="条件不满足 → 条件满足","form row reflects compatibility")
	check(str(row_starting(rows,"主动1").value)=="条件满足 → 条件不满足","mist active becomes unavailable with fan")
	check(str(row_starting(rows,"主动2").value)=="条件不满足 → 条件满足","petal active becomes available with fan")
	check(quote.before.evasion_chance==quote.after.evasion_chance,"movement not lost on sword/fan swap")
	press("comparison_back")

	# A form alone must not be represented as an active action/skill slot.
	scene.state.equipped_actives.clear()
	open_comparison(fan)
	rows=readable_rows("form only no active")
	check(str(row_starting(rows,"主动1").value)=="未装配 → 未装配","empty active slot represented without inferred skill")
	check(str(row_starting(rows,"武式").source).contains("不是主动栏"),"form explicitly distinct from active lane")
	check(scene.get_meta("equipment_comparison_quote").after.active_skills.is_empty(),"form-only preview adds no active skills")
	press("comparison_back")

	scene.state.equipped_weapon_art=""
	scene.state.equipped_actives.assign(["petal"])
	open_comparison(fan)
	rows=readable_rows("active only no form")
	check(str(row_starting(rows,"武式").value)=="未装配 → 未装配","active-only does not infer passive form")
	check(str(row_starting(rows,"主动1").value)=="条件不满足 → 条件满足","active-only compatibility shown")
	check(scene.get_meta("equipment_comparison_quote").after.weapon_art.is_empty(),"active-only preview adds no form")
	press("comparison_back")

	# Both compatible and incompatible weapons must not imply eligibility.
	scene.state.equipped_weapon_art="petal"
	for condition in ["unattuned","realm locked","unlearned"]:
		scene.state.realm=12
		scene.state.technique_levels.petal=5
		scene.state.attuned_techniques.assign(["mist","petal","breath"])
		if condition=="unattuned":scene.state.attuned_techniques.erase("petal")
		elif condition=="realm locked":scene.state.realm=0
		else:scene.state.technique_levels.petal=0
		for candidate in [fan,sword]:
			open_comparison(candidate)
			rows=readable_rows(condition+" candidate %d"%candidate)
			quote=scene.get_meta("equipment_comparison_quote")
			check(not quote.after.weapon_art.active and not quote.after.weapon_art.movement_active,condition+" no form or movement granted")
			check(not quote.after.active_skills[0].active,condition+" no active granted")
			check(str(row_starting(rows,"武式").value)=="条件不满足 → 条件不满足",condition+" UI never implies availability")
			check(not str(row_starting(rows,"武式").source).contains("身法按装配生效"),condition+" no unconditional movement promise")
			press("comparison_back")

	scene.state.realm=15
	scene.state.technique_levels.petal=5
	scene.state.attuned_techniques.assign(["mist","petal","breath"])
	scene.state.equipped_actives.assign(["mist","petal"])
	while scene.state.inventory.size()<scene.state.Equipment.CAPACITY:
		scene.state.gear.add_item_spec({"template_id":"feet_boots","rarity":"epic","level":100})
	var last_id: int=scene.state.inventory[-1].id
	for rank in range(5):scene.state.gear.enhance_item(last_id)
	var original: Dictionary=scene.state.gear.to_dict().duplicate(true)
	open_comparison(last_id)
	rows=readable_rows("full bag enhanced maximum item")
	quote=scene.get_meta("equipment_comparison_quote")
	check(quote.inventory_count==100 and quote.inventory_capacity==100,"full inventory accurately displayed")
	check(str(row_starting(rows,"行箧").label)=="行箧 100 / 100","full inventory label readable and accurate")
	check(not scene.buttons.comparison_equip.disabled,"full bag permits explicit equip")
	check(scene.state.gear.to_dict()==original,"full bag browsing read only")
	press("comparison_equip")
	check(scene.state.gear.equipped_item("feet").id==last_id,"full bag explicit equip succeeds")
	check(scene.state.inventory.size()==100,"full bag swap does not remove items")
	press("comparison_back")
	scene.state.equip_item(fan)
