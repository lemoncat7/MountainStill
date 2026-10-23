extends RefCounted
## A quiet route through the existing paper books. Reading and links never
## award progress, spend resources, equip items or depart on the player's behalf.
const Ink = preload("res://scripts/ink_pages.gd")

static func status(h) -> Dictionary:
	if h.state.has_method("player_journey_status"):return h.state.player_journey_status()
	return {"id":"settle","title":"先安顿这一身","summary":"启封随身木箱，细看所得，再亲手穿戴。","detail":"石台札记会随真实进度记下眼前一事。","progress":"初入山中","action":"整理行装","kind":"equipment","target":"","phase":"settle","complete":false}

static func rows(h) -> Array:
	if h.state.has_method("player_journey_rows"):return h.state.player_journey_rows()
	return [{"id":"settle","title":"安顿山居","summary":"启封随身木箱，细看所得，再亲手穿戴。","done":false,"current":true}]

static func recommended(h) -> int:
	var roadmap:Array=rows(h)
	var phase:String=str(status(h).get("phase",""))
	for i in range(roadmap.size()):
		if str(roadmap[i].get("id",""))==phase:return i
	for i in range(roadmap.size()):
		if bool(roadmap[i].get("current",false)):return i
	return 0

static func selected(h) -> int:
	if bool(h.get_meta("ink_guide_follow_current",true)):return recommended(h)
	return clampi(int(h.get_meta("ink_guide_step",recommended(h))),0,maxi(0,rows(h).size()-1))

static func recommend(h):
	h.set_meta("ink_guide_follow_current",true)
	h.set_meta("ink_guide_step",recommended(h));h._refresh_drawer()

static func _open(h,book:String):
	if h.drawer_name==book:h._refresh_drawer()
	else:h._toggle_drawer(book)

static func navigate(h,kind:String,target:String=""):
	# An explicit journal destination supersedes our chapter reading detour.
	# Only clear overlays belonging to that detour; legacy entry behavior stays.
	if h.has_meta("chapter_practice_return"):
		h.remove_meta("chapter_practice_return")
		h.set_meta("combat_insight_open",false)
		h.set_meta("equipment_comparison_open",false)
	match kind:
		"equipment":
			var chosen:Dictionary={}
			for item in h.state.gear.inventory:
				if str(item.get("id",-1))==target or (not target.is_empty() and str(item.get("template_id",""))==target):chosen=item;break
			if chosen.is_empty():
				for item in h.state.gear.inventory:
					if not int(item.id) in h.state.gear.equipped.values():chosen=item;break
			if chosen.is_empty():chosen=h.state.gear.get_item(h.selected_item)
			if chosen.is_empty() and not h.state.gear.inventory.is_empty():chosen=h.state.gear.inventory[0]
			if not chosen.is_empty():
				h.selected_item=int(chosen.id);h.selected_slot=str(chosen.slot)
				h.inventory_page=h.state.gear.inventory.find(chosen)/3
			h.wardrobe_tab="equipment";_open(h,"wardrobe")
		"technique":
			h.wardrobe_tab="technique";h.set_meta("ink_manual_filter","all")
			var manuals:Array=h.state.technique_rows()
			for i in range(manuals.size()):
				if str(manuals[i].id)==target:
					h.set_meta("ink_manual_page",i/Ink.MANUALS_PER_PAGE);h.set_meta("ink_technique_id",target);h.set_meta("preview_technique",target);break
			h.set_meta("ink_heart_quote",{});_open(h,"wardrobe")
		"meridian":
			h.wardrobe_tab="meridian"
			for point in h.state.meridian_rows():
				if str(point.id)==target:
					h.set_meta("meridian_branch",str(point.branch));h.set_meta("meridian_id",target);h.set_meta("meridian_selected_"+str(point.branch),target);break
			_open(h,"wardrobe")
		"route":
			h.wardrobe_tab="expedition";h.set_meta("expedition_view","route")
			var route:String=target if not target.is_empty() else str(h.state.selected_stage)
			var chapters:Array=h.state.stage_rows()
			for i in range(chapters.size()):
				if str(chapters[i].id)==route:h.set_meta("ink_stage_id",route);h.set_meta("ink_stage_page",i/Ink.Adventure.CHAPTERS_PER_PAGE);break
			_open(h,"wardrobe")
		"crafting":
			h.wardrobe_tab="bag";h.set_meta("bag_view","craft")
			var parts:PackedStringArray=target.split(":")
			var recipe:String=parts[0] if not target.is_empty() else "refine_stone"
			if parts.size()>1:h.set_meta("craft_material_"+recipe,parts[1])
			_open(h,"wardrobe");Ink.inspect_craft(h,recipe)
		"quest":
			h.set_meta("ink_journal_tab","journal");h.set_meta("ink_journal_mode","quests")
			var quests:Array=h.state.quest_rows()
			for i in range(quests.size()):
				if str(quests[i].id)==target:h.set_meta("ink_journal_page",i/3);break
			_open(h,"practice")
		"ending":
			h.set_meta("ink_journal_tab","ending");_open(h,"practice")
		"gather", "meditate":
			# This named action starts only the chosen peaceful activity.
			h.state.set_activity(kind);h._save_loadout();h._build_nav()
			h.set_meta("ink_journal_tab","practice");_open(h,"practice")
		"longterm":
			h.set_meta("ink_journal_tab","collection");_open(h,"practice")
		_:
			h.set_meta("ink_journal_tab","practice");_open(h,"practice")

static func act_current(h):
	var current:Dictionary=status(h)
	navigate(h,str(current.get("kind","practice")),str(current.get("target","")))

static func _skip(h,id:String):
	var current:Dictionary=status(h)
	if str(current.get("id",""))!=id or not bool(current.get("skippable",false)):return
	if h.state.has_method("skip_player_journey_suggestion"):
		h.state.skip_player_journey_suggestion(id);h._save_loadout();recommend(h)

static func _reset(h):
	if h.state.has_method("reset_player_journey_suggestions"):
		h.state.reset_player_journey_suggestions();h._save_loadout()
	recommend(h)

static func _secondary(h,x:float,y:float,width:float,current:Dictionary,key:String):
	var skip:bool=bool(current.get("skippable",false))
	var alternative:String=str(current.get("alternative_kind",""))
	var part:float=(width-6.0)*.5 if skip and not alternative.is_empty() else width
	if skip:
		var id:String=str(current.get("id",""))
		var skip_button:Button=h._qbutton(h.drawer,key+"_skip","略过此建议",Rect2(x,y,part,22),func():_skip(h,id),"只收起这条建议，不赠送资源、不完成目标；可在入山页重新查看。")
		skip_button.add_theme_font_size_override("font_size",10);skip_button.size=Vector2(part,22)
	if not alternative.is_empty():
		var xx:float=x+part+6.0 if skip else x
		var alternative_button:Button=h._qbutton(h.drawer,key+"_alternative",str(current.get("alternative_action","另看山路"))+" ↗",Rect2(xx,y,part,22),func():
			var fresh:Dictionary=status(h)
			navigate(h,str(fresh.get("alternative_kind","practice")),str(fresh.get("alternative_target",""))),"只翻到对应书页；准备建议不是出发的硬性条件。")
		alternative_button.add_theme_font_size_override("font_size",10);alternative_button.size=Vector2(part,22)

static func build_practice(h,x:float,y:float):
	var current:Dictionary=status(h)
	h._qbutton(h.drawer,"practice_claim",str(current.get("action","看眼前一事"))+" ↗",Rect2(x+340,y+234,264,31),func():act_current(h),str(current.get("summary",""))+"\n"+str(current.get("detail","")),true)
	_secondary(h,x+340,y+208,264,current,"practice_journey")

static func draw_practice(h,x:float,y:float,a:float):
	var current:Dictionary=status(h)
	Ink._txt(h,"归 山 之 路" if bool(current.get("complete",false)) else "眼 前 一 事",Vector2(x+342,y+79),10,a,Ink.FADED)
	Ink._txt(h,Ink._ellipsis(str(current.get("title","山居从容")),259,18),Vector2(x+342,y+106),18,a,Ink.INK,true)
	Ink._wrap(h,str(current.get("summary","")),Vector2(x+342,y+132),259,11,a,Ink.FADED,4)
	Ink._txt(h,Ink._ellipsis(str(current.get("progress","")),259,10),Vector2(x+342,y+199),10,a,Ink.JADE)

static func build_guide(h,x:float,y:float):
	var roadmap:Array=rows(h)
	var step:int=selected(h)
	for i in range(roadmap.size()):
		var index:int=i
		var row:Dictionary=roadmap[i]
		var b:Button=h._qbutton(h.drawer,"guide_step_%d"%i,str(row.get("title","")),Rect2(x,y+90+i*18.0,270,17.5),func():
			h.set_meta("ink_guide_follow_current",false);h.set_meta("ink_guide_step",index);h._refresh_drawer(),str(row.get("summary","")),false,step==i)
		b.set_meta("ink_region",true);b.add_theme_font_size_override("font_size",11);b.size=Vector2(270,17.5)
	var reset:Button=h._qbutton(h.drawer,"guide_restart","重看引导",Rect2(x+189,y+61,81,23),func():_reset(h),"重新显示你略过的建议；真实进度、所有资源与已学功法不变。")
	reset.add_theme_font_size_override("font_size",10);reset.size=Vector2(81,23)
	h._qbutton(h.drawer,"guide_recommend","眼下该做什么？",Rect2(x+108,y+240,162,27),func():recommend(h),"只根据真实行装、功法、经脉与山路进度给出眼前一事。")
	h._qbutton(h.drawer,"guide_idle","安心挂机 ↗",Rect2(x,y+240,103,27),func():navigate(h,"practice"),"到修行页可选择随缘自动静坐、采药与突破；历练仍亲自出发。")
	var current:Dictionary=status(h)
	var live:bool=step==recommended(h)
	h._qbutton(h.drawer,"guide_action",(str(current.get("action","看眼前一事")) if live else "回到眼下建议")+" ↗",Rect2(x+300,y+240,304,28),func():
		if selected(h)==recommended(h):act_current(h)
		else:recommend(h),str(current.get("detail","")) if live else "查看眼下真正可做的一步；浏览路线不会替你完成目标。",true)
	if live:_secondary(h,x+300,y+211,304,current,"guide_journey")

static func draw_guide(h,x:float,y:float,a:float):
	var roadmap:Array=rows(h)
	if roadmap.is_empty():return
	var step:int=selected(h)
	var live_index:int=recommended(h)
	Ink._rule(h,Vector2(x+282,y+65),Vector2(x+282,y+268),a)
	Ink._txt(h,"归山一卷 · 八段路",Vector2(x+4,y+79),16,a,Ink.INK,true)
	for i in range(roadmap.size()):
		var row:Dictionary=roadmap[i]
		var yy:float=y+90+i*18.0
		if i==step:h.draw_line(Vector2(x-3,yy+2),Vector2(x-3,yy+15),Color(Ink.RED,a*.8),2,true)
		Ink._txt(h,str(i+1),Vector2(x+7,yy+13),10,a,Ink.RED if i==step else Ink.FADED)
		Ink._txt(h,str(row.get("title","")),Vector2(x+28,yy+13),12,a,Ink.INK,true)
		Ink._txt(h,"眼下" if i==live_index else ("已历" if bool(row.get("done",false)) else "待行"),Vector2(x+231,yy+13),9,a,Ink.JADE if i==live_index or bool(row.get("done",false)) else Ink.FADED)
	var current:Dictionary=status(h)
	if step!=live_index:
		var row:Dictionary=roadmap[step]
		Ink._txt(h,"这一段 · 可随时回望",Vector2(x+302,y+78),10,a,Ink.FADED)
		Ink._txt(h,str(row.get("title","")),Vector2(x+302,y+105),19,a,Ink.INK,true)
		Ink._wrap(h,str(row.get("summary","")),Vector2(x+302,y+133),298,11,a,Ink.FADED,4)
		Ink._wrap(h,"随缘静修可独自走到归真；六章历练始终亲自启程。",Vector2(x+302,y+207),298,10,a,Ink.JADE,2)
		return
	Ink._txt(h,"眼下建议 · "+str(roadmap[live_index].get("title","")),Vector2(x+302,y+78),10,a,Ink.JADE)
	Ink._txt(h,Ink._ellipsis(str(current.get("title","")),298,17),Vector2(x+302,y+104),17,a,Ink.INK,true)
	Ink._wrap(h,str(current.get("summary","")),Vector2(x+302,y+126),298,11,a,Ink.INK,2)
	Ink._wrap(h,str(current.get("detail","")),Vector2(x+302,y+162),298,10,a,Ink.FADED,3)
	Ink._txt(h,Ink._ellipsis(str(current.get("progress","")),298,10),Vector2(x+302,y+205),10,a,Ink.JADE)
