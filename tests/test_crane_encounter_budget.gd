extends SceneTree
## The third chapter trades raw vitality for evasion, rather than weakening
## its attacks or silently boosting a particular hero build. The full lawful
## pacing envelope remains in test_encounter_balance.gd.
const Content = preload("res://scripts/cultivation_content.gd")
const Registry = preload("res://scripts/attack_module_registry.gd")
const Plan = preload("res://tests/campaign_build_plan.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	var cranes: Array = Content.STAGES.cloud_slope.monsters
	var guardian: Dictionary = cranes[2]
	check(cranes.size() == 3 and guardian.id == "cloud_guardian" and guardian.boss, "chapter retains two ordinary cranes and its named boss")
	check(cranes[0].hp == 240 and cranes[1].hp == 245, "ordinary crane vitality is unchanged")
	check(guardian.hp == 450, "agile boss uses its explicit 450-vitality encounter budget")
	check(guardian.hp < Content.STAGES.creek_bridge.monsters[2].hp, "evasive crane has less raw vitality than the preceding stone guardian")
	check(guardian.hp > float(cranes[1].hp) * 1.8, "boss still has substantially more vitality than an ordinary crane")
	check(guardian.attack == 9 and guardian.defense == 2, "boss keeps its existing attack and armor")
	check(guardian.attack_module_id == "enemy.cloud_crane" and guardian.boss_move == "burst", "boss retains its module and opening chain")
	var registry := Registry.new()
	registry.bootstrap()
	var boss = registry.bind(guardian.attack_module_id, {"enemy": guardian})
	var normal = registry.bind(cranes[0].attack_module_id, {"enemy": cranes[0]})
	var stone = registry.bind("enemy.river_stone")
	check(boss.definition().dodge_chance == 0.12 and normal.definition().dodge_chance == 0.12, "ordinary and boss crane retain their 12 percent evasion identity")
	check(boss.definition().dodge_chance > stone.definition().dodge_chance, "agile identity remains distinct from the stone encounter")
	check(boss.definition().guard_chance == 0.06, "no additional hidden crane defense is introduced")
	check(boss.supports_body_contact() and boss.definition().weighted_choice, "real body contact and state-aware weighted choices remain enabled")
	check(not boss.is_awakened(0.1), "vitality reduction does not introduce a new phase or damage buff")
	check(boss.defense_modifier(1) == {"multiplier": 1.08, "mechanic": "crane_landing"}, "existing landing exposure is unchanged")
	var expected := {
		"charge": {"family": "crane_dive", "windup": 0.98, "strike": 0.34, "recovery": 0.78, "hits": [1.76]},
		"sweep": {"family": "crane_sweep", "windup": 0.82, "strike": 0.33, "recovery": 0.66, "hits": [1.42]},
		"burst": {"family": "crane_peck", "windup": 0.76, "strike": 0.18, "recovery": 0.54, "hits": [0.43, 0.47, 0.62]},
	}
	for kind in expected:
		var enemy := guardian.duplicate(true)
		enemy.boss_move = kind
		var action: Dictionary = boss.select_action({"enemy": enemy, "action_index": 0, "charge_reach": 61.0})
		var authored: Dictionary = expected[kind]
		check(action.move_family == authored.family and action.kind == kind, "retains authored family " + kind)
		check(action.hits == authored.hits, "does not reduce attack coefficients " + kind)
		check(action.windup == authored.windup and action.strike == authored.strike and action.recovery == authored.recovery, "retains readable action timing " + kind)
		check(action.strike_geometry.mode == "enemy_body", "retains physical contact authority " + kind)
	for width in [1040.0, 1200.0, 1440.0]:
		var prepared := Plan.prepare_enemy(guardian, "cloud_slope", width)
		check(prepared.hp == 450 and prepared.attack == 9 and prepared.defense == 2, "window preparation cannot scale the vitality budget")
		check(prepared.route_id == "cloud_slope" and prepared.visual_type == "cloud_crane", "preparation keeps accepted route artwork and anatomy")
	print("Crane encounter budget: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
