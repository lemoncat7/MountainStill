extends SceneTree
## Independent action-lane invariants, earned interrupts and stat effects.
const Duel = preload("res://scripts/duel_timeline.gd")
const Rig = preload("res://scripts/character_sidewalk.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_overlap_and_contacts()
	_test_earned_interrupts()
	_test_earned_counterchains()
	_test_modifier_effects()
	_test_pose_continuity()
	_test_enemy_airborne_continuity()
	_test_partition_and_cancellation()
	print("Continuous duel: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func make_duel(tech: String = "mist", seed_value: int = 377, modifiers: Dictionary = {}, enemy_changes: Dictionary = {}) -> Duel:
	var d := Duel.new()
	var hero := {"hp": 9999, "max_hp": 9999, "attack": 11, "defense": 1}
	hero.merge(modifiers, true)
	var enemy := {"hp": 9999, "max_hp": 9999, "attack": 8, "defense": 1, "boss": true, "route_id": "bamboo_pass", "dodge_chance": 0.0, "guard_chance": 0.0}
	enemy.merge(enemy_changes, true)
	d.start(hero, enemy, tech, "fan" if tech == "petal" else "sword", seed_value)
	return d

func _test_overlap_and_contacts() -> void:
	var d := make_duel()
	d.advance(0.30)
	check(d.pose().hero.combat_phase == "windup" and d.pose().enemy.combat_phase == "windup", "both actors anticipate simultaneously")
	check(d.pose().hero.action_id != d.pose().enemy.action_id, "each lane owns its action identity")
	check(d.pose().hero.phase_progress > d.pose().enemy.phase_progress, "each lane advances its own authored phase")
	var overlapping := 0
	var simultaneous_commitment := 0
	var starts := []
	var actions := {}
	var before_hp := [d.hero_hp, d.enemy_hp]
	for tick in range(2000):
		var events := d.advance(0.01)
		var contacts := 0
		for event in events:
			if event.type == "turn_started":
				starts.append(event)
				actions[event.action_id] = event
			if event.type == "contact":
				contacts += 1
				check(event.damage == event.pre_hp - event.post_hp, "every visible hit exactly matches HP delta")
				if actions.has(event.action_id):
					check(event.time >= actions[event.action_id].time + actions[event.action_id].windup, "damage cannot precede its own windup")
		check(before_hp == [d.hero_hp, d.enemy_hp] or contacts > 0, "HP changes only at an exact contact event")
		before_hp = [d.hero_hp, d.enemy_hp]
		var p := d.pose()
		if p.hero.combat_phase != "idle" and p.enemy.combat_phase != "idle": overlapping += 1
		if p.hero.combat_phase in ["strike", "contact"] and p.enemy.combat_phase in ["strike", "contact"]: simultaneous_commitment += 1
	check(overlapping > 1300, "most fight time contains concurrent actions rather than one-person-one-move waiting")
	check(simultaneous_commitment > 3, "independent commitments sometimes genuinely overlap")
	var repeats := 0
	for index in range(1, starts.size()):
		if starts[index].actor == starts[index - 1].actor: repeats += 1
	check(repeats >= 2, "action starts are not forced to alternate")

func _test_earned_interrupts() -> void:
	var d := make_duel("mist", 377)
	var events := d.advance(60.0)
	var contacts := {}
	var broken_actions := {}
	var breaks := 0
	var cancelled_contacts := 0
	var latest_actions := {}
	for event in events:
		if event.type == "turn_started": latest_actions[event.actor] = event.action_id
		elif event.type == "contact":
			contacts[event.contact_id] = event
			check(not broken_actions.has(event.action_id), "an earned interrupt suppresses all future contacts in the interrupted action")
			if event.resolution == "dodge": check(event.poise_damage == 0.0, "dodged strikes cannot break posture")
		elif event.type == "poise_break":
			breaks += 1
			check(contacts.has(event.contact_id), "interrupt is tied to a real already-resolved contact")
			check(event.pressure >= event.threshold, "interrupt requires accumulated pressure reaching actual threshold")
			check(contacts[event.contact_id].poise_broken, "poise break matches its causal damage event")
			check(contacts[event.contact_id].resolution != "dodge", "a miss never cancels the opponent")
			if event.interrupted:
				broken_actions[latest_actions[event.target]] = true
				cancelled_contacts += 1
	check(breaks > 5 and cancelled_contacts > 3, "sustained pressure produces earned visible stagger opportunities")
	var armored := make_duel("mist", 377, {"poise_bonus": 1000.0})
	check(armored.pose().hero.max_poise > d.pose().hero.max_poise, "poise training increases actual break threshold")

func _test_earned_counterchains() -> void:
	for tech in ["petal", "stillness"]:
		var earned := false
		var count := 0
		for event in make_duel(tech, 17).advance(90.0):
			if event.type == "contact" and event.target == "hero":
				if tech == "petal" and event.resolution == "dodge": earned = true
				if tech == "stillness" and event.resolution == "guard": earned = true
			if event.type == "turn_started" and event.actor == "hero" and event.counter:
				check(earned, "counter start has a preceding real technique defense: " + tech)
				check(event.counter_kind == ("dodge_chase" if tech == "petal" else "deflect_counter"), "counter communicates the actual tactical cause")
				earned = false
				count += 1
		check(count > 2, "defensive technique visibly chains multiple earned responses: " + tech)

	# Offensive forms earn a follow-up from a real posture break instead of
	# borrowing the evasive/guard forms' defensive identity.
	for tech in ["mist", "ember"]:
		var earned := false
		var count := 0
		for event in make_duel(tech, 17).advance(60.0):
			if event.type == "poise_break" and event.actor == "hero" and event.interrupted: earned = true
			if event.type == "turn_started" and event.actor == "hero" and event.counter:
				check(earned and event.counter_kind == "break_followup", "offensive follow-up requires a real successful posture break")
				earned = false
				count += 1
		check(count > 2, "offensive form can exploit an earned opening: " + tech)

func _test_modifier_effects() -> void:
	var basic := make_duel()
	var fast := make_duel("mist", 377, {"combat_haste": 0.08})
	var recovered := make_duel("mist", 377, {"recovery_bonus": 0.08})
	check(fast.pose().windup_duration < basic.pose().windup_duration, "haste shortens actual anticipation clock")
	check(recovered.pose().windup_duration == basic.pose().windup_duration and recovered.pose().turn_duration < basic.pose().turn_duration, "recovery training shortens recovery without falsifying contact")
	var first_basic: Dictionary = basic.advance(0.70).filter(func(e: Dictionary) -> bool: return e.type == "contact" and e.actor == "hero")[0]
	var pressure: Dictionary = make_duel("mist", 377, {"break_bonus": 0.18}).advance(0.70).filter(func(e: Dictionary) -> bool: return e.type == "contact" and e.actor == "hero")[0]
	check(pressure.poise_damage > first_basic.poise_damage and pressure.damage == first_basic.damage, "break training increases real posture damage independently of HP")
	var counter_base := 0.0
	var counter_trained := 0.0
	for event in make_duel("stillness", 17).advance(60.0):
		if event.type == "contact" and event.actor == "hero" and event.counter: counter_base = maxf(counter_base, event.counter_multiplier)
	for event in make_duel("stillness", 17, {"counter_bonus": 0.18}).advance(60.0):
		if event.type == "contact" and event.actor == "hero" and event.counter: counter_trained = maxf(counter_trained, event.counter_multiplier)
	check(counter_trained > counter_base and counter_base > 1.0, "counter training improves only genuinely earned counters")
	for modifier in ["dodge_bonus", "guard_bonus"]:
		var base_count := 0
		var improved_count := 0
		var resolution := "dodge" if modifier == "dodge_bonus" else "guard"
		for seed_value in range(1, 11):
			for event in make_duel("ember", seed_value).advance(30.0):
				if event.type == "contact" and event.target == "hero" and event.resolution == resolution: base_count += 1
			for event in make_duel("ember", seed_value, {modifier: 0.25}).advance(30.0):
				if event.type == "contact" and event.target == "hero" and event.resolution == resolution: improved_count += 1
		check(improved_count > base_count + 10, modifier + " changes actual resolved defense outcomes")

func _test_pose_continuity() -> void:
	for tech in ["mist", "petal", "ember", "stillness"]:
		var d := make_duel(tech, 377)
		var previous := Rig.sample_pose(d.pose().hero)
		var previous_phase := "windup"
		for frame in range(1800):
			d.advance(1.0 / 120.0)
			var motion: Dictionary = d.pose().hero
			var p := Rig.sample_pose(motion)
			check(p.far_leg.planted or p.near_leg.planted, "approach transfers weight with at least one planted sole")
			for key in ["near_arm", "far_arm"]:
				check(absf(Vector2(p[key].shoulder).distance_to(p[key].elbow) - 42.0) < 0.001, "full-body motions keep exact upper arm lengths")
				check(absf(Vector2(p[key].elbow).distance_to(p[key].wrist) - Vector2(10,36).length()) < 0.001, "full-body motions keep exact forearm lengths")
			# Contact recoil can intentionally change velocity abruptly; elsewhere
			# every frame must stay spatially connected, including stagger release.
			if motion.defense_action == "ready" and previous_phase != "stagger" and motion.combat_phase != "stagger":
				check(p.near_arm.wrist.distance_to(previous.near_arm.wrist) * Rig.PIXEL_SCALE < 5.0, "active grip has no unmotivated pose pop")
			previous = p
			previous_phase = motion.combat_phase

func _test_enemy_airborne_continuity() -> void:
	for route in ["cloud_slope", "moon_marsh"]:
		var d := make_duel("mist", 377, {"attack": 1}, {"route_id": route, "boss_move": "burst"})
		var starts := d.advance(0.18).filter(func(e: Dictionary) -> bool: return e.type == "turn_started" and e.actor == "enemy")
		var anticipation: float = starts[0].windup
		d.advance(anticipation - 0.001)
		var before: Vector2 = d.pose().enemy.visual_offset
		d.advance(0.002)
		var after: Vector2 = d.pose().enemy.visual_offset
		check(before.distance_to(after) < 1.0, "airborne tell joins strike without snapping to the ground: " + route)
		var previous := after
		for frame in range(180):
			d.advance(1.0 / 240.0)
			var p := d.pose()
			var current: Vector2 = p.enemy.visual_offset
			check(absf(current.y - previous.y) < 2.0, "multi-contact flight remains vertically continuous: " + route)
			previous = current

func _test_partition_and_cancellation() -> void:
	for tech in ["mist", "petal", "ember", "stillness"]:
		var small := make_duel(tech, 81, {"combat_haste": 0.08, "poise_bonus": 10.0, "break_bonus": 0.18})
		var large := make_duel(tech, 81, {"combat_haste": 0.08, "poise_bonus": 10.0, "break_bonus": 0.18})
		var events: Array[Dictionary] = []
		for tick in range(1000): events.append_array(small.advance(0.02))
		check(events == large.advance(20.0), "all lane/interruption/counter events invariant to timestep partition: " + tech)
		var paused := small.pose()
		for tick in range(10): check(small.pose() == paused, "pose reads never advance an independent lane")
		small.cancel()
		var hp := [small.hero_hp, small.enemy_hp]
		var cancelled := small.advance(100.0)
		check(cancelled.size() == 1 and cancelled[0].type == "cancelled" and hp == [small.hero_hp, small.enemy_hp], "cancel drains both lanes without contact or reward")
