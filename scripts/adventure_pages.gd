extends RefCounted
## Finite, player-started expeditions and branched meridians, on ink paper.
const SERIF=preload("res://assets/fonts/NotoSerifCJK-Regular.ttc")
const INK=Color("343b32")
const FADED=Color("707365")
const RED=Color("a44434")
const JADE=Color("6e876b")

static func txt(h,t:String,p:Vector2,s:int,a:float,c:Color=INK):
	h._text(t,p,s,Color(c,a),SERIF)
static func rule(h,p:Vector2,q:Vector2,a:float):h.draw_line(p,q,Color(FADED,a*.28),1.0,true)
static func wrapped(h,t:String,p:Vector2,w:float,s:int,a:float,c:Color=FADED,n:int=3):h.InkPages._wrap(h,t,p,w,s,a,c,n)
static func button(h,key:String,label:String,r:Rect2,fn:Callable,hint:String="",accent=false,selected=false)->Button:
	return h._qbutton(h.drawer,key,label,r,fn,hint,accent,selected)

const CHAPTERS_PER_PAGE := 3

static func chapter_status(h) -> Dictionary:
	if h.state.has_method("chapter_status"):return h.state.chapter_status()
	var rows:Array=h.state.stage_rows()
	var done:int=0
	for row in rows:
		if int(row.get("clears",0))>0:done+=1
	return {"completed":done,"total":rows.size(),"story_resolved":done==rows.size(),"epilogue_ready":false,"ending_complete":false}

static func selected_chapter(h) -> Dictionary:
	var rows:Array=h.state.stage_rows()
	var selected:String=str(h.get_meta("ink_stage_id",h.state.selected_stage))
	for row in rows:
		if str(row.id)==selected:return row
	for row in rows:
		if bool(row.get("selected",false)):return row
	return rows[0] if not rows.is_empty() else {}

static func _chapter_page(h,rows:Array) -> int:
	var pages:int=maxi(1,ceili(rows.size()/float(CHAPTERS_PER_PAGE)))
	var page:int=clampi(int(h.get_meta("ink_stage_page",0)),0,pages-1)
	h.set_meta("ink_stage_page",page)
	return page

static func _inspect_chapter(h,id:String,rows:Array):
	h.set_meta("ink_stage_id",id);h.set_meta("expedition_view","guide" if str(h.get_meta("expedition_view","route"))=="guide" else "route");h.set_meta("ink_abandon_confirm","")
	for i in range(rows.size()):
		if str(rows[i].id)==id:h.set_meta("ink_stage_page",i/CHAPTERS_PER_PAGE);break
	var status:Dictionary=h.state.stage_status()
	# Browsing must never discard a saved checkpoint or change a live route.
	if not bool(status.get("active",false)) and not bool(status.get("paused",false)):
		if h.state.select_stage(id):h._save_loadout()
	h._refresh_drawer()

static func _chapter_gate(h,row:Dictionary) -> String:
	if not bool(row.get("unlocked",false)):
		var requirements:Array[String]=[]
		var level:int=clampi(int(row.get("unlock_realm",0)),0,h.state.REALM_NAMES.size()-1)
		if h.state.realm<level:requirements.append("需达 "+str(h.state.REALM_NAMES[level]))
		var prerequisite:String=str(row.get("prerequisite",""))
		if not prerequisite.is_empty() and int(h.state.stage_clears.get(prerequisite,0))<=0:
			for previous in h.state.stage_rows():
				if str(previous.id)==prerequisite:requirements.append("先通 "+str(previous.name));break
		if not requirements.is_empty():return " · ".join(requirements)
		return str(row.get("locked_reason","山路尚未开启"))
	return "已通关 · 可重游，首通心意只领一次" if int(row.get("clears",0))>0 else "已可出发 · 亲点后才进入这一章"

static func _depart(h):
	# Read fresh state at click time: stale controls never overwrite a checkpoint.
	if h.encounter_active:
		h._retreat_encounter();h._refresh_drawer();return
	if h.paused:return
	var chosen:Dictionary=selected_chapter(h)
	var status:Dictionary=h.state.stage_status()
	if bool(status.get("paused",false)) and str(chosen.get("id",""))!=str(status.get("id","")):
		_inspect_chapter(h,str(status.id),h.state.stage_rows());return
	if not bool(chosen.get("unlocked",false)):
		h._notice(_chapter_gate(h,chosen));return
	if not bool(status.get("paused",false)) and not h.state.select_stage(str(chosen.id)):return
	h._start_encounter()
	if not h.drawer_name.is_empty():h._refresh_drawer()

static func _can_abandon_for_chapter(h,chosen:Dictionary,status:Dictionary) -> bool:
	return not h.encounter_active and bool(status.get("paused",false)) and str(chosen.get("id",""))!=str(status.get("id",""))

static func _abandon_key(h,chosen:Dictionary,status:Dictionary) -> String:
	# Closing the book, changing chapter, or a new run invalidates confirmation.
	return "%d:%s:%d"%[int(status.get("run_id",0)),str(chosen.get("id","")),int(h.drawer_generation)]

static func _abandon_for_chapter(h):
	var status:Dictionary=h.state.stage_status()
	var chosen:Dictionary=selected_chapter(h)
	if not _can_abandon_for_chapter(h,chosen,status):return
	# Earned, unsearched loot has a durable owner. Browsing another chapter
	# offers a return to that body, never a misleading abandonment promise.
	if bool(status.get("corpse_pending",false)):
		_return_to_unsearched_corpse(h,status);return
	var key:String=_abandon_key(h,chosen,status)
	if str(h.get_meta("ink_abandon_confirm",""))!=key:
		h.set_meta("ink_abandon_confirm",key);h._refresh_drawer();return
	var result:Dictionary=h.state.cancel_stage()
	h.set_meta("ink_abandon_confirm","")
	if bool(result.get("ok",false)):
		if str(result.get("reason",""))=="corpse_preserved":
			_return_to_unsearched_corpse(h,status);return
		if bool(chosen.get("unlocked",false)):h.state.select_stage(str(chosen.id))
		h._save_loadout();h._notice("已放下「%s」 · 已得收获保留，未完路段重来。"%str(status.get("name","旧程")))
	h._refresh_drawer()

static func _return_to_unsearched_corpse(h,status:Dictionary):
	_inspect_chapter(h,str(status.get("id",h.state.selected_stage)),h.state.stage_rows())
	h._save_loadout()
	h._notice("遗物尚未搜取 · 回到「%s」继续此程，原有搜寻进度已保留。"%str(status.get("name","旧程")))

static func _chapter_guide(h,chapter:Dictionary)->Dictionary:
	if not h.state.has_method("chapter_field_guide"):return {}
	return h.state.chapter_field_guide(str(chapter.get("id","")))

static func _guide_hint(guide:Dictionary)->String:
	return "守灵 · "+str(guide.get("monster_name",""))+"\n"+str(guide.get("identity",""))+"\n备行 · "+str(guide.get("preparation",""))+"\n山材 · "+str(guide.get("material_name",""))+"\n百工 · "+str(guide.get("crafting_goal",""))

static func _guide_recipe(h):
	var guide:Dictionary=_chapter_guide(h,selected_chapter(h))
	var id:String=str(guide.get("recipe_id",""))
	if id.is_empty():return
	# Navigation only: inspect a recipe without selecting, starting, cancelling
	# or otherwise changing the current expedition/checkpoint.
	var material:String=str(guide.get("material_id",""))
	var quote:Dictionary=h.state.crafting_quote(id)
	if material!="spirit_jade" and material in quote.get("alternatives",[]):
		h.set_meta("craft_material_"+id,material)
	h.wardrobe_tab="bag";h.set_meta("bag_view","craft")
	h.InkPages.inspect_craft(h,id)

static func build_expedition(h,x:float,y:float):
	var status:Dictionary=h.state.stage_status()
	var rows:Array=h.state.stage_rows()
	var chosen:Dictionary=selected_chapter(h)
	var page:int=_chapter_page(h,rows)
	var pages:int=maxi(1,ceili(rows.size()/float(CHAPTERS_PER_PAGE)))
	for i in range(CHAPTERS_PER_PAGE):
		var index:int=page*CHAPTERS_PER_PAGE+i
		if index>=rows.size():break
		var row:Dictionary=rows[index]
		var id:String=str(row.id)
		var hint:String=str(row.get("summary",row.get("description","")))+"\n"+_chapter_gate(h,row)+"\n首通："+str(row.get("first_clear_reward_text","关底收获")).replace("灵气","功德" if h.state.realm==h.state.MAX_REALM else "灵气")+"\n"+str(row.get("next_objective",""))+"\n"+str(row.get("rewards",""))
		var b:Button=button(h,"stage_"+id,str(row.name),Rect2(x,y+68+i*43,202,41),func():_inspect_chapter(h,id,h.state.stage_rows()),hint,false,str(chosen.get("id",""))==id)
		b.set_meta("ink_region",true)
	button(h,"stage_prev","‹",Rect2(x,y+203,31,25),func():
		h.set_meta("ink_stage_page",maxi(0,int(h.get_meta("ink_stage_page",0))-1));h.set_meta("ink_abandon_confirm","");h._refresh_drawer(),"前三章").disabled=page<=0
	button(h,"stage_next","›",Rect2(x+171,y+203,31,25),func():
		h.set_meta("ink_stage_page",mini(pages-1,int(h.get_meta("ink_stage_page",0))+1));h.set_meta("ink_abandon_confirm","");h._refresh_drawer(),"后三章").disabled=page>=pages-1
	var label:String="整装出发"
	var hint:String="只出发这一章；两场交锋与守关者，途中机缘不限时。通关后回山，不自动连关。"
	if h.encounter_active:
		label="归山暂歇";hint="归山调息，已过路段与收获都保留。下一次亲点继续，从尚未击退的敌人开始，恢复气血。"
	elif bool(status.get("paused",false)):
		label="继续此程" if str(chosen.get("id",""))==str(status.get("id","")) else "回到未完之程"
		hint="已通过 %d / %d 敌，回到「%s」继续；已获奖励不会重复发放。"%[int(status.get("kills",0)),int(status.get("total",3)),str(status.get("name","山路"))]
	elif not bool(chosen.get("unlocked",false)):
		label="尚待机缘";hint=_chapter_gate(h,chosen)
	var depart:Button=button(h,"depart_stage",label,Rect2(x,y+237,202,30),func():_depart(h),hint,true)
	depart.disabled=h.paused or (not h.encounter_active and not bool(status.get("paused",false)) and not bool(chosen.get("unlocked",false)))
	button(h,"expedition_gear","整理衣冠 ↗",Rect2(x+225,y+240,119,27),func():h.wardrobe_tab="equipment";h._refresh_drawer(),"穿上已拥有的装备，或用草露淬炼旧物")
	button(h,"expedition_meridian","疏通经脉 ↗",Rect2(x+354,y+240,119,27),func():h.wardrobe_tab="meridian";h._refresh_drawer(),"有限的永久成长；经脉不阻挡境界突破")
	button(h,"expedition_chest","木箱 · %d"%h.state.chest_count,Rect2(x+483,y+240,121,27),h._open_treasure,"启封现有木箱；不会自动穿戴",true).disabled=h.state.chest_count<=0
	var opportunity:Dictionary=h.state.opportunity_status()
	var guide:Dictionary=_chapter_guide(h,chosen)
	var guide_open:bool=str(h.get_meta("expedition_view","route"))=="guide"
	if not guide.is_empty() and (str(h.get_meta("expedition_view","route"))!="opportunity" or opportunity.is_empty()):
		button(h,"chapter_guide","山路" if guide_open else "备行",Rect2(x+534,y+67,70,26),func():
			h.set_meta("expedition_view","route" if str(h.get_meta("expedition_view","route"))=="guide" else "guide");h._refresh_drawer(),_guide_hint(guide),false,guide_open)
		if guide_open and not str(guide.get("recipe_id","")).is_empty():
			button(h,"chapter_recipe","查看配方 ↗",Rect2(x+403,y+67,123,26),func():_guide_recipe(h),"百工 · "+str(guide.get("crafting_goal",""))+"\n只翻阅配方；不出发、不换路线、不自动制作。")
	if _can_abandon_for_chapter(h,chosen,status):
		if bool(status.get("corpse_pending",false)):
			button(h,"abandon_stage","遗物尚未搜取 · 回到「%s」"%str(status.get("name","未完之程")),Rect2(x+225,y+207,379,26),func():_abandon_for_chapter(h),"倒地守灵与搜寻进度保留。先返回原章、亲点继续搜取遗物，再选择另一章；不会重打已击退守灵。",true)
		else:
			var confirming:bool=str(h.get_meta("ink_abandon_confirm",""))==_abandon_key(h,chosen,status)
			button(h,"abandon_stage","确认放下 · 收获保留，未完路段重来" if confirming else "放下「%s」…"%str(status.get("name","未完之程")),Rect2(x+225,y+207,379,26),func():_abandon_for_chapter(h),"放下「%s」的未完路段。已得收获保留，再走此路需从头开始。第一次点击只预览，再确认才放下。"%str(status.get("name","旧程")),confirming)
	elif not opportunity.is_empty():
		button(h,"expedition_opportunity",str(opportunity.get("name","山间机缘"))+" · 回应机缘 ↗",Rect2(x+225,y+207,379,26),func():h.set_meta("expedition_view","opportunity");h._refresh_drawer(),str(opportunity.get("description",""))+"\n这份机缘会一直等待；合书或退出后仍然保留",true)
	elif bool(chosen.get("reward_pending",false)) and h.state.has_method("claim_chapter_reward"):
		button(h,"chapter_reward","收下本章首通心意",Rect2(x+225,y+207,379,26),func():
			var result:Dictionary=h.state.claim_chapter_reward(str(selected_chapter(h).get("id","")))
			if bool(result.get("ok",false)):h._save_loadout();h._notice("首通心意已收入行囊。","loot");h._refresh_drawer()
			else:h.CapacityPages.open(h,"chapter",{"id":str(selected_chapter(h).get("id",""))},str(result.get("reason",""))),"背包满时保留首通奖励；可以稍后领取",true)
	elif bool(chapter_status(h).get("story_resolved",false)):
		button(h,"chapter_ending","翻阅归山终章 ↗",Rect2(x+225,y+207,379,26),func():h.set_meta("ink_journal_tab","ending");h._toggle_drawer("practice"),"六章之后，回望这一路；归真后可亲手写下结语",true)
	if str(h.get_meta("expedition_view","route"))=="opportunity" and not opportunity.is_empty():
		button(h,"opportunity_back","看山路",Rect2(x+534,y+67,70,26),func():h.set_meta("expedition_view","route");h._refresh_drawer(),"机缘继续保留\n"+str(opportunity.get("description","")))
		for i in range(opportunity.get("choices",[]).size()):
			var choice:Dictionary=opportunity.choices[i]
			var id:String=str(choice.id)
			button(h,"opportunity_"+id,str(choice.get("label",choice.get("name",id)))+" · "+h.InkPages._reward_text(choice.get("rewards",{})).replace("灵气",str(opportunity.get("energy_name","灵气"))),Rect2(x+225,y+153+i*39,379,32),func():
				var result:Dictionary=h.state.choose_opportunity(id)
				if bool(result.get("ok",false)):
					h._save_loadout();h._notice(str(result.get("name","这一段山缘"))+" · "+h.InkPages._reward_text(result.get("rewards",{})).replace("灵气",str(opportunity.get("energy_name","灵气"))),"loot");h.set_meta("expedition_view","route");h._refresh_drawer()
					if h.encounter_phase=="opportunity":h._close_drawer()
				elif str(result.get("reason",""))=="resource_full":h.CapacityPages.open(h,"opportunity",{"id":id,"run_id":int(opportunity.get("run_id",-1)),"stage_id":str(opportunity.get("stage_id",""))},"resource_full"),str(choice.get("description",""))+" · "+h.InkPages._reward_text(choice.get("rewards",{})).replace("灵气",str(opportunity.get("energy_name","灵气"))),true)
		if is_instance_valid(h.buttons.get("expedition_opportunity")):h.buttons.expedition_opportunity.visible=false

static func draw_expedition(h,x:float,y:float,a:float):
	var rows:Array=h.state.stage_rows()
	var chosen:Dictionary=selected_chapter(h)
	var page:int=_chapter_page(h,rows)
	var campaign:Dictionary=chapter_status(h)
	rule(h,Vector2(x+210,y+65),Vector2(x+210,y+267),a)
	for i in range(CHAPTERS_PER_PAGE):
		var index:int=page*CHAPTERS_PER_PAGE+i
		if index>=rows.size():break
		var row:Dictionary=rows[index]
		var yy:float=y+68+i*43
		var unlocked:bool=bool(row.get("unlocked",false))
		if str(row.id)==str(chosen.get("id","")):h.draw_line(Vector2(x-4,yy+6),Vector2(x-4,yy+34),Color(RED,a*.8),2,true)
		txt(h,"%02d"%int(row.get("chapter",index+1)),Vector2(x+7,yy+18),11,a,RED if unlocked else FADED)
		txt(h,str(row.name),Vector2(x+33,yy+18),16,a,INK if unlocked else FADED)
		var sub:String="已通 · 首通心意已收" if bool(row.get("first_clear_claimed",false)) else ("已通 · 心意待领" if bool(row.get("reward_pending",false)) else ("可出发 · 两敌一守关" if unlocked else "待启 · 点选查看条件"))
		txt(h,sub,Vector2(x+33,yy+35),10,a,JADE if int(row.get("clears",0))>0 else FADED)
		rule(h,Vector2(x+8,yy+42),Vector2(x+198,yy+42),a*.7)
	h.InkPages._center(h,"山路 %d / %d  ·  已通 %d 章"%[page+1,maxi(1,ceili(rows.size()/float(CHAPTERS_PER_PAGE))),int(campaign.get("completed",0))],Rect2(x+31,y+207,140,17),9,a,FADED)
	var opportunity:Dictionary=h.state.opportunity_status()
	if str(h.get_meta("expedition_view","route"))=="opportunity" and not opportunity.is_empty():
		txt(h,str(opportunity.get("title",opportunity.get("name","山间机缘"))),Vector2(x+230,y+85),22,a)
		wrapped(h,str(opportunity.get("text",opportunity.get("description",""))),Vector2(x+230,y+109),366,11,a,FADED,2)
		txt(h,"此缘常留 · 何时回应都不迟",Vector2(x+232,y+230),10,a,FADED)
		return
	var chapter:int=int(chosen.get("chapter",rows.find(chosen)+1))
	if str(h.get_meta("expedition_view","route"))=="guide":
		var guide:Dictionary=_chapter_guide(h,chosen)
		if not guide.is_empty():
			txt(h,"第 %d / %d 章 · 守灵 / 备行"%[chapter,rows.size()],Vector2(x+230,y+77),10,a,FADED)
			txt(h,h.InkPages._ellipsis(str(guide.get("monster_name","守关者")),254,18),Vector2(x+230,y+104),18,a)
			wrapped(h,str(guide.get("identity","")),Vector2(x+230,y+126),371,10,a,FADED,2)
			wrapped(h,"备行 · "+str(guide.get("preparation","")),Vector2(x+230,y+160),371,10,a,JADE,2)
			wrapped(h,str(guide.get("material_name","山材"))+" → "+str(guide.get("crafting_goal","")),Vector2(x+230,y+196),371,10,a,INK,1)
			return
	txt(h,"第 %d / %d 章"%[chapter,rows.size()],Vector2(x+230,y+77),10,a,FADED)
	txt(h,h.InkPages._ellipsis(str(chosen.get("title",chosen.get("name","青竹关"))),371,22),Vector2(x+230,y+102),22,a)
	var story:String=str(chosen.get("resolution","")) if int(chosen.get("clears",0))>0 else ""
	if story.is_empty():story=str(chosen.get("summary",chosen.get("description","循竹影前行，途经机缘，迎战镇关灵兽。")))
	wrapped(h,story,Vector2(x+230,y+123),371,11,a,FADED,2)
	var status:Dictionary=h.state.stage_status()
	var objective:String="本章目标 · 走过两场交锋，击退守关者。"
	if h.encounter_active:objective="行程进行中 · %s · 已过 %d / %d 敌"%[str(status.get("name","")),int(status.get("kills",0)),int(status.get("total",3))]
	elif bool(status.get("paused",false)):
		objective=("败退留有余地 · " if bool(status.get("failed",false)) else "上次停在 · ")+str(status.get("name",""))+" · 已过 %d / %d 敌"%[int(status.get("kills",0)),int(status.get("total",3))]
	elif not bool(chosen.get("unlocked",false)):objective=_chapter_gate(h,chosen)
	elif int(chosen.get("clears",0))>0:objective=str(chosen.get("next_objective","已通关 %d 回 · 这段山路已写入归途。"%int(chosen.get("clears",0))))
	wrapped(h,objective,Vector2(x+230,y+165),371,11,a,JADE if bool(chosen.get("unlocked",false)) else RED,1)
	var reward:String=str(chosen.get("first_clear_reward_text","每敌有物资；木箱 12% · 装备 3% 独立判定")).replace("灵气","功德" if h.state.realm==h.state.MAX_REALM else "灵气")
	wrapped(h,("首通已收 · " if bool(chosen.get("first_clear_claimed",false)) else "首通心意 · ")+reward,Vector2(x+230,y+186),371,10,a,FADED,2)
	if opportunity.is_empty() and not _can_abandon_for_chapter(h,chosen,status) and not bool(chosen.get("reward_pending",false)) and not bool(campaign.get("story_resolved",false)):
		wrapped(h,"机缘会等你 · 败退可续程 · 每章手动出发" if bool(chosen.get("unlocked",false)) else "静修提升境界，前章通关后便可继续。",Vector2(x+230,y+221),371,10,a,FADED,1)

static func _meridian_branch(h) -> String:
	var id:String=str(h.get_meta("meridian_branch","central"))
	if not h.state.Content.MERIDIAN_BRANCHES.has(id):id="central"
	return id

static func _meridian_branch_points(h) -> Array:
	var rows:Array=[]
	for row in h.state.meridian_rows():
		if str(row.branch)==_meridian_branch(h):rows.append(row)
	return rows

static func _selected_meridian(h)->Dictionary:
	var rows:Array=_meridian_branch_points(h)
	var selected:String=str(h.get_meta("meridian_id","qihai"))
	for row in rows:
		if str(row.id)==selected:return row
	return rows[0] if not rows.is_empty() else {}

static func _choose_meridian_branch(h,id:String):
	h.set_meta("meridian_branch",id)
	# Keep one remembered selection per branch, without changing any progression.
	h.set_meta("meridian_id",str(h.get_meta("meridian_selected_"+id,"")))
	var chosen:Dictionary=_selected_meridian(h)
	h.set_meta("meridian_id",str(chosen.get("id","qihai")))
	h._refresh_drawer()

static func _point_position(row:Dictionary) -> Vector2:
	var p:Dictionary=row.get("map_position",{})
	return Vector2(float(p.get("x",120)),float(p.get("y",126)))

static func _meridian_hint(row:Dictionary) -> String:
	var parents:String="、".join(row.get("prerequisite_names",[]))
	return str(row.description)+"\n"+str(row.effect)+"\n"+("起始穴位" if parents.is_empty() else "前置："+parents)+"\n"+str(row.locked_reason)

static func build_meridian(h,x:float,y:float):
	var branches:Array=h.state.meridian_branch_rows()
	for i in range(branches.size()):
		var branch:Dictionary=branches[i]
		var id:String=str(branch.id)
		button(h,"meridian_branch_"+id,"%s %d/%d"%[str(branch.name),int(branch.opened),int(branch.total)],Rect2(x+i*121,y+60,116,27),func():_choose_meridian_branch(h,id),str(branch.description),false,_meridian_branch(h)==id)
	var rows:Array=_meridian_branch_points(h)
	var chosen:Dictionary=_selected_meridian(h)
	for row in rows:
		var id:String=str(row.id)
		var p:Vector2=_point_position(row)+Vector2(x,y)
		var b:Button=button(h,"meridian_row_"+id,str(row.name),Rect2(p-Vector2(34,20),Vector2(68,50)),func():
			h.set_meta("meridian_id",id);h.set_meta("meridian_selected_"+str(row.branch),id);h._refresh_drawer(),_meridian_hint(row),false,str(chosen.get("id",""))==id)
		b.set_meta("ink_region",true)
	var locked:bool=h.InkPages._live_loadout_locked(h)
	var unlock:Button=button(h,"unlock_meridian","此穴已通" if bool(chosen.get("active",false)) else ("交锋后通脉" if locked else "温养通脉"),Rect2(x+435,y+239,169,29),func():
		if h.InkPages._live_loadout_locked(h):
			h._notice("交锋中可查阅经脉；此敌结束后再通脉，当前招式不受干扰。");return
		var result:Dictionary=h.state.unlock_meridian(str(chosen.id))
		if bool(result.get("ok",false)):
			h.meridian_glow=1.0;h._save_loadout();h._notice(str(chosen.get("name","经脉"))+"已通 · "+str(chosen.get("effect","")),"level");h._refresh_drawer(),"必定成功，只支付所列资源一次。四条支脉可自由搭配，境界突破无需通脉。",true)
	unlock.disabled=locked or not bool(chosen.get("can_unlock",false))

static func draw_meridian(h,x:float,y:float,a:float):
	var origin:Vector2=Vector2(x,y)
	var branch_id:String=_meridian_branch(h)
	var branch:Dictionary=h.state.Content.MERIDIAN_BRANCHES[branch_id]
	var hue:Color=Color(str(branch.color))
	var rows:Array=_meridian_branch_points(h)
	var chosen:Dictionary=_selected_meridian(h)
	var positions:Dictionary={}
	for row in rows:positions[str(row.id)]=_point_position(row)+origin
	rule(h,origin+Vector2(250,96),origin+Vector2(250,264),a)
	# Only this branch is drawn. Its edges are the actual unlock prerequisites.
	for row in rows:
		var p:Vector2=positions[str(row.id)]
		for required in row.get("prerequisites",[]):
			if not positions.has(str(required)):continue
			var from:Vector2=positions[str(required)]
			var direction:Vector2=(p-from).normalized()
			var active:bool=bool(row.get("active",false))
			h.draw_line(from+direction*21,p-direction*21,Color(hue,a*(.72 if active else .25)),1.6,true)
			var midpoint:Vector2=from.lerp(p,.58)
			var cross:Vector2=Vector2(-direction.y,direction.x)*3
			h.draw_polyline(PackedVector2Array([midpoint-direction*4+cross,midpoint,midpoint-direction*4-cross]),Color(hue,a*.5),1,true)
			if active:
				var t:float=fposmod(h.interface_clock*.33,1.0)
				h.draw_circle((from+direction*22).lerp(p-direction*22,t),1.8,Color("b69c59",a*.75))
	if branch_id!="central":
		h.InkPages._center(h,"气海启四脉 · 左右可择先",Rect2(x+3,y+94,236,16),10,a,FADED)
	else:h.InkPages._center(h,"任督六穴 · 根基循序相承",Rect2(x+3,y+96,236,16),10,a,FADED)
	for row in rows:
		var p:Vector2=positions[str(row.id)]
		var active:bool=bool(row.get("active",false))
		var ready:bool=bool(row.get("can_unlock",false))
		var selected:bool=str(row.id)==str(chosen.get("id",""))
		h.draw_circle(p,20,Color(hue,a*(.13 if active else .035)))
		h.draw_arc(p,20,0,TAU,36,Color(RED if selected else hue,a*(.86 if selected else .43)),1.5 if selected else 1.0,true)
		if active:h.draw_arc(p,16.5,0,TAU,32,Color(hue,a*.28),.8,true)
		h.InkPages._center(h,str(row.name),Rect2(p-Vector2(24,9),Vector2(48,18)),13,a,INK if active or ready or selected else FADED)
		h.InkPages._center(h,"已通" if active else ("可通" if ready else "待修"),Rect2(p+Vector2(-26,22),Vector2(52,14)),9,a,hue if active or ready else FADED)
	var parents:String="、".join(chosen.get("prerequisite_names",[]))
	txt(h,str(chosen.get("name","气海")),Vector2(x+270,y+112),23,a)
	txt(h,str(branch.title),Vector2(x+337,y+108),12,a,hue)
	wrapped(h,str(chosen.get("description","")),Vector2(x+271,y+135),330,12,a,FADED,2)
	wrapped(h,str(chosen.get("effect","")),Vector2(x+271,y+176),330,13,a,hue,1)
	var gate:String="境界 · "+str(h.state.REALM_NAMES[int(chosen.get("unlock_realm",0))])+"   前置 · "+("无" if parents.is_empty() else parents)
	wrapped(h,gate,Vector2(x+271,y+197),330,10,a,FADED,1)
	var active:bool=bool(chosen.get("active",false))
	txt(h,"永久生效 · 此穴不再付费" if active else "需 %d %s · %d 灵草 · %d 晨露"%[int(chosen.get("cost_qi",0)),str(chosen.get("energy_name","灵气")),int(chosen.get("cost_herbs",0)),int(chosen.get("cost_dew",0))],Vector2(x+271,y+220),11,a,FADED)
	wrapped(h,str(chosen.get("locked_reason","")) if not bool(chosen.get("can_unlock",false)) else "资源齐备 · 必定成功",Vector2(x+271,y+249),159,10,a,hue if active else RED,2)
	txt(h,"已通 %d / %d · 可跨脉修习 · 不阻境界"%[h.state.meridian_count,h.state.Content.ACUPOINTS.size()],Vector2(x+2,y+272),9,a,FADED)
