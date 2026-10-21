extends SceneTree
## Six-chapter campaign state tests. Natural play uses actual duel outcomes,
## ordinary breakthroughs and paid upgrades; only isolated edge fixtures mutate.
const State = preload("res://scripts/cultivation_state.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Plan = preload("res://tests/campaign_build_plan.gd")
const Ledger = preload("res://scripts/equipment_ledger.gd")
var checks := 0
var failures := 0
var prefix := "user://test_first_campaign_%d" % OS.get_process_id()

func _initialize() -> void:
	_test_content_and_gates()
	_test_lawful_campaign()
	_test_checkpoint_retry()
	_test_reward_caps_and_ownership()
	_test_v4_migration_and_sanitization()
	_test_authored_opportunities()
	_test_no_automatic_adventure()
	_cleanup()
	print("First campaign tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func fresh(suffix: String = "") -> State:
	var s := State.new()
	s.save_path = prefix + suffix + ".json"
	s._adventure_rng.seed = 20261020
	return s

func fingerprint(s: State) -> Array:
	return [s.herbs, s.dew, s.qi, s.merit, s.inventory.duplicate(true), s.total_victories, s.stage_clears.duplicate(), s.chapter_reward_claimed.duplicate(), s._adventure_rng.state]

func finish_fixture(s: State) -> Dictionary:
	var started := s.start_stage()
	if not bool(started.get("ok", false)):
		return started
	var result: Dictionary = {}
	for index in range(int(started.kills), 3):
		if index == 2:
			s.check_route_opportunity(int(started.run_id))
			if s.stage_status().opportunity_pending:
				s.choose_opportunity("read_inscription")
		result = s.defeat_stage_monster(int(started.run_id), index)
	return result

func _test_content_and_gates() -> void:
	var s := fresh()
	var rows := s.chapter_rows()
	check(Content.VERSION == 4 and rows.size() == 6, "schema v4 retained with six authored chapters")
	check(rows.map(func(r): return r.id) == Content.CHAPTER_ORDER, "stable original routes extended in authored order")
	check(rows.map(func(r): return r.unlock_realm) == [0, 1, 3, 6, 9, 12], "six realm gates are 0,1,3,6,9,12")
	check(s.chapter_status().completed == 0 and s.chapter_status().current_chapter == 1, "new game points at first chapter")
	check(not s.complete_home_epilogue().ok and not s.chapter_status().story_resolved, "new game cannot finish campaign")
	s.realm = 15
	for i in range(6):
		var id: String = Content.CHAPTER_ORDER[i]
		var row: Dictionary = s.chapter_rows()[i]
		check(row.monsters.size() == 3 and row.monsters.map(func(m): return m.boss) == [false, false, true], "exactly two normals then boss: " + id)
		check(not String(row.summary).is_empty() and not String(row.first_clear_reward_text).is_empty(), "chapter has authored story and transparent guaranteed reward: " + id)
		check(s.select_stage(id) == (i == 0), "realm alone cannot bypass new chapter prerequisite: " + id)
		if i > 0:
			check(String(row.locked_reason).contains(String(Content.STAGES[Content.CHAPTER_ORDER[i - 1]].name)), "gate names concrete prerequisite: " + id)

func _test_lawful_campaign() -> void:
	# This is a fresh actual character, without editing realm/resources/gear.
	var s := fresh("_natural")
	s.auto_advance = true # Deliberately opted-in legacy campaign path.
	Plan.configure(s, "sword", 0)
	var battle_seconds := 0.0
	var encounter_count := 0
	for chapter in range(6):
		var id: String = Content.CHAPTER_ORDER[chapter]
		check(s.select_stage(id), "legitimate prior rewards unlock chapter " + id)
		var started := s.start_stage()
		check(bool(started.get("ok", false)), "manual departure succeeds: " + id)
		if not bool(started.get("ok", false)):
			return
		var health := int(s.stats().max_hp)
		for index in range(3):
			if index == 2:
				s.check_route_opportunity(int(started.run_id))
				if s.stage_status().opportunity_pending:
					check(s.choose_opportunity("gather_gift").ok, "earned random choice is optional extra, never chapter gate")
			var hero := s.stats().duplicate(true)
			hero.hp = health
			hero.battle_resources = s.stage_battle_resources()
			var enemy: Dictionary = Plan.prepare_enemy(s.stage_status().next_monster, id)
			var duel := Duel.new()
			duel.start(hero, enemy, s.technique, String(s.gear.visual_loadout().get("weapon", "")), int(started.run_id) * 1337 + index * 79 + 17)
			for tick in range(3000):
				if duel.finished:
					break
				duel.advance(0.1)
				s.step(0.1)
				battle_seconds += 0.1
			check(duel.finished and duel.victory, "earned build wins real duel: %s enemy %d" % [id, index])
			if not duel.victory:
				print("FAILED BUILD ", id, " ", hero, " enemy ", enemy)
				return
			s.update_stage_battle_resources(int(started.run_id), duel.battle_resource_snapshot())
			health = duel.hero_hp
			encounter_count += 1
			var result: Dictionary = s.defeat_stage_monster(int(started.run_id), index)
			check(result.ok, "only real victory pays encounter: " + id)
			if index < 2:
				var stats:Dictionary=s.stats()
				s.update_stage_battle_resources(int(started.run_id),Duel.rest_resource_snapshot(s.stage_battle_resources(),9.0,float(stats.combat_qi_max),float(stats.combat_qi_regen)))
				s.step(9.0)
			if index == 2:
				check(result.stage_finished and result.first_clear and result.chapter_reward.ok, "first-clear canonical package awarded exactly once: " + id)
				check(s.equip_item(int(result.chapter_reward.item.id)), "first-clear gear is real owned equippable instance: " + id)
				check(result.chapter_reward.item.template_id == Content.CHAPTERS[id].first_clear_reward.template_id, "fixed reward independent of random drops: " + id)
				var before := fingerprint(s)
				check(not s.claim_chapter_reward(id).ok and not s.defeat_stage_monster(int(started.run_id), index).ok and fingerprint(s) == before, "duplicate claim/callback never pays twice: " + id)
		s.step(0.1) # Ordinary automatic breakthroughs spend their published costs.
		Plan.configure(s, "sword", chapter + 1)
		Plan.buy_affordable_meridians(s)
		check(s.chapter_status().tokens.size() == chapter + 1 and not s.stage_status().active, "finite route returns home with permanent token, never autostarts")
		check(s._valid_save(s._snapshot()), "chapter completion remains valid v4 save")
	check(encounter_count == 18 and s.realm == 15, "six chapters plus funded ordinary breakthroughs reach归真")
	check(s.chapter_status().story_resolved and s.chapter_status().epilogue_ready and not s.chapter_status().ending_complete, "adventure resolution and home epilogue are separate explicit milestones")
	var before := fingerprint(s)
	check(s.complete_home_epilogue().ok and s.chapter_status().ending_complete, "explicit home epilogue completes finite first campaign")
	var journal_count := s.journal_rows().size()
	check(not s.complete_home_epilogue().ok and fingerprint(s) == before and s.journal_rows().size() == journal_count, "ending cannot pay or record twice")
	check(battle_seconds < 1800.0, "active first campaign needs no hours of artificial waiting")
	s.settings.paused = true
	check(s.save_game(), "complete campaign saves")
	var restored := fresh("_natural")
	check(restored.load_game().loaded, "complete campaign reloads")
	var restored_status := restored.chapter_status()
	var original_status := s.chapter_status()
	for key in ["story_resolved_at", "finished_at"]:
		check(absf(float(restored_status[key]) - float(original_status[key])) < 0.001, "campaign timestamp survives JSON precision: " + key)
		restored_status.erase(key)
		original_status.erase(key)
	check(restored_status == original_status, "six tokens, resolution, ending and claims survive reload")
	check(restored.inventory == s.inventory and restored.equipped == s.equipped and not restored.stage_status().active, "real rewarded equipped items survive reload without autostart")
	var gold_before := fingerprint(restored)
	for id in Content.CHAPTER_ORDER:
		check(not restored.claim_chapter_reward(id).ok, "reloaded claims remain idempotent: " + id)
	check(fingerprint(restored) == gold_before, "reloaded rewards never duplicate")
	print("LAWFUL FIRST CAMPAIGN: %d actual duel wins, %.1fs battle/simulation, realm=%d, techniques=%s, meridians=%d, owned=%d" % [encounter_count, battle_seconds, s.realm, s.technique_levels, s.meridian_count, s.inventory.size()])

func _test_checkpoint_retry() -> void:
	var s := fresh("_retry")
	s.auto_advance = false
	var started := s.start_stage()
	s.defeat_stage_monster(int(started.run_id), 0)
	var before := fingerprint(s)
	check(not s.fail_stage(int(started.run_id) + 1).ok and fingerprint(s) == before, "stale defeat cannot pause or mutate active run")
	check(s.fail_stage(int(started.run_id)).ok and s.stage_status().failed and s.stage_status().paused and s.stage_status().kills == 1, "defeat preserves earned first checkpoint")
	check(fingerprint(s) == before and not s.defeat_stage_monster(int(started.run_id), 1).ok, "failed run earns no additional or duplicate loot")
	s.settings.paused = true
	check(s.save_game(), "failed checkpoint saves")
	var restored := fresh("_retry")
	restored.load_game()
	check(restored.stage_status().failed and restored.stage_status().kills == 1 and not restored.stage_status().active, "failure reload remains paused at unbeaten enemy")
	restored.settings.paused = false
	var resumed := restored.start_stage()
	check(resumed.ok and resumed.reason == "resumed" and resumed.run_id == started.run_id and not resumed.failed, "manual retry resumes same reward token and clears failure flag")
	check(not restored.defeat_stage_monster(int(resumed.run_id), 0).ok, "retry cannot repeat defeated enemy reward")
	restored.defeat_stage_monster(int(resumed.run_id), 1)
	var rng := restored._adventure_rng.state
	check(restored.pause_stage(int(resumed.run_id)).ok and restored.stage_status().kills == 2, "voluntary home rest preserves checkpoint too")
	check(restored.start_stage().ok and restored._adventure_rng.state == rng, "retry itself neither rerolls nor pays")
	restored.check_route_opportunity(int(resumed.run_id))
	if restored.stage_status().opportunity_pending:
		restored.choose_opportunity("read_inscription")
	check(restored.defeat_stage_monster(int(resumed.run_id), 2).stage_finished and restored.total_victories == 3, "retry completes with exactly three paid kills")

func _test_reward_caps_and_ownership() -> void:
	var s := fresh("_capacity")
	s.auto_advance = false
	for index in range(Ledger.CAPACITY):
		s.gear.inventory.append(s.gear._make_item(s.gear._allocate_id(), "head_pin", "common", 1))
	var result := finish_fixture(s)
	check(result.stage_finished and result.first_clear and result.chapter_reward.reason == "inventory_full", "full bag cannot destroy unique first-clear gear")
	check(s.chapter_rows()[0].reward_pending and s.chapter_status().tokens == ["青竹印"], "permanent story token awarded, full package stays pending")
	var before := fingerprint(s)
	check(not s.claim_chapter_reward("bamboo_pass").ok and fingerprint(s) == before, "blocked reward is atomic with no partial qi/material payment")
	s.settings.paused = true
	s.save_game()
	var restored := fresh("_capacity")
	restored.load_game()
	check(restored.chapter_rows()[0].reward_pending, "pending finite reward persists across reload")
	var last_id := int(restored.inventory[-1].id)
	check(restored.salvage_item(last_id).ok, "make genuine inventory room by salvage")
	var claimed := restored.claim_chapter_reward("bamboo_pass")
	check(claimed.ok and restored.inventory.size() == Ledger.CAPACITY and not restored.chapter_rows()[0].reward_pending, "canonical reward claimed once capacity permits")
	check(restored.gear.discovered_templates.weapon_sword and restored.equip_item(int(claimed.item.id)), "guaranteed item enters collection and real equipment slot")
	var t := fresh()
	t.stage_clears.bamboo_pass = 1
	t.herbs = State.MAX_RESOURCE
	before = fingerprint(t)
	check(t.claim_chapter_reward("bamboo_pass").reason == "resource_full" and fingerprint(t) == before, "material cap never overflows or partially claims")
	t.herbs = 0
	t.qi = State.MAX_ENERGY
	check(t.claim_chapter_reward("bamboo_pass").reason == "resource_full" and t.inventory.is_empty(), "energy cap keeps whole package pending")
	t.qi = 0
	t.realm = 15
	check(t.claim_chapter_reward("bamboo_pass").ok and t.qi == 0.0 and t.merit == 180.0, "postgame reward correctly grants merit without invalid max-realm qi")
	check(t._valid_save(t._snapshot()), "capped/postgame reward ownership remains save-valid")

func _test_v4_migration_and_sanitization() -> void:
	var s := fresh("_legacy")
	s.realm = 3
	s.auto_advance = false
	s.settings.paused = true
	var data := s._snapshot()
	for key in ["campaign_revision", "chapter_reward_claimed", "legacy_unlocked_stages", "story_resolved_at", "ending_finished_at"]:
		data.adventure.erase(key)
	data.adventure.selected_stage = "cloud_slope"
	data.adventure.stage_clears = {"creek_bridge": 1}
	data.adventure.stage_run = {"id": "cloud_slope", "run_id": 19, "kills": 1}
	_write(s.save_path, data)
	check(s.load_game().loaded and s.realm == 3, "pre-campaign v4 core realm preserved without remap")
	check(s.stage_status().paused and s.stage_status().kills == 1 and s.selected_stage == "cloud_slope", "legacy unlocked partial route remains available at same checkpoint")
	check(s.chapter_rows()[1].unlocked and s.chapter_rows()[2].unlocked, "previously unlocked original routes do not get retroactively locked")
	check(s.chapter_rows()[1].reward_pending and not s.chapter_rows()[0].first_clear_claimed, "legacy clear gains pending retrofit reward without inventing clears or granting on load")
	check(not s.chapter_status().story_resolved and not s.chapter_status().ending_complete and s.inventory.is_empty(), "migration never fabricates story ending or items")
	s.realm = 15
	check(not s.chapter_rows()[3].unlocked, "legacy migration does not bypass NEW chapter prerequisite")
	s.save_game()
	s.load_game()
	check(s.chapter_rows()[2].unlocked and not s.chapter_rows()[3].unlocked, "legacy exception roundtrips narrowly after new save marker")
	data = s._snapshot()
	data.adventure.chapter_reward_claimed = {"bamboo_pass": true, "creek_bridge": "yes", "unknown": true}
	data.adventure.ending_finished_at = 0
	data.adventure.story_resolved_at = 0
	data.adventure.legacy_unlocked_stages.summit_gate = true
	_write(s.save_path, data)
	s.load_game()
	check(s.chapter_reward_claimed.is_empty() and not s.chapter_rows()[5].unlocked and not s.chapter_status().ending_complete, "malformed claims/unlocks/ending cannot manufacture chapter completion")

func _test_authored_opportunities() -> void:
	var expected := [[6, 2, 40.0], [4, 8, 80.0], [14, 6, 180.0], [24, 9, 720.0], [10, 24, 1800.0], [24, 18, 4200.0]]
	var names: Array = []
	var descriptions: Array = []
	var labels: Array = []
	for chapter in range(6):
		var id: String = Content.CHAPTER_ORDER[chapter]
		var s := fresh("_opportunity")
		s.realm = 15
		s.auto_advance = false
		s.pending_opportunity = {"id": "quiet_cairn", "stage_id": id, "run_id": 71}
		var status := s.opportunity_status()
		names.append(status.name)
		descriptions.append(status.description)
		labels.append(String(status.choices[0].name) + String(status.choices[1].name))
		check(status.id == "quiet_cairn" and status.choices.map(func(c): return c.id) == ["gather_gift", "read_inscription"], "stable saved opportunity and choice IDs: " + id)
		check(status.choices[0].rewards.herbs == expected[chapter][0] and status.choices[0].rewards.dew == expected[chapter][1] and status.choices[1].rewards.qi == expected[chapter][2], "authored canonical distinct outcome amounts: " + id)
		var rng := s._adventure_rng.state
		var before := [s.herbs, s.dew, s.merit]
		var result := s.choose_opportunity("gather_gift")
		check(result.ok and s.herbs == before[0] + expected[chapter][0] and s.dew == before[1] + expected[chapter][1] and s.merit == before[2], "stage-specific material branch pays exactly once: " + id)
		check(not s.choose_opportunity("read_inscription").ok and s._adventure_rng.state == rng, "authored choice neither pays alternative nor rolls RNG: " + id)
		s.pending_opportunity = {"id": "quiet_cairn", "stage_id": id, "run_id": 72}
		before = [s.herbs, s.dew, s.merit]
		result = s.choose_opportunity("read_inscription")
		check(result.ok and s.merit == before[2] + expected[chapter][2] and s.qi == 0.0 and s.herbs == before[0] and s.dew == before[1], "insight converts to exact merit at归真: " + id)
		s.pending_opportunity = {"id": "quiet_cairn", "stage_id": id, "run_id": 73}
		s.settings.paused = true
		var data := s._snapshot()
		data.adventure.pending_opportunity.choices = [{"id": "gather_gift", "rewards": {"herbs": State.MAX_RESOURCE}}]
		data.adventure.pending_opportunity.name = "forged"
		_write(s.save_path, data)
		s.load_game()
		check(s.opportunity_status().name == status.name and s.opportunity_status().choices == status.choices, "legacy quiet_cairn load rebuilds route-specific canonical scene and ignores injected reward: " + id)
		s.herbs = State.MAX_RESOURCE
		s.dew = State.MAX_RESOURCE
		s.merit = State.MAX_ENERGY
		check(s.choose_opportunity("gather_gift").reason == "resource_full" and s.choose_opportunity("read_inscription").reason == "resource_full" and not s.pending_opportunity.is_empty(), "both authored options remain pending at their resource caps: " + id)
	check(names.size() == 6 and _unique_count(names) == 6 and _unique_count(descriptions) == 6 and _unique_count(labels) == 6, "all six route scenes and choice label pairs are distinct")

func _unique_count(values: Array) -> int:
	var seen := {}
	for value in values:
		seen[value] = true
	return seen.size()

func _test_no_automatic_adventure() -> void:
	var s := fresh()
	s.auto_advance = true # Explicit quiet path must never start adventure.
	s.step(State.OFFLINE_CAP_SECONDS)
	s.step(7200.0)
	check(s.realm == 15 and s.total_victories == 0 and s.stage_clears.is_empty(), "peaceful sixteen-stage path completes unchanged without any battle")
	check(s.completion_status().complete and not s.chapter_status().story_resolved and not s.chapter_status().epilogue_ready, "peaceful completion is independent from optional adventure ending")
	check(not s.stage_status().active and not s.stage_status().paused and s.inventory.is_empty(), "idle never starts battles or fabricates campaign equipment")

func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _cleanup() -> void:
	for suffix in ["", "_natural", "_retry", "_capacity", "_legacy", "_opportunity"]:
		for extension in [".json", ".json.bak", ".json.tmp"]:
			var path: String = prefix + suffix + extension
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
