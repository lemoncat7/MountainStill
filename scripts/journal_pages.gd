extends RefCounted
## A field journal, opened from the meditation stone. All entries come from
## the saved campaign, and the paper remains navigable after the final realm.
const Ink = preload("res://scripts/ink_pages.gd")
const Journey = preload("res://scripts/player_journey_pages.gd")
const TABS = ["practice","guide","journal","collection"]
const TAB_NAMES = ["修行","入山","山居志","物华录"]
const CATEGORIES = ["realms","items","discoveries","techniques","recipes"]
const CATEGORY_NAMES = ["境界","衣冠","见闻","功法","丹方"]

static func build_practice(h,x:float,y:float,_r:Rect2):
	var tab:String=str(h.get_meta("ink_journal_tab","practice"))
	for i in range(TABS.size()):
		var id:String=TABS[i]
		h._qbutton(h.drawer,"journal_"+id,TAB_NAMES[i],Rect2(x+279+i*82,y+13,77,29),func():
			h.set_meta("ink_journal_tab",id);h._refresh_drawer(),"翻阅"+TAB_NAMES[i],false,tab==id)
	match tab:
		"guide": _build_guide(h,x,y)
		"ending": _build_ending(h,x,y)
		"journal": _build_journal(h,x,y)
		"collection": _build_collection(h,x,y)
		_: _build_cultivation(h,x,y)

static func draw_practice(h,x:float,y:float,a:float):
	Ink._book_header(h,"山 居 札","一山一生  ·  心有所归",x,y,605,a)
	match str(h.get_meta("ink_journal_tab","practice")):
		"guide": _draw_guide(h,x,y,a)
		"ending": _draw_ending(h,x,y,a)
		"journal": _draw_journal(h,x,y,a)
		"collection": _draw_collection(h,x,y,a)
		_: _draw_cultivation(h,x,y,a)

static func _next_quest(h) -> Dictionary:
	for row in h.state.quest_rows():
		if bool(row.get("unlocked",false)) and not bool(row.get("claimed",false)): return row
	return {}

static func _build_cultivation(h,x:float,y:float):
	for i in range(3):
		var id:String=["meditate","gather","brew"][i]
		var label:String=["静坐","采药","炼丹"][i]
		h._qbutton(h.drawer,"activity_"+id,label,Rect2(x+i*103,y+151,96,30),func():
			h.state.set_activity(id);h._notice({"meditate":"一呼一吸，灵气归心。","gather":"循着药香，去山间走走。","brew":"温火慢煨，不急于成。"}[id]);h._save_loadout();h._build_nav();h._refresh_drawer(),["灵气缓慢增长","灵草与灵露按时收入行囊","使用丹房中所选的丹方"][i],false,h.state.activity==id)
	var stats:Dictionary=h.state.stats()
	var complete:bool=bool(stats.get("max_realm",false))
	var ready:bool=not complete and h.state.qi>=float(stats.need_qi) and h.state.herbs>=int(stats.need_herbs)
	var preview:Dictionary=h.state.breakthrough_preview() if h.state.has_method("breakthrough_preview") else {}
	var unlocks:String=str(preview.get("unlocks",""))
	var requirement:String=str(preview.get("cost","修为和灵草齐备，即可突破"))+(("\n突破后 · "+unlocks) if not unlocks.is_empty() else "")
	var button:Button=h._qbutton(h.drawer,"breakthrough","此心归真" if complete else ("突破至 "+h.state.next_realm_name()),Rect2(x,y+234,194,31),func():
		if h.state.breakthrough():h._on_breakthrough();h._save_loadout();h._refresh_drawer(),requirement,true)
	button.disabled=not ready
	h._qbutton(h.drawer,"practice_auto","随缘 · "+("开" if h.state.auto_advance else "关"),Rect2(x+207,y+234,95,31),func():
		h.state.auto_advance=not h.state.auto_advance;h._save_loadout();h._refresh_drawer(),"自动静坐、采药并突破；不启动切磋或灵狐远游",false,h.state.auto_advance)
	Journey.build_practice(h,x,y)

static func _draw_cultivation(h,x:float,y:float,a:float):
	var stats:Dictionary=h.state.stats()
	var complete:bool=bool(stats.get("max_realm",false))
	Ink._rule(h,Vector2(x+321,y+66),Vector2(x+321,y+265),a)
	Ink._txt(h,h.state.realm_name(),Vector2(x+1,y+88),24,a,Ink.INK,true)
	Ink._txt(h,"静修圆满 · 山居长在" if complete else "下一境 · "+h.state.next_realm_name(),Vector2(x+1,y+111),11,a,Ink.FADED)
	var energy:String="功德" if complete else "灵气"
	var activity_text:String=energy+" +%.1f / 秒 · 正在静坐"%float(stats.qi_rate) if h.state.activity=="meditate" else "正在%s · 静坐 +%.1f%s / 秒"%[h.state.activity_name(),float(stats.qi_rate),energy]
	if h.paused:activity_text="暂歇中 · 修行、研习与离线收益均暂停"
	Ink._txt(h,activity_text,Vector2(x+1,y+136),11,a,Ink.FADED)
	Ink._txt(h,"气血 %d · 总攻 %d（境 +%d） · 总御 %d（境 +%d）"%[int(stats.get("max_hp",100)),int(stats.attack),int(stats.get("realm_attack",0)),int(stats.defense),int(stats.get("realm_defense",0))],Vector2(x+1,y+194),9,a,Ink.FADED)
	Ink._txt(h,"修为已圆满 · 功德 %d"%int(h.state.merit) if complete else "修为 %d / %d · 灵草 %d / %d"%[int(h.state.qi),int(stats.need_qi),h.state.herbs,int(stats.need_herbs)],Vector2(x+1,y+213),11,a,Ink.INK)
	Ink._meter(h,Rect2(x+1,y+225,300,0),float(stats.progress),a)
	Journey.draw_practice(h,x,y,a)

static func _guide_rows(h) -> Array:
	# Compatibility entry point for the existing paper tests and captures.
	var result:Array=[]
	for row in Journey.rows(h):
		var entry:Dictionary=row.duplicate(true)
		entry["text"]=str(row.get("summary",""));result.append(entry)
	return result

static func _recommended_guide_step(h) -> int:
	return Journey.recommended(h)

static func _guide_action(h,kind:String):
	Journey.navigate(h,kind)

static func _build_guide(h,x:float,y:float):
	Journey.build_guide(h,x,y)

static func _draw_guide(h,x:float,y:float,a:float):
	Journey.draw_guide(h,x,y,a)

static func _build_ending(h,x:float,y:float):
	var chapters:Dictionary=Ink.Adventure.chapter_status(h)
	var complete:bool=bool(chapters.get("ending_complete",false))
	var ready:bool=bool(chapters.get("epilogue_ready",false)) and not complete
	var home:bool=not h.encounter_active and str(h.world_route).is_empty()
	var label:String="回到山居" if complete else ("落笔 · 此心归处" if ready else ("继续静修" if bool(chapters.get("story_resolved",false)) else "循着山路再出发"))
	var action:Button=h._qbutton(h.drawer,"ending_action",label,Rect2(x+319,y+234,285,31),func():
		var current:Dictionary=Ink.Adventure.chapter_status(h)
		if bool(current.get("ending_complete",false)) or (bool(current.get("story_resolved",false)) and not bool(current.get("epilogue_ready",false))):
			h.set_meta("ink_journal_tab","practice");h._refresh_drawer()
		elif bool(current.get("epilogue_ready",false)):
			if h.encounter_active or not str(h.world_route).is_empty():h._notice("先收步归山，再把这一程落在纸上。");return
			var result:Dictionary=h.state.complete_home_epilogue()
			if bool(result.get("ok",false)):h._save_loadout();h._notice(str(result.get("text","此心归处，青山长在。")),"level");h._refresh_drawer()
		else:
			h.wardrobe_tab="expedition";h.set_meta("expedition_view","route");h._toggle_drawer("wardrobe"),"六章与归真皆完成后，在家中亲手落笔。完成后仍可自由山居。",true)
	if ready and not home:action.disabled=true;action.text="先归山，再落笔";action.tooltip_text="请先结束当前行程、回到山居，再写下结语。"
	h._qbutton(h.drawer,"ending_journal","翻阅往日手记 ↗",Rect2(x,y+234,279,31),func():h.set_meta("ink_journal_tab","journal");h.set_meta("ink_journal_mode","events");h.set_meta("ink_journal_page",0);h._refresh_drawer(),"回看这一路真实留下的记事")

static func _draw_ending(h,x:float,y:float,a:float):
	var peaceful:Dictionary=h.state.completion_status()
	var chapters:Dictionary=Ink.Adventure.chapter_status(h)
	var complete:bool=bool(chapters.get("ending_complete",false))
	Ink._rule(h,Vector2(x+296,y+65),Vector2(x+296,y+265),a)
	Ink._txt(h,"归 山 终 章",Vector2(x+3,y+80),10,a,Ink.FADED)
	Ink._txt(h,str(chapters.get("ending_title","此心归处")) if complete else "山路尽处，是归途",Vector2(x+3,y+109),22,a,Ink.INK,true)
	var summary:String=str(chapters.get("summary","六段山路留下各自的回声。静修与行路，最后都归入这一方山居。"))
	Ink._wrap(h,summary,Vector2(x+4,y+131),273,12,a,Ink.FADED,5)
	Ink._txt(h,"一卷已毕 · 生活仍可继续" if complete else "终章不会自动落笔，等你亲手写完。",Vector2(x+4,y+219),10,a,Ink.JADE if complete else Ink.FADED)
	Ink._txt(h,"静修之路 · %d / %d 阶"%[h.state.realm+1,h.state.MAX_REALM+1],Vector2(x+320,y+83),14,a,Ink.INK,true)
	Ink._meter(h,Rect2(x+321,y+97,281,0),float(peaceful.get("progress",0)),a)
	Ink._txt(h,"已归真 · 静修圆满" if bool(peaceful.get("complete",false)) else "每次突破都必定成功，可独自走至归真。",Vector2(x+320,y+118),10,a,Ink.FADED)
	Ink._txt(h,"山路之卷 · %d / %d 章"%[int(chapters.get("completed",0)),int(chapters.get("total",6))],Vector2(x+320,y+150),14,a,Ink.INK,true)
	var rows:Array=h.state.stage_rows()
	for i in range(rows.size()):
		var p:Vector2=Vector2(x+322+i*47,y+162)
		if int(rows[i].get("clears",0))>0:Ink._seal(h,str(i+1),p,a,22)
		else:
			h.draw_rect(Rect2(p,Vector2(22,22)),Color(Ink.FADED,a*.3),false,1.0)
			Ink._txt(h,str(i+1),p+Vector2(7,16),11,a,Ink.FADED)
	var next:String="可回山静坐，也可重游旧路。" if complete else str(chapters.get("next_objective","循着山路前行，慢慢温养修为。"))
	Ink._wrap(h,next,Vector2(x+320,y+209),282,10,a,Ink.JADE,1)
	if complete:Ink._seal(h,"归",Vector2(x+246,y+72),a,29)

static func _journal_entries(h) -> Array:
	if h.state.has_method("journal_rows"):return h.state.journal_rows()
	var rows:Array=[]
	for entry in h.journal:rows.append({"text":str(entry),"time":0})
	return rows

static func _build_journal(h,x:float,y:float):
	var mode:String=str(h.get_meta("ink_journal_mode","quests"))
	h._qbutton(h.drawer,"journal_quests","山中小事",Rect2(x,y+61,100,25),func():h.set_meta("ink_journal_mode","quests");h.set_meta("ink_journal_page",0);h._refresh_drawer(),"入山指引与长期目标",false,mode=="quests")
	h._qbutton(h.drawer,"journal_events","往日手记",Rect2(x+111,y+61,100,25),func():h.set_meta("ink_journal_mode","events");h.set_meta("ink_journal_page",0);h._refresh_drawer(),"保留最近六十条重要山居记事",false,mode=="events")
	var rows:Array=h.state.quest_rows() if mode=="quests" else _journal_entries(h)
	var per_page:int=3
	var pages:int=maxi(1,ceili(rows.size()/float(per_page)))
	var page:int=clampi(int(h.get_meta("ink_journal_page",0)),0,pages-1)
	h.set_meta("ink_journal_page",page)
	if mode=="quests":
		for i in range(per_page):
			var index:int=page*per_page+i
			if index>=rows.size():break
			var row:Dictionary=rows[index]
			var id:String=str(row.id)
			var claim:Button=h._qbutton(h.drawer,"quest_claim_"+id,"已记" if bool(row.claimed) else ("收下" if bool(row.ready) else "未成"),Rect2(x+325,y+91+i*46,63,30),func():
				var result:Dictionary=h.state.claim_quest(id)
				if bool(result.get("ok",false)):h._save_loadout();h._notice("已完成 · "+str(row.name),"loot");h._refresh_drawer()
				else:h.CapacityPages.open(h,"quest",{"id":id},str(result.get("reason",""))),str(row.description)+" · "+Ink._reward_text(row.get("rewards",{})),bool(row.ready))
			claim.disabled=not bool(row.ready) or bool(row.claimed)
	h._qbutton(h.drawer,"journal_ending","归山终章 ↗",Rect2(x+425,y+238,179,28),func():h.set_meta("ink_journal_tab","ending");h._refresh_drawer(),"查看静修与六章山路的进度；完成后亲手写下结语")
	h._qbutton(h.drawer,"journal_prev","‹",Rect2(x,y+240,32,26),func():h.set_meta("ink_journal_page",maxi(0,page-1));h._refresh_drawer(),"前一页").disabled=page<=0
	h._qbutton(h.drawer,"journal_next","›",Rect2(x+355,y+240,32,26),func():h.set_meta("ink_journal_page",page+1);h._refresh_drawer(),"后一页").disabled=page>=pages-1

static func _draw_journal(h,x:float,y:float,a:float):
	Ink._rule(h,Vector2(x+407,y+65),Vector2(x+407,y+265),a)
	var mode:String=str(h.get_meta("ink_journal_mode","quests"))
	var rows:Array=h.state.quest_rows() if mode=="quests" else _journal_entries(h)
	var per_page:int=3
	var page:int=int(h.get_meta("ink_journal_page",0))
	for i in range(per_page):
		var index:int=page*per_page+i
		if index>=rows.size():break
		var row:Dictionary=rows[index]
		if mode=="quests":
			var yy:float=y+94+i*46
			var unlocked:bool=bool(row.get("unlocked",false))
			Ink._txt(h,str(row.name),Vector2(x+7,yy+12),14,a,Ink.INK if unlocked else Ink.FADED,true)
			Ink._txt(h,"%d / %d"%[int(row.get("progress",0)),int(row.get("target",1))],Vector2(x+252,yy+12),10,a,Ink.FADED)
			Ink._wrap(h,str(row.description),Vector2(x+7,yy+31),310,10,a,Ink.FADED,1)
			Ink._rule(h,Vector2(x+7,yy+42),Vector2(x+388,yy+42),a*.65)
		else:
			var yy:float=y+105+i*46
			Ink._wrap(h,str(row.get("text","")),Vector2(x+7,yy),380,10,a,Ink.INK,2)
			Ink._rule(h,Vector2(x+7,yy+29),Vector2(x+388,yy+29),a*.45)
	if rows.is_empty():Ink._txt(h,"一纸初开，山居尚长。",Vector2(x+18,y+151),15,a,Ink.FADED,true)
	Ink._center(h,"第 %d / %d 页"%[page+1,maxi(1,ceili(rows.size()/float(per_page)))],Rect2(x+40,y+244,307,16),10,a,Ink.FADED)
	var ending:Dictionary=h.state.completion_status()
	Ink._txt(h,"归 途",Vector2(x+426,y+80),10,a,Ink.FADED)
	Ink._txt(h,str(ending.get("title","一山一生")),Vector2(x+426,y+108),20,a,Ink.INK,true)
	Ink._wrap(h,str(ending.get("description","")),Vector2(x+426,y+135),175,10,a,Ink.FADED,4)
	Ink._meter(h,Rect2(x+427,y+204,173,0),float(ending.get("progress",0)),a)
	Ink._txt(h,"山中小事 %d / %d"%[int(ending.get("quest_claimed",0)),int(ending.get("quest_total",0))],Vector2(x+426,y+226),10,a,Ink.FADED)
	

static func _build_collection(h,x:float,y:float):
	var selected:String=str(h.get_meta("ink_collection_category","realms"))
	for i in range(CATEGORIES.size()):
		var id:String=CATEGORIES[i]
		h._qbutton(h.drawer,"collection_"+id,CATEGORY_NAMES[i],Rect2(x,y+68+i*34,103,31),func():
			h.set_meta("ink_collection_category",id);h.set_meta("ink_collection_page",0);h._refresh_drawer(),"翻阅"+CATEGORY_NAMES[i],false,selected==id)
	var collection:Dictionary=h.state.collection_status()
	var rows:Array=collection.get(selected,[])
	var pages:int=maxi(1,ceili(rows.size()/6.0))
	var page:int=clampi(int(h.get_meta("ink_collection_page",0)),0,pages-1)
	h.set_meta("ink_collection_page",page)
	h._qbutton(h.drawer,"collection_prev","‹",Rect2(x+133,y+240,30,26),func():h.set_meta("ink_collection_page",maxi(0,page-1));h._refresh_drawer(),"前一页").disabled=page<=0
	h._qbutton(h.drawer,"collection_next","›",Rect2(x+574,y+240,30,26),func():h.set_meta("ink_collection_page",page+1);h._refresh_drawer(),"后一页").disabled=page>=pages-1

static func _draw_collection(h,x:float,y:float,a:float):
	var selected:String=str(h.get_meta("ink_collection_category","realms"))
	var collection:Dictionary=h.state.collection_status()
	var rows:Array=collection.get(selected,[])
	var page:int=int(h.get_meta("ink_collection_page",0))
	Ink._rule(h,Vector2(x+117,y+66),Vector2(x+117,y+265),a)
	var category_index:int=CATEGORIES.find(selected)
	var found:int=0
	for row in rows:
		if bool(row.get("unlocked",false)):found+=1
	Ink._txt(h,CATEGORY_NAMES[maxi(0,category_index)]+" · 已识 %d / %d"%[found,rows.size()],Vector2(x+137,y+81),13,a,Ink.INK,true)
	for i in range(6):
		var index:int=page*6+i
		if index>=rows.size():break
		var row:Dictionary=rows[index]
		var xx:float=x+139+(i%2)*235
		var yy:float=y+113+(i/2)*42
		var unlocked:bool=bool(row.get("unlocked",false))
		Ink._txt(h,str(row.get("name","未知")),Vector2(xx,yy),15,a,Ink.INK if unlocked else Ink.FADED,true)
		Ink._txt(h,"已入山居谱" if unlocked else "尚待机缘",Vector2(xx,yy+17),9,a,Ink.JADE if unlocked else Ink.FADED)
		if unlocked:Ink._seal(h,"录",Vector2(xx+187,yy-11),a*.8,18)
		Ink._rule(h,Vector2(xx,yy+24),Vector2(xx+210,yy+24),a*.6)
	Ink._txt(h,"总录 %d / %d"%[int(collection.get("progress",0)),int(collection.get("total",0))],Vector2(x+8,y+255),10,a,Ink.FADED)
	Ink._center(h,"第 %d / %d 页  ·  所得皆留痕"%[page+1,maxi(1,ceili(rows.size()/6.0))],Rect2(x+172,y+244,394,16),10,a,Ink.FADED)
