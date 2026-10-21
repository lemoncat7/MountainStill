extends RefCounted
## A read-only, resumable recommendation, never a reward system or unlock gate.
## Every completion is derived from owned things and paid, persistent progress.
const PHASES := ["settle", "learn", "breakthrough", "bamboo", "growth", "craft", "chapters", "home"]
const TITLES := ["安顿山居", "研习通脉", "初次突破", "青竹试行", "章间养成", "百工成器", "六印历练", "归山长住"]
const SUMMARIES := [
	"先看随身木箱，亲手穿戴所得。归息心法已知，可免费确定首次心法。不开箱也能空手行路。",
	"采药每8秒一草、24秒一露。云岚第二重需6草2露、研习9秒；气海需30灵气3草1露，吐纳永久+5%。两者均是可选培养。",
	"静坐积灵气，采药备灵草。在修行页查看消耗与新解锁，亲点一次升一阶；随缘挂机需你开启。",
	"亲选青竹关，出发后三场实战。击退后走近搜寻2秒再入袋，途中机缘会等你；首通青锋剑须亲手装备。",
	"每章首通只赠一次成长资源。先比较装备，再把灵气用于突破、草露用于学习/通脉/淬炼，准备下一章。",
	"青苔纤维可先织衣，三章后云羽可扎扇。3枚碎屑炼1石；稀有灵髓玉、随机箱子都不是通关条件。制成后亲手穿戴。",
	"六章依序展开，前章首通与境界共同解锁。每次选择一条路，不会连打下一章；新技能、经脉与装备由你搭配。",
	"六印与归真齐备后回家亲写终章。此后收藏、培育不同流派、+5淬炼或重游旧路；只静修也可独自归真。"
]

static func _goal(id: String, title: String, summary: String, detail: String, action: String, kind: String, target: String, phase: String, progress: String = "", skippable: bool = false) -> Dictionary:
	return {"id": id, "title": title, "summary": summary, "detail": detail, "action": action, "kind": kind, "target": target,
		"phase": phase, "index": PHASES.find(phase), "total": PHASES.size(), "progress": progress, "complete": false, "skippable": skippable}

static func _want(s, id: String) -> bool:
	return not bool(s.journey_skipped.get(id, false))

static func _manual(s, id: String) -> Dictionary:
	for row in s.technique_rows():
		if String(row.id) == id: return row
	return {}

static func _resource_goal(s, id: String, herbs: int, dew: int, qi: float, purpose: String, phase: String) -> Dictionary:
	if s.herbs < herbs or s.dew < dew:
		var seconds: float = maxf(maxi(0, herbs - s.herbs) * 8.0 - s._gather_clock, maxi(0, dew - s.dew) * 24.0 - s._dew_clock) / s.gather_multiplier()
		return _goal(id, "采药备料", purpose, "采药时不同时吐纳。灵草用于突破、研习、炼丹与淬炼；晨露用于研习与温养。选择静坐可随时换回。", "继续采药" if s.activity == "gather" else "去采药", "gather", "", phase,
			"灵草 %d/%d · 晨露 %d/%d · 约还需%d秒" % [s.herbs, herbs, s.dew, dew, ceili(maxf(0.0, seconds))], true)
	if s.qi + s.EPSILON < qi:
		return _goal(id, "静坐养息", purpose, "收起书页也会继续。离山最多结算8小时；暂停不积累。修为灵气用于突破与通脉，战斗真气另行计算。", "继续静坐" if s.activity == "meditate" else "去静坐", "meditate", "", phase,
			"灵气 %d/%d · 约还需%d秒" % [s.qi, qi, ceili(maxf(0.0, qi - s.qi) / s.qi_rate())], true)
	return {}

static func _study(s, id: String, rank: int, phase: String, purpose: String) -> Dictionary:
	var key := "study_%s_%d" % [id, rank]
	if int(s.technique_levels.get(id, 0)) >= rank or not _want(s, key): return {}
	var row := _manual(s, id)
	if row.is_empty() or not bool(row.unlocked) or s.realm < int(row.next_rank_realm): return {}
	var supply := _resource_goal(s, key, int(row.cost_herbs), int(row.cost_dew), 0.0, purpose, phase)
	if not supply.is_empty(): return supply
	return _goal(key, "研习" + String(row.name), purpose,
		"先支付所列草露，再等待真实研习计时。学成的重数永久保留；纳入通习与装入心法/武式/主动/辅修栏是不同选择。" + (" " + String(row.locked_reason) if not bool(row.can_upgrade) else ""),
		"翻阅" + String(row.name), "technique", id, phase, "%d→%d重 · %d草%d露 · %d秒" % [row.level, int(row.level) + 1, row.cost_herbs, row.cost_dew, row.training_duration], true)

static func _breakthrough(s, phase: String, why: String) -> Dictionary:
	var resource := _resource_goal(s, "realm_" + str(s.realm), int(s.HERB_COSTS[s.realm]), 0, float(s.QI_COSTS[s.realm]), why, phase)
	if not resource.is_empty():
		# A next-chapter realm gate is a genuine requirement. Only the optional
		# first-breakthrough recommendation below may be skipped in favor of bamboo.
		resource.skippable = false
		return resource
	var preview: Dictionary = s.breakthrough_preview()
	return _goal("realm_" + str(s.realm), "突破至" + s.next_realm_name(), why, String(preview.cost) + " " + String(preview.unlocks), "查看突破", "practice", "", phase,
		"灵气 %d/%d · 灵草 %d/%d" % [s.qi, s.QI_COSTS[s.realm], s.herbs, s.HERB_COSTS[s.realm]])

static func _owned_upgrade(s, phase: String) -> Dictionary:
	# Compare actual owned items rather than demanding a named reward. A player
	# who found or made a stronger alternative is never sent backwards.
	for item in s.inventory:
		var id := int(item.id)
		if id in s.equipped.values() or not _want(s, "equip_" + str(id)): continue
		var worn: Dictionary = s.gear.equipped_item(String(item.slot))
		var score := int(item.attack) + int(item.defense)
		var old := int(worn.get("attack", 0)) + int(worn.get("defense", 0))
		if score <= old: continue
		return _goal("equip_" + str(id), "让行装真正生效", "已拥有" + String(item.name) + "。先比较，再决定是否替换当前部位。",
			"只有亲手穿戴才增加实际属性与改变外观。旧装备留在行囊；若喜欢当前搭配，可略过这条建议。", "比较并穿戴", "equipment", str(id), phase,
			"攻击 %+d · 防御 %+d" % [int(item.attack) - int(worn.get("attack", 0)), int(item.defense) - int(worn.get("defense", 0))], true)
	return {}

static func _craft(s, recipe: String, phase: String) -> Dictionary:
	var key := "craft_" + recipe
	if not _want(s, key): return {}
	var quote: Dictionary = s.crafting_quote(recipe)
	if not bool(quote.get("unlocked", true)): return {}
	var template: String = String(quote.get("output_item", {}).get("template_id", ""))
	if template.is_empty() or bool(s.gear.discovered_templates.get(template, false)): return {}
	var cost: Dictionary = quote.get("materials", {})
	var stones: int = int(cost.get("refinement_stone", 0))
	if s.material_count("refinement_stone") < stones:
		# Early shirt uses spare same-route fiber; shards remain available for the
		# later fan. The selected material is explicit in the real recipe page.
		var source := "moss_fiber" if recipe == "weave_armor" else "spirit_shard"
		var reserve: int = int(cost.get(source, 0))
		if s.material_count(source) < 3 + reserve: return {}
		return _goal(key, "先炼一枚淬炼石", "为" + String(quote.name) + "备料。" + ("用3枚青苔灵纤，留下3枚织衣，碎屑留作后续制扇。" if source == "moss_fiber" else "3枚灵息碎屑炼1石，三章的普通搜寻足够制扇。"),
			"合成必定成功。来源材料由你亲选；耗尽时停止，不会偷偷替用稀有物。之后返回入山指引查看下一步。", "查看凝炼配方", "crafting", "refine_route:moss_fiber" if source == "moss_fiber" else "refine_stone", phase,
			"淬炼石 %d/%d" % [s.material_count("refinement_stone"), stones], true)
	if not bool(quote.get("can_craft", false)): return {}
	return _goal(key, String(quote.name), "把已搜寻的普通山材做成真实衣冠兵器。", "制作不会自动穿戴。先读材料与属性差值，再制成、穿戴；不用等稀有掉落。", "查看制作配方", "crafting", recipe, phase, "材料已齐 · 制成后仍需亲手穿戴", true)

static func status(s) -> Dictionary:
	var chapter: Dictionary = s.chapter_status()
	var completed := int(chapter.completed)
	var route: Dictionary = s.stage_status()
	if bool(route.active) or bool(route.paused):
		var summary := "还有本程未走完的路。已得收获与击退进度保留，下一章不会自行开启。"
		if bool(route.corpse_pending): summary = "守灵已倒地，搜寻满2秒后才收下物品。已固定的收获不会因归山或读档重掷。"
		elif bool(route.opportunity_pending): summary = "途中机缘正在等你选择，没有倒计时。"
		elif bool(route.failed): summary = "这次先回山休整。可学习、换装再亲点继续，不扣已得资源。"
		return _goal("resume_route", "续行" + String(route.name), summary, "离线不打斗、不搜寻、不恢复本程战斗真气。读档停在山居，点击继续才重返原检查点。", "查看本程", "route", String(route.id), "bamboo" if completed == 0 else "chapters", "已收获 %d/3 场" % int(route.kills))
	if not s.pending_heart_switch.is_empty():
		return _goal("heart_adjusting", "调息换修中", "旧心法仍然生效，调息结束才转入新法。", "此期间不可出发或再次换修；可静坐、采药或翻阅书页。离线会按8小时上限继续。", "查看心法", "technique", String(s.pending_heart_switch.to_id), "growth", "剩余 %d 秒" % ceili(float(s.pending_heart_switch.remaining)))
	if not s.technique_training.is_empty():
		var training: Dictionary = s.technique_training[0]
		return _goal("training_" + String(training.id), "正在研习" + String(s.Content.TECHNIQUES[training.id].name), "草露已支付，计时完成后才获得新重数。", "研习与静坐/采药可同时进行；关书不停止，暂停则一起停下。已学重数存档保留，不会因打开书页重复收费。", "查看研习", "technique", String(training.id), "learn" if completed == 0 else "growth", "剩余 %d 秒" % ceili(float(training.remaining)))
	if bool(chapter.ending_complete):
		var final := _goal("longterm", "一卷已毕，山居长在", "六章与归真已完成。下一段由你选择：换一种流派，温养喜欢的装备，或继续收藏。", "静坐归真后积功德；草露支持研习和心法换修；普通材料继续用于制作与+5淬炼。重游旧路仍要手动出发，首通心意不会重复发放。", "翻阅收藏与成长", "longterm", "", "home", "六印齐 · 归真 · 终章已落笔")
		final.complete = true
		return final
	if not chapter.pending_rewards.is_empty():
		return _goal("pending_reward", "收下已得的首通心意", "此章已经通关，首通赠礼尚未入袋。", "腾出行囊或资源空间后再领取；不会丢失，也不会因为反复打开书页重复发放。", "查看首通心意", "route", String(chapter.pending_rewards[0]), "growth")
	if bool(chapter.story_resolved):
		if s.realm < s.MAX_REALM: return _breakthrough(s, "home", "六印已齐，将本程所得修为逐阶化入境界，归真后回家落笔。")
		return _goal("epilogue", "亲写归山终章", "六印与归真齐备，这一卷由你亲手结束。", "写下终章后仍可培养、收藏、游历和重访旧路。它不会开启新付费内容或自动出发。", "翻阅归山终章", "ending", "", "home", "六章皆通 · 十六阶圆满")
	if completed == 0:
		if s.equipped.is_empty() and (s.chest_count > 0 or not s.inventory.is_empty()) and _want(s, "first_equipment"):
			return _goal("first_equipment", "安顿第一件行装", "入山时赤膊白短裤。随身木箱保证一件入门装备，先启封，再选择穿上。", "衣冠与兵器分别占五个部位。持剑才有剑招；没有兵器也能空手交锋。随机首箱不是通关门槛。", "整理随身行装", "equipment", "", "settle", "随身木箱 %d · 已有装备 %d" % [s.chest_count, s.inventory.size()], true)
		if not s.heart_equipped_once and _want(s, "first_heart"):
			return _goal("first_heart", "把归息用起来", "你已知归息首重，但尚未确定心法。首次确定免费且立即生效。", "归息增加战斗真气上限与恢复，方便普攻间穿插主动招。以后换修会先展示材料与调息时间；书卷等级不会丢。", "查看归息心法", "technique", "breath", "learn", "首次心法 · 免费确定", true)
	# Optional old sidequests are available when genuinely ready; they support
	# the early materials budget without a new gift/reward faucet.
	if completed < 2:
		for quest in s.quest_rows():
			if bool(quest.ready) and _want(s, "quest_" + String(quest.id)):
				return _goal("quest_" + String(quest.id), "记下" + String(quest.name), String(quest.description), "这是已经完成的小事。到山居志亲手领取一次心意；不领取也可继续修行与行路。", "翻到这页小记", "quest", String(quest.id), "learn" if completed == 0 else "growth", "已完成 · 心意待领", true)
	if completed == 0:
		if int(s.counters.get("techniques_trained", 0)) == 0:
			var study := _study(s, "mist", 2, "learn", "第一次温故能增加实际攻击；云岚剑招还需要持剑，首章会给一柄确定的青锋剑。")
			if not study.is_empty(): return study
		if s.meridian_count == 0 and _want(s, "first_meridian"):
			var supply := _resource_goal(s, "first_meridian", 3, 1, 30.0, "温养气海：30灵气、3草、1露，换取永久吐纳+5%。通脉与突破可自行取舍。", "learn")
			if not supply.is_empty(): return supply
			return _goal("first_meridian", "让气息有根", "气海温养后，吐纳永久+5%，并打开四条可自由搭配的支脉。", "支付30灵气、3草、1露，必定成功。经脉从不锁住境界，随时可先突破或先出发。", "查看气海", "meridian", "qihai", "learn", "30灵气 · 3草 · 1露", true)
		if s.realm == 0 and _want(s, "first_breakthrough"):
			var goal := _breakthrough(s, "breakthrough", "完成一次亲手突破，理解修为怎样变成实际攻防，并开启炼气中期功法。青竹关亦可直接试行。")
			goal.id = "first_breakthrough"
			goal.skippable = true
			return goal
	else:
		var gear := _owned_upgrade(s, "growth")
		if not gear.is_empty(): return gear
		if completed == 1 and s.gear.equipped_item("chest").is_empty():
			var armor := _craft(s, "weave_armor", "craft")
			if not armor.is_empty(): return armor
		var next_id := String(chapter.current_stage_id)
		var needed: int = int(s.Content.STAGES[next_id].unlock_realm)
		if s.realm < needed: return _breakthrough(s, "growth", "下一章" + String(s.Content.STAGES[next_id].name) + "需" + String(s.REALM_NAMES[needed]) + "。首通灵气已到账，仍按所列消耗逐阶突破。")
		if completed == 1:
			var mist := _study(s, "mist", 3, "growth", "听泉石灵守势较重。提高已有剑诀，首通青锋剑才更能发挥作用。也可沿用自己的搭配。")
			if not mist.is_empty(): return mist
		if completed >= 2 and _want(s, "prepare_support"):
			var support := _study(s, "barrier", 1, "growth", "筑基开放第二主动栏。护元可与剑诀同装，耗真气吸收实际来伤。")
			if not support.is_empty(): return support
			if int(s.technique_levels.get("barrier", 0)) > 0 and s.equipped_actives.size() < s.active_capacity() and not s.equipped_actives.has("barrier"):
				return _goal("prepare_support", "把新招装进主动栏", "护元已学成。装入新增的主动栏，交锋才会实际使用。", "武式管持械普攻，主动栏管耗气技能；学会或通习本身不会自动施放。也可保留你的其他搭配。", "查看护元装配", "technique", "barrier", "growth", "主动栏 %d/%d" % [s.equipped_actives.size(), s.active_capacity()], true)
		if completed == 3:
			var fan := _craft(s, "bind_cloud_fan", "craft")
			if not fan.is_empty(): return fan
			if String(s.gear.visual_loadout().get("weapon", "")) == "weapon_fan":
				var petal := _study(s, "petal", 1, "craft", "流云扇已经在手。落英的武式与主动各自装配，扇招才会接入真实交锋。")
				if not petal.is_empty(): return petal
				if s.equipped_weapon_art != "petal" and _want(s, "fan_form"):
					return _goal("fan_form", "扇与落英相合", "将已学的落英装入武式；主动回锋可另选。原有剑诀重数会保留。", "换流派是选择，不是强制。若更喜欢剑，可以略过建议并穿回青锋。", "查看落英装配", "technique", "petal", "craft", "持扇 · 落英已学", true)
		if completed >= 4:
			var manual := "petal" if String(s.gear.visual_loadout().get("weapon", "")) == "weapon_fan" else "mist"
			var growth := _study(s, manual, 3 if manual == "petal" else 5, "growth", "后段守灵更强，先把已用的功法推进一重；草露不足可回山采集，不依赖稀有物。")
			if not growth.is_empty(): return growth
	var id := String(chapter.current_stage_id)
	var next := _goal("depart_" + id, "启程" + String(s.Content.STAGES[id].name), String(s.Content.CHAPTERS[id].summary),
		"先在备行页看守灵特点和材料用途，再亲点出发。每章两敌一守关，搜寻后才入袋；归山后比较装备、培养、突破，再选下一章。", "查看本章山路", "route", id, "bamboo" if completed == 0 else "chapters", "六印 %d/6 · 本章三场" % completed)
	return next

static func rows(s) -> Array:
	var current: Dictionary = status(s)
	var chapters: Dictionary = s.chapter_status()
	var done := [not s.equipped.is_empty(), int(s.counters.get("techniques_trained", 0)) > 0 and s.meridian_count > 0, s.realm > 0,
		int(s.stage_clears.get("bamboo_pass", 0)) > 0, int(chapters.completed) >= 2, int(s.counters.get("crafted", 0)) > 0,
		bool(chapters.story_resolved), bool(chapters.ending_complete)]
	var result: Array = []
	for i in range(PHASES.size()):
		result.append({"id": PHASES[i], "title": TITLES[i], "summary": SUMMARIES[i], "done": done[i], "current": current.phase == PHASES[i]})
	return result
