extends SceneTree
## Save a paused, earned, pre-crafting checkpoint for the genuine UI demonstration.
const Earned = preload("res://tests/chapter_crafting_plan.gd")
var output := "/tmp/chapter-crafting-checkpoints"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var journey := Earned.new()
	var ok: bool = journey.prepare()
	var s = journey.state
	if ok:
		for id in s.equipped_actives.duplicate(): s.unequip_technique(str(id), "active")
		journey.check(s.equip_technique("petal", "weapon_art").get("ok", false)
			and s.equip_technique("petal", "active").get("ok", false), "paid learned petal is ready for explicit fan equip")
		if int(s.technique_levels.get("barrier", 0)) > 0:
			journey.check(s.equip_technique("barrier", "active").get("ok", false), "earned barrier fills the second active slot")
	s.settings.paused = true
	var snapshot: Dictionary = s._snapshot()
	journey.check(s._valid_save(snapshot), "earned pre-crafting checkpoint validates")
	if ok and journey.errors.is_empty():
		var checkpoint := FileAccess.open(output.path_join("before-crafting.json"), FileAccess.WRITE)
		checkpoint.store_string(JSON.stringify(snapshot, "\t"))
		checkpoint.close()
	var provenance: Dictionary = journey.report()
	provenance.checkpoint = "before-crafting.json"
	provenance.checkpoint_valid = s._valid_save(snapshot)
	provenance.checkpoint_paused = true
	provenance.next_ui_steps = ["凝炼灵息 twice (6 earned shards)", "缚制流云扇 (4 earned feathers + 2 stones)",
		"Explicitly equip the newly owned fan", "凝炼灵息 once (remaining 3 earned shards)",
		"Enhance that fan to +1 with the third stone", "Paid petal already occupies weapon_art and active",
		"Explicitly depart for ember_ruins"]
	var file := FileAccess.open(output.path_join("provenance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(provenance, "\t"))
	file.close()
	var setup := {"checkpoint": output.path_join("before-crafting.json"), "checkpoint_valid": s._valid_save(snapshot),
		"paused": true, "stage_active": s.stage_status().active, "selected_stage": s.selected_stage,
		"realm": s.realm, "seconds": s.lifetime_seconds, "seed": Earned.DRY_SEED,
		"earned_victories": s.total_victories, "stage_clears": s.stage_clears,
		"materials": s.materials.to_dict(), "gear": s.gear.to_dict(), "hero": s.stats(),
		"form": s.equipped_weapon_art, "actives": s.equipped_actives, "passives": s.equipped_passives,
		"petal_level": int(s.technique_levels.petal), "training_pending": s.technique_training,
		"random_rewards": journey.chances, "study": {"cost": journey.petal_study.get("cost", {}), "duration": journey.petal_study.get("duration", 0)},
		"provenance": output.path_join("provenance.json"), "source": Earned.measurement_metadata()}
	file = FileAccess.open(output.path_join("setup.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(setup, "\t"))
	file.close()
	print("CHAPTER_CRAFTING_CHECKPOINT ", output, " checks=", journey.checks, " errors=", journey.errors.size())
	quit(0 if ok and journey.errors.is_empty() else 1)
