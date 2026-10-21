extends SceneTree
## One bounded, lawful fan-build continuation. Separate from the dry first-four
## chapter proof: later random events may occur, but random gear is never worn.
const Earned = preload("res://tests/chapter_crafting_plan.gd")
const State = preload("res://scripts/cultivation_state.gd")
const Plan = preload("res://tests/campaign_build_plan.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const DT := 1.0 / 60.0
var checkpoint := "/tmp/chapter-crafting-checkpoints/before-crafting.json"
var output := "/tmp/earned-fan-continuation.json"
var journey = Earned.new()
var actions: Array = []
var late_battles: Array = []
var opportunities: Array = []
var random_loot: Array = []
var fan_id := -1
var completed := false
var isolated_save := "user://diagnose_fan_continuation_%d.json" % OS.get_process_id()

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--checkpoint="): checkpoint = arg.trim_prefix("--checkpoint=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var s := State.new()
	# load_game checkpoints internally; preserve the shared capture source.
	var copied := FileAccess.open(isolated_save, FileAccess.WRITE)
	copied.store_string(FileAccess.get_file_as_string(checkpoint))
	copied.close()
	s.save_path = isolated_save
	if journey.check(s.load_game().get("loaded", false), "load the genuinely earned, paused pre-crafting checkpoint"):
		journey.state = s
		s.settings.paused = false
		if _initial_fan() and journey.run_stage("ember_ruins"):
			_prepare_next(4, 2)
			if _late_route("moon_marsh"):
				_prepare_next(5, 3)
				completed = _late_route("summit_gate")
	var metadata: Dictionary = Earned.measurement_metadata()
	metadata.source_sha256["tests/diagnose_earned_fan_continuation.gd"] = FileAccess.get_sha256("res://tests/diagnose_earned_fan_continuation.gd")
	var report := {"scope": "One fixed sensible fan continuation, not a build search; native enemies unchanged; no retries, grinding or injected state.",
		"checkpoint": checkpoint, "checkpoint_sha256": FileAccess.get_sha256(checkpoint),
		"checkpoint_provenance": checkpoint.get_base_dir().path_join("provenance.json"),
		"source": metadata, "completed_six_chapters": completed, "checks": journey.checks, "errors": journey.errors,
		"fan_id": fan_id, "fan": journey.state.gear.get_item(fan_id), "final": journey.resources(),
		"actions": actions, "ember_battles": journey.records, "late_battles": late_battles,
		"opportunities": opportunities, "random_loot": random_loot,
		"random_equipment_used": false, "opener_and_dropped_chests_opened": int(journey.state.counters.chests_opened),
		"final_stage_active": journey.state.stage_status().active}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("FAN_CONTINUATION completed=", completed, " checks=", journey.checks, " errors=", journey.errors, " report=", output)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(isolated_save + suffix): DirAccess.remove_absolute(isolated_save + suffix)
	quit(0 if completed and journey.errors.is_empty() else 1)

func _initial_fan() -> bool:
	var s = journey.state
	for index in range(3):
		var result: Dictionary = s.craft_recipe("refine_stone")
		if not journey.check(result.get("ok", false), "initial earned shards combine"): return false
		actions.append(result.duplicate(true))
	var made: Dictionary = s.craft_recipe("bind_cloud_fan")
	if not journey.check(made.get("ok", false), "initial earned cloud fan crafted"): return false
	fan_id = int(made.item.id)
	actions.append(made.duplicate(true))
	journey.check(s.equip_item(fan_id), "same actual fan explicitly equipped")
	var enhanced: Dictionary = s.enhance_item(fan_id, "materials")
	actions.append(enhanced.duplicate(true))
	return journey.check(enhanced.get("ok", false) and int(s.gear.get_item(fan_id).enhancement) == 1,
		"initial third stone makes the earned fan +1")

func _prepare_next(cleared_chapters: int, target_rank: int) -> void:
	var s = journey.state
	s.step(0.1) # Funded, ordinary automatic breakthroughs; no realm edits.
	var before: Dictionary = journey.resources()
	var study: Array = []
	var targets := [["petal", 3], ["body", 2], ["barrier", 2], ["breath", 3]] if cleared_chapters == 4 else [["petal", 4], ["body", 3], ["barrier", 3], ["breath", 3]]
	for target in targets:
		var old_level := int(s.technique_levels[str(target[0])])
		var result: int = Plan.study(s, str(target[0]), int(target[1]))
		study.append({"id": target[0], "target": target[1], "before": old_level, "after": s.technique_levels[str(target[0])], "completed": result})
	Plan.buy_affordable_meridians(s)
	# Preserve the established fan/petal/barrier/breath/body loadout. The fixed
	# upgrade order is chosen before either late route is attempted.
	journey.check(int(s.equipped.weapon) == fan_id and s.equipped_weapon_art == "petal"
		and s.equipped_actives.has("petal") and s.equipped_actives.has("barrier"),
		"lawful preparation preserves the established fan build")
	while int(s.gear.get_item(fan_id).enhancement) < target_rank:
		var cost := int(s.gear.get_item(fan_id).enhancement) + 1
		while s.material_count("refinement_stone") < cost:
			var result: Dictionary = {}
			if s.material_count("spirit_shard") >= 3:
				result = s.craft_recipe("refine_stone")
			else:
				for material in ["moss_fiber", "river_ore", "ember_cinder", "moon_thread", "cloud_feather", "summit_jade"]:
					if s.material_count(material) >= 3:
						result = s.craft_recipe("refine_route", material)
						break
			if result.is_empty() or not result.get("ok", false):
				actions.append({"preparation_stopped": "no ordinary material budget", "target_rank": target_rank})
				break
			actions.append(result.duplicate(true))
		if s.material_count("refinement_stone") < cost: break
		var result: Dictionary = s.enhance_item(fan_id, "materials")
		actions.append(result.duplicate(true))
		if not result.get("ok", false): break
	actions.append({"prepare_after_chapter": cleared_chapters, "before": before,
		"after": journey.resources(), "study": study, "fan": s.gear.get_item(fan_id).duplicate(true)})

func _late_route(route: String) -> bool:
	var s = journey.state
	if not journey.check(s.select_stage(route), "earned late chapter gate " + route): return false
	var started: Dictionary = s.start_stage()
	if not journey.check(started.get("ok", false), "manual late chapter departure " + route): return false
	var run_id := int(started.run_id)
	var health := int(s.stats().max_hp)
	for index in range(3):
		if index == 2:
			var landmark: Dictionary = s.check_route_opportunity(run_id)
			if landmark.get("opportunity_pending", false):
				var choice: Dictionary = s.choose_opportunity("gather_gift")
				opportunities.append({"stage": route, "result": choice})
				if not journey.check(choice.get("ok", false), "actual late-route opportunity is resolved through API"): return false
		var hero: Dictionary = s.stats().duplicate(true)
		hero.hp = health
		hero.battle_resources = s.stage_battle_resources()
		var definition: Dictionary = Content.STAGES[route].monsters[index].duplicate(true)
		var enemy: Dictionary = Plan.prepare_enemy(definition, route)
		for field in definition: journey.check(enemy[field] == definition[field], "native late enemy retains " + str(field))
		journey.check(int(s.equipped.weapon) == fan_id, "original crafted fan is used for the actual late duel")
		var duel := Duel.new()
		duel.start(hero, enemy, s.technique, str(s.gear.visual_loadout().weapon), run_id * 1337 + index * 79 + 17)
		var events: Array = []
		while not duel.finished and duel.elapsed < 240.0:
			events.append_array(duel.advance(DT))
			s.step(DT)
		var record := {"stage": route, "index": index, "hero": hero, "enemy": enemy,
			"fan": s.gear.get_item(fan_id).duplicate(true), "seconds": duel.elapsed,
			"victory": duel.victory, "hp_end": duel.hero_hp, "events": journey.event_counts(events)}
		late_battles.append(record)
		print("FAN_LATE ", route, "/", index, " victory=", duel.victory, " hp=", duel.hero_hp, " seconds=", duel.elapsed)
		if not duel.finished or not duel.victory:
			s.fail_stage(run_id)
			journey.check(false, "fixed earned fan plan stopped at " + route + "/" + str(index))
			return false
		s.update_stage_battle_resources(run_id, duel.battle_resource_snapshot())
		health = duel.hero_hp
		if not journey.check(s.begin_stage_corpse(run_id, index).get("ok", false), "late real victory creates corpse"): return false
		for frame in range(120):
			s.advance_stage_search(run_id, index, DT)
			journey.rest(run_id, DT)
		var reward: Dictionary = s.complete_stage_search(run_id, index)
		if not journey.check(reward.get("ok", false), "late actual two-second corpse search pays"): return false
		if reward.chest_rolled or reward.equipment_rolled or reward.treasure_rolled:
			random_loot.append({"stage": route, "index": index, "chest": reward.chest_rolled,
				"equipment": reward.equipment_rolled, "treasure": reward.treasure_rolled, "item": reward.item})
		record.reward = reward
		if index < 2:
			journey.rest(run_id, 9.0)
		elif reward.chapter_reward.get("item") is Dictionary:
			# Keep the original crafted fan even after the final deterministic
			# epic fan reward. Only earned non-weapon first-clear armor is worn.
			if str(reward.chapter_reward.item.slot) != "weapon":
				journey.check(s.equip_item(int(reward.chapter_reward.item.id)), "equip genuinely earned late first-clear armor")
	journey.check(not s.stage_status().active and int(s.stage_clears[route]) == 1, "late chapter clears once and returns home")
	return true
