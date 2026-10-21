extends SceneTree
## Effective-stat timing, exact authority, and independent real-time resources.
const Duel = preload("res://scripts/duel_timeline.gd")
const Timing = preload("res://scripts/combat_timing.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const State = preload("res://scripts/cultivation_state.gd")
const Impact = preload("res://scripts/combat_impact.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_policy_and_loadout()
	_test_phase_ratios_and_intervals()
	_test_exact_fast_contacts()
	_test_cooldowns_pause_and_status()
	_test_partition()
	print("Combat speed: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func make_duel(speed: float = 100.0, enemy_speed: float = 100.0, style: String = "unarmed", active: bool = false) -> Duel:
	var hero := {"hp":100000,"max_hp":100000,"attack":10,"defense":2,"speed":speed,
		"evasion_chance":0.0,"guard_bonus":-1.0,"poise_bonus":10000.0,
		"combat_qi_max":80.0,"combat_qi_regen":0.0,"heart_method":{},"weapon_art":{},"weapon_skill":{},"active_skills":[]}
	if active:
		var spell: Dictionary = Content.TECHNIQUES.ember.duplicate(true)
		spell.id = "ember"
		spell.active = true
		hero.active_skills.append(spell)
	var enemy := {"hp":100000,"max_hp":100000,"attack":1,"defense":1,"boss":true,"route_id":"cloud_slope",
		"speed":enemy_speed,"boss_move":"burst","engagement_distance":100.0,"dodge_chance":0.0,"guard_chance":0.0}
	var d := Duel.new()
	d.start(hero,enemy,"mist",style,377)
	return d

func _test_policy_and_loadout() -> void:
	check(Timing.from_stats({}).speed == 100.0, "missing speed preserves baseline100")
	check(is_equal_approx(Timing.from_stats({"combat_haste":0.08}).rate,1.08), "legacy earned haste maps once")
	check(is_equal_approx(Timing.from_stats({"speed":108.0,"combat_haste":0.08}).rate,1.08), "canonical effective speed never double multiplies legacy haste")
	check(Timing.from_stats({"speed":100.0,"combat_haste":0.35}).rate == 1.0, "explicit effective speed is authoritative")
	for invalid in [NAN,INF,-INF,"fast",null]:
		check(is_equal_approx(Timing.from_stats({"speed":invalid,"combat_haste":0.04}).rate,1.04), "invalid speed safely uses earned legacy fallback")
	for too_fast in [161.0,1.0e20]:
		check(Timing.from_stats({"speed":too_fast}).rate == 1.60, "fast input is bounded at160")
	for too_slow in [0.0,-900.0,64.0]:
		check(Timing.from_stats({"speed":too_slow}).rate == 0.65, "slow input is bounded at65")
	var s := State.new()
	s.realm=1;s.qi=100000;s.herbs=10000;s.dew=10000
	for id in ["qihai","shangyang","hegu"]: check(s.unlock_meridian(id).ok,"real paid speed node " + id)
	check(is_equal_approx(float(s.stats().speed),104.0),"loadout exposes paid +4% as effective speed104")
	check(is_equal_approx(Timing.from_stats(s.stats()).rate,1.04),"real state canonical+legacy fields apply once")
	var cached := make_duel(140.0)
	var before: Dictionary = cached._lanes.hero.action.duplicate(true)
	cached._hero.speed=65.0
	cached._hero.combat_haste=0.35
	cached.pose()
	check(cached._lanes.hero.action == before,"stat mutation and pose sampling do not retime a committed action")
	check(cached._action_timing.hero.rate == 1.4,"loadout speed is cached once at setup")

func _test_phase_ratios_and_intervals() -> void:
	for style in ["unarmed","sword","fan"]:
		var normal := make_duel(100.0,100.0,style)
		var fast := make_duel(140.0,140.0,style)
		var a: Dictionary = normal._lanes.hero.action
		var b: Dictionary = fast._lanes.hero.action
		for key in ["strike","hold","recovery"]:
			check(is_equal_approx(float(a[key])/float(b[key]),1.4),style+" actual "+key+" uses speed140")
		check(float(b.contacts[0].time)<float(a.contacts[0].time),style+" authoritative first contact arrives sooner")
		check(float(b.end)<float(a.end),style+" faster action finishes sooner including physical approach")
		for d in [normal,fast]:
			d.advance(float(d._lanes.enemy.ready_at))
		a=normal._lanes.enemy.action;b=fast._lanes.enemy.action
		for key in ["windup","strike","hold","gap","recovery"]:
			check(is_equal_approx(float(a[key])/float(b[key]),1.4),"monster actual "+key+" uses speed140")
		check(is_equal_approx(float(a.start),float(b.start)),"monster opening AI wait stays real-time")
	for actor in ["hero","enemy"]:
		check(is_equal_approx(Timing.ready_interval(actor,Timing.from_stats({"speed":100.0}))/Timing.ready_interval(actor,Timing.from_stats({"speed":140.0})),1.4),actor+" inter-action interval scales once")
	var normal_heavy: Dictionary = Duel.BASIC_MOVES.basic_unarmed_palm.duplicate(true)
	var fast_heavy: Dictionary = normal_heavy.duplicate(true)
	var fast_light: Dictionary = Duel.BASIC_MOVES.basic_unarmed_jab.duplicate(true)
	Timing.apply(fast_heavy,Timing.from_stats({"speed":140.0}))
	Timing.apply(fast_light,Timing.from_stats({"speed":140.0}))
	for key in Timing.POLICY.phase_keys:
		check(is_equal_approx(float(fast_heavy[key])*1.4,float(normal_heavy[key])),"authored heavy timing scales without rewriting "+key)
	check(fast_heavy.windup>fast_light.windup and fast_heavy.recovery>fast_light.recovery,"fast heavy and light attacks retain their distinct rhythm")

func _test_exact_fast_contacts() -> void:
	var d := make_duel(1000000.0,1000000.0,"sword",true)
	var seen := {}
	var starts := {}
	var last_time := 0.0
	var all_contacts := 0
	var close_combo := false
	for boundary in range(2000):
		if d.elapsed>=25.0 or d.finished: break
		var next := minf(d._next_boundary("hero"),d._next_boundary("enemy"))
		check(next + Duel.EPSILON >= d.elapsed,"fast combo never schedules preparation behind the current clock")
		var before_qi := float(d.battle_resource_snapshot().qi)
		var paid := 0.0
		for event in d.advance(maxf(0.00000001,next-d.elapsed)):
			check(float(event.time)+0.00001>=last_time,"fast event timestamps remain monotonic")
			last_time=float(event.time)
			if event.type=="turn_started":
				starts[event.action_id]=event
				if event.actor=="hero":paid+=float(event.qi_cost)
				var action:Dictionary=d._lanes[event.actor].action
				if action.contacts.size()>1 and float(action.gap)<Duel.DEFENSE_LEAD:close_combo=true
			if event.type=="contact":
				all_contacts+=1
				check(not seen.has(event.contact_id),"one authoritative event per authored contact")
				seen[event.contact_id]=true
				var phase:Dictionary=d._sample_lane(str(event.actor))
				check(phase.name=="contact" and int(phase.index)==int(event.hit_index),"damage is resolved at matching rendered contact phase")
				check(int(event.damage)==int(event.pre_hp)-int(event.post_hp),"fast contact is the only source of its HP delta")
				check(int(event.hit_index)<int(starts[event.action_id].contacts),"speed never invents extra action hits")
		check(is_equal_approx(float(d.battle_resource_snapshot().qi),before_qi-paid),"qi commits once at action start and never at individual contacts")
	check(all_contacts>20 and close_combo,"real clipped-speed encounter exercises fast multi-hit contacts")

func _test_cooldowns_pause_and_status() -> void:
	for speed in [65.0,100.0,140.0,160.0]:
		var d := make_duel(speed,140.0,"unarmed",true)
		var committed := false
		for boundary in range(100):
			var next := minf(d._next_boundary("hero"),d._next_boundary("enemy"))
			for event in d.advance(maxf(0.00000001,next-d.elapsed)):
				if event.type=="turn_started" and event.actor=="hero" and event.action_kind=="spell":
					committed=true
			if committed:break
		check(committed,"real skill commits at speed "+str(speed))
		check(is_equal_approx(float(d.battle_resource_snapshot().cooldowns.ember),7.0),"speed never shortens the authored7s skill cooldown")
		var resources := d.battle_resource_snapshot()
		var phase := d._sample_lane("hero")
		for i in range(5):d.pose()
		d.advance(0.0);d.advance(-1.0);d.advance(NAN)
		check(d.battle_resource_snapshot()==resources and d._sample_lane("hero")==phase,"pause keeps phase and skill cooldown stationary")
		d.apply_slow("hero",3.0,0.22)
		d.apply_slow("enemy",3.0,0.22)
		d.advance(0.25)
		check(is_equal_approx(float(d.battle_resource_snapshot().cooldowns.ember),6.75),"resume consumes actual elapsed time for cooldown")
		check(is_equal_approx(d._hero_slow_until-d.elapsed,2.75) and is_equal_approx(d._enemy_slow_until-d.elapsed,2.75),"speed does not accelerate either debuff duration")
		var event := {"actor":"hero","target":"enemy","move":"basic_unarmed_jab","resolution":"hit","damage":6,"raw_damage":6}
		var baseline := Impact.describe(event)
		event.speed=speed;event.action_rate=speed/100.0
		check(Impact.describe(event).hitstop==baseline.hitstop,"real-time hitstop is independent of action speed")

func compact(events: Array[Dictionary]) -> Array:
	var result := []
	for event in events:
		var row := {}
		for key in ["type","time","actor","move","action_id","contact_id","resolution","damage","qi","qi_cost","hero_hp","enemy_hp"]:
			if event.has(key):row[key]=event[key]
		result.append(row)
	return result

func _test_partition() -> void:
	var coarse := make_duel(160.0,160.0,"sword",true)
	var fine := make_duel(160.0,160.0,"sword",true)
	var all := coarse.advance(20.0)
	var pieces: Array[Dictionary] = []
	for i in range(2000):pieces.append_array(fine.advance(0.01))
	check(compact(all)==compact(pieces),"large delta cannot skip accelerated contacts or duplicate commits")
	check(coarse.hero_hp==fine.hero_hp and coarse.enemy_hp==fine.enemy_hp and coarse.battle_resource_snapshot()==fine.battle_resource_snapshot(),"fast resources/HP are partition deterministic")
