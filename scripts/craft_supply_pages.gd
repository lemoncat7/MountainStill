extends RefCounted
## Read-only ingredient planning. Links never select a live route or transact.
const Registry = preload("res://scripts/material_registry.gd")
const Content = preload("res://scripts/cultivation_content.gd")

static func clear(h):
	h.set_meta("craft_supply_open",false)
	h.set_meta("craft_supply_trail",[])

static func is_open(h)->bool:
	return bool(h.get_meta("craft_supply_open",false))

static func has_return(h)->bool:
	return not h.get_meta("craft_supply_trail",[]).is_empty()

static func current(h)->Dictionary:
	return h.InkPages._craft_selected(h)

static func rows(h)->Array:
	var result:Array=[]
	for cost in current(h).get("costs",[]):
		var row:Dictionary=cost.duplicate(true)
		row.missing=maxi(0,int(cost.count)-int(cost.owned))
		row.kind="";row.target="";row.label="";row.gate=""
		var id:String=str(cost.id)
		row.source=str(Registry.material(id).get("source",""))
		if id=="refinement_stone":
			row.kind="recipe";row.target="refine_stone";row.label="查看合成 ↗"
			row.source="灵息碎屑或山材合成；不会自动消耗。"
		else:
			for stage in h.state.stage_rows():
				var definition:Dictionary=Content.STAGES[str(stage.id)]
				var route:Dictionary=Registry.ROUTES.get(str(definition.biome),{})
				if id in ["spirit_shard","spirit_jade"] or str(route.get("material_id",""))==id:
					row.kind="route";row.target=str(stage.id);row.label="查看山路 ↗"
					row.gate=h.InkPages.Adventure._chapter_gate(h,stage)
					if id=="spirit_shard":row.source="六章击退守灵后搜取遗物，每敌 1 枚。"
					elif id=="spirit_jade":row.source="六章搜取遗物独立 1% 概率，无保底。"
					else:row.source=str(stage.name)+" · 击退守灵后亲手搜取遗物。"
					break
		result.append(row)
	return result

static func _valid(h,drawer)->bool:
	return is_instance_valid(drawer) and h.drawer==drawer and h.drawer_name=="wardrobe" and not h.closing

static func open(h):
	h.set_meta("craft_supply_open",true);h._refresh_drawer()

static func return_to_recipe(h):
	var trail:Array=h.get_meta("craft_supply_trail",[])
	if trail.is_empty():return
	var context:Dictionary=trail.pop_back()
	h.set_meta("craft_supply_trail",trail)
	h.wardrobe_tab="bag";h.set_meta("bag_view","craft")
	h.set_meta("craft_recipe",context.recipe)
	if not str(context.material).is_empty():h.set_meta("craft_material_"+str(context.recipe),context.material)
	h.set_meta("craft_supply_open",true);h._refresh_drawer()

static func follow(h,id:String,drawer):
	if not _valid(h,drawer) or h.wardrobe_tab!="bag" or not is_open(h):return
	# Resolve current costs again; stale links cannot switch a newer recipe.
	var found:Dictionary={}
	for row in rows(h):
		if str(row.id)==id:found=row;break
	if found.is_empty() or str(found.kind).is_empty():return
	var quote:Dictionary=current(h)
	var trail:Array=h.get_meta("craft_supply_trail",[])
	trail.append({"recipe":str(quote.id),"material":str(quote.get("selected_material",""))})
	h.set_meta("craft_supply_trail",trail)
	h.set_meta("craft_supply_open",false)
	if str(found.kind)=="recipe":
		h.InkPages.inspect_craft(h,str(found.target),true)
	else:
		# Do not call _inspect_chapter: that may select a route when idle.
		h.set_meta("ink_abandon_confirm","")
		h.wardrobe_tab="expedition";h.set_meta("ink_stage_id",str(found.target));h.set_meta("expedition_view","route")
		var stages:Array=h.state.stage_rows()
		for i in range(stages.size()):
			if str(stages[i].id)==str(found.target):h.set_meta("ink_stage_page",i/h.InkPages.Adventure.CHAPTERS_PER_PAGE);break
		h._refresh_drawer()

static func build_return(h,r:Rect2):
	var drawer=h.drawer
	h._qbutton(h.drawer,"craft_supply_return","返回百工 ↩",r,func():
		if _valid(h,drawer):return_to_recipe(h),"回到刚才的配方与用料；只翻页，不制作、不出发。")

static func build(h,x:float,y:float):
	var drawer=h.drawer
	h._qbutton(h.drawer,"craft_supply_close","返回配方",Rect2(x+430,y+60,174,25),func():
		if _valid(h,drawer):h.set_meta("craft_supply_open",false);h._refresh_drawer(),"保留当前配方与亲选用料。")
	if has_return(h):build_return(h,Rect2(x+232,y+60,180,25))
	var entries:Array=rows(h)
	for i in range(entries.size()):
		var row:Dictionary=entries[i]
		var id:String=str(row.id)
		if not str(row.kind).is_empty():
			h._qbutton(h.drawer,"craft_supply_"+id,str(row.label),Rect2(x+458,y+129+i*65,146,27),func():follow(h,id,drawer),str(row.source)+"\n"+str(row.gate)+"\n只查看，不自动出发或消耗材料。")

static func draw(h,x:float,y:float,a:float):
	var ink=h.InkPages
	var quote:Dictionary=current(h)
	ink._txt(h,ink._ellipsis("备料 · "+str(quote.get("name","")),600,16),Vector2(x,y+111),16,a,ink.INK,true)
	var entries:Array=rows(h)
	for i in range(entries.size()):
		var row:Dictionary=entries[i]
		var yy:float=y+136+i*65
		var count_text:String="还缺 %d"%int(row.missing) if int(row.missing)>0 else "已齐备"
		ink._txt(h,"%s · 已有 %d / 需 %d · %s"%[row.name,row.owned,row.count,count_text],Vector2(x,yy),13,a,ink.RED if int(row.missing)>0 else ink.JADE)
		ink._txt(h,ink._ellipsis(str(row.source),445,11),Vector2(x,yy+18),11,a,ink.FADED)
		ink._txt(h,ink._ellipsis(str(row.gate),600,11),Vector2(x,yy+36),11,a,ink.FADED)
		ink._rule(h,Vector2(x,yy+44),Vector2(x+604,yy+44),a)
	ink._txt(h,"只作备料参考；解锁、容量和交锋限制仍按原规则检查。",Vector2(x,y+269),11,a,ink.FADED)
