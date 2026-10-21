extends RefCounted
## Authored creature choreography. All samples are pure and retain fixed anatomy.
## Legacy charge/sweep/burst IDs remain the save/UI contract; families describe
## actual bodywork, contact rhythm, preferred range and the committed budget.
const FAMILIES := {
	"moss_beast": {"charge": "moss_rush", "sweep": "moss_pounce", "burst": "moss_slam"},
	"cloud_crane": {"charge": "crane_dive", "sweep": "crane_sweep", "burst": "crane_peck"},
}
const COSTS := {"moss_rush": 38.0, "moss_pounce": 12.0, "moss_slam": 32.0,
	"crane_dive": 38.0, "crane_sweep": 25.0, "crane_peck": 14.0}

static func family(species: String, kind: String) -> String:
	return str(FAMILIES.get(species, {}).get(kind, species + "_" + kind))

static func cost(species: String, kind: String) -> float:
	return float(COSTS.get(family(species, kind), {"charge": 34.0, "sweep": 17.0, "burst": 28.0}.get(kind, 20.0)))

static func choice_weights(species: String, state: Dictionary) -> Dictionary:
	var gap := float(state.get("distance", 50.0))
	var stamina := float(state.get("stamina", 100.0))
	var history: Array = state.get("history", [])
	var weights := {"charge": 1.0, "sweep": 1.0, "burst": 1.0}
	if species == "moss_beast":
		weights.charge = 0.50 + clampf(gap / 55.0, 0.0, 2.2)
		weights.sweep = 1.55 if gap < 55.0 else 0.70
		weights.burst = 1.60 if gap < 34.0 else 0.65
	elif species == "cloud_crane":
		weights.charge = 0.45 + clampf(gap / 60.0, 0.0, 2.0)
		weights.sweep = 1.55 if str(state.get("hero_phase", "")) in ["strike", "contact"] else 0.85
		weights.burst = 1.65 if gap < 52.0 else 0.80
	else:
		weights.charge += clampf(gap / 90.0, 0.0, 1.2)
	if str(state.get("hero_phase", "")) == "recovery":
		weights.charge *= 1.32
	if float(state.get("hp_fraction", 1.0)) < 0.35:
		weights.sweep *= 1.30
	# A genuine evade invites a chase, but does not force a rotation.
	if bool(state.get("chase", false)):
		weights.charge *= 1.75
	for kind in weights:
		if cost(species, kind) > stamina:
			weights[kind] *= 0.035
		elif cost(species, kind) > stamina * 0.75:
			weights[kind] *= 0.42
		if not history.is_empty() and str(history[-1]) == kind:
			weights[kind] = 0.0
		elif history.size() >= 2 and str(history[-2]) == kind:
			weights[kind] *= 0.42
	return weights

static func choose(weights: Dictionary, roll: float) -> String:
	var total := 0.0
	for value in weights.values(): total += float(value)
	var cursor := clampf(roll, 0.0, 0.999999) * total
	for kind in ["charge", "sweep", "burst"]:
		cursor -= float(weights.get(kind, 0.0))
		if cursor < 0.0: return kind
	return "sweep"

static func authored(species: String, kind: String, boss: bool, reach: float) -> Dictionary:
	var f := family(species, kind)
	var result: Dictionary = {}
	match f:
		"moss_pounce":
			result = {"label": "后足扣地 · 短扑", "windup": 0.57 if boss else 0.46, "strike": 0.26, "hold": 0.11, "recovery": 0.52,
				"hits": [1.28 if boss else 0.93], "gap": 0.0, "lunge": minf(reach, 37.0), "monster_range": 48.0, "impact_weight": 0.80, "impact_direction": Vector2(-1.0, 0.2)}
		"moss_rush":
			result = {"label": "伏角刨土 · 蓄力冲撞", "windup": 0.91 if boss else 0.62, "strike": 0.25, "hold": 0.15, "recovery": 0.70,
				"hits": [1.76 if boss else 1.12], "gap": 0.0, "lunge": reach, "monster_range": 108.0, "impact_weight": 1.30, "impact_direction": Vector2(-1.0, -0.08)}
		"moss_slam":
			result = {"label": "前掌高举 · 震地重砸", "windup": 0.94 if boss else 0.78, "strike": 0.28, "hold": 0.12, "recovery": 0.78,
				"hits": [1.12, 0.30, 0.38] if boss else [1.22], "gap": 0.30, "lunge": minf(reach, 12.0), "monster_range": 65.0, "impact_weight": 1.50, "impact_direction": Vector2(-0.25, 1.0)}
		"crane_peck":
			result = {"label": "曲颈定睛 · 连环啄", "windup": 0.76 if boss else 0.52, "strike": 0.18, "hold": 0.07, "recovery": 0.54,
				"hits": [0.43, 0.47, 0.62] if boss else [0.53, 0.64], "gap": 0.24, "lunge": minf(reach, 20.0), "monster_range": 50.0, "impact_weight": 0.58, "impact_direction": Vector2(-1.0, 0.12)}
		"crane_sweep":
			result = {"label": "单足拧身 · 展翼横扫", "windup": 0.82 if boss else 0.63, "strike": 0.33, "hold": 0.15, "recovery": 0.66,
				"hits": [1.42 if boss else 1.02], "gap": 0.0, "lunge": minf(reach, 14.0), "monster_range": 72.0, "impact_weight": 1.05, "impact_direction": Vector2(-1.0, -0.35)}
		"crane_dive":
			result = {"label": "展翅腾空 · 折翼俯冲", "windup": 0.98 if boss else 0.79, "strike": 0.34, "hold": 0.14, "recovery": 0.78,
				"hits": [1.76 if boss else 1.16], "gap": 0.0, "lunge": reach, "monster_range": 112.0, "impact_weight": 1.32, "impact_direction": Vector2(-0.65, 0.76)}
	if not result.is_empty():
		result.move_family = f
		result.stamina_cost = cost(species, kind)
	return result

static func neutral_pose() -> Dictionary:
	return {"head_pitch": 0.0, "head_thrust": 0.0, "body_pitch": 0.0, "crouch": 0.0,
		"foreleg_lift": 0.0, "hindleg_drive": 0.0, "wing_open": 0.0, "wing_sweep": 0.0,
		"neck_fold": 0.0, "beak_thrust": 0.0, "foot_lift": 0.0, "tail_lift": 0.0,
		"impact": 0.0, "windup": 0.0, "step_cycle": 0.0, "recovery": 0.0}

static func _blend(from: Dictionary, to: Dictionary, t: float) -> Dictionary:
	var result := neutral_pose()
	for key in result: result[key] = lerpf(float(from.get(key, 0.0)), float(to.get(key, 0.0)), t)
	return result

static func sample(action: Dictionary, phase: Dictionary, clock: float) -> Dictionary:
	var f := str(action.get("move_family", ""))
	var name := str(phase.name)
	var p := clampf(float(phase.progress), 0.0, 1.0)
	var i := int(phase.index)
	var wind := neutral_pose()
	var hit := neutral_pose()
	var root_wind := Vector2.ZERO
	var root_hit := Vector2.ZERO
	match f:
		"moss_pounce":
			wind.merge({"crouch": 0.85, "head_pitch": 0.10, "hindleg_drive": -0.65, "tail_lift": 0.25}, true)
			hit.merge({"head_thrust": 0.65, "foreleg_lift": 0.28, "hindleg_drive": 0.85, "body_pitch": -0.04}, true)
			root_wind = Vector2(4.0, 0.0)
		"moss_rush":
			wind.merge({"crouch": 0.55, "head_pitch": 0.30, "head_thrust": -0.30, "foreleg_lift": 0.18, "tail_lift": 0.65}, true)
			hit.merge({"head_thrust": 0.92, "head_pitch": 0.18, "hindleg_drive": 0.65, "tail_lift": 0.80}, true)
			root_wind = Vector2(7.0, 0.0)
		"moss_slam":
			wind.merge({"body_pitch": 0.14, "foreleg_lift": 1.0, "head_pitch": -0.28, "head_thrust": -0.10, "tail_lift": 0.22}, true)
			hit.merge({"crouch": 0.70, "head_pitch": 0.18, "head_thrust": 0.30, "hindleg_drive": 0.24}, true)
		"crane_peck":
			wind.merge({"neck_fold": 0.85, "head_pitch": -0.20, "wing_open": 0.16, "foot_lift": 0.12}, true)
			hit.merge({"beak_thrust": 1.0, "head_thrust": 0.65, "head_pitch": 0.22, "wing_open": 0.24, "tail_lift": 0.35}, true)
			root_wind = Vector2(3.0, -4.0); root_hit = Vector2(0.0, -4.0)
		"crane_sweep":
			wind.merge({"wing_open": 0.88, "wing_sweep": -0.75, "neck_fold": 0.35, "foot_lift": 0.22, "body_pitch": 0.06}, true)
			hit.merge({"wing_open": 1.0, "wing_sweep": 1.0, "head_thrust": 0.25, "tail_lift": 0.50, "body_pitch": -0.06}, true)
			root_wind = Vector2(2.0, -3.0); root_hit = Vector2(0.0, -3.0)
		"crane_dive":
			wind.merge({"wing_open": 1.0, "wing_sweep": -0.20, "neck_fold": 0.55, "foot_lift": 1.0, "tail_lift": 0.50, "body_pitch": -0.12}, true)
			hit.merge({"wing_open": 0.16, "wing_sweep": 0.75, "head_pitch": 0.48, "beak_thrust": 0.85, "head_thrust": 0.60, "foot_lift": 0.25, "body_pitch": 0.12}, true)
			root_wind = Vector2(6.0, -34.0); root_hit = Vector2(0.0, -3.0)
	var pose := neutral_pose()
	var root := Vector2.ZERO
	var eased := smoothstep(0.0, 1.0, p)
	if name == "windup":
		pose = _blend(neutral_pose(), wind, eased)
		root = Vector2.ZERO.lerp(root_wind, eased)
		pose.windup = eased
	elif name == "strike":
		if i == 0:
			pose = _blend(wind, hit, eased)
			root = root_wind.lerp(root_hit, eased)
		else:
			# Between chain pecks the neck visibly folds back then fires again.
			# Slam echoes leave the paws grounded; they do not fake extra jumps.
			var recoil := sin(p * PI)
			pose = _blend(hit, wind, recoil * (0.90 if f == "crane_peck" else 0.14))
			root = root_hit
		if f == "moss_pounce": root.y -= sin(p * PI) * 19.0
		if f == "crane_dive": root.y -= sin(p * PI) * 5.0
		pose.impact = eased if i == 0 else 1.0 - sin(p * PI)
	elif name == "contact":
		pose = hit.duplicate()
		root = root_hit
		pose.impact = 1.0
	elif name == "recovery":
		pose = _blend(hit, neutral_pose(), eased)
		root = root_hit.lerp(Vector2.ZERO, eased)
		pose.recovery = eased
		pose.impact = 1.0 - eased
		# Recovery has its own locomotion. The pounce and dive spring into a
		# low backward bound; rooted heavy moves deliberately replace their
		# weight in two short backsteps rather than sliding planted paws.
		if f in ["moss_pounce", "crane_dive"]:
			var rebound := sin(p * PI)
			root.y -= rebound * (8.0 if f == "moss_pounce" else 10.0)
			pose.foreleg_lift += rebound * 0.35
			pose.hindleg_drive -= rebound * 0.30
			pose.foot_lift += rebound * 0.42
			pose.wing_open += rebound * (0.25 if f == "crane_dive" else 0.0)
		elif f in ["moss_rush", "moss_slam"]:
			pose.step_cycle = -sin(p * TAU * 2.0) * (0.70 if f == "moss_rush" else 0.34) * sin(p * PI)
			pose.hindleg_drive = -0.55 * sin(p * PI)
		elif f in ["crane_peck", "crane_sweep"]:
			root.y -= sin(p * PI) * 4.0
			pose.foot_lift += sin(p * PI) * 0.28
			pose.step_cycle = -sin(p * TAU) * 0.35
	# Each rush includes visible paw alternation while remaining grounded.
	if f == "moss_rush" and name in ["windup", "strike"]:
		var t := maxf(0.0, clock - float(action.start))
		var cycle := t * 13.0 + maxf(0.0, t - float(action.windup)) * 9.0
		var amplitude := 0.30 * (1.0 - smoothstep(0.75, 1.0, p)) + sin(p * PI) * 0.50 if name == "strike" else smoothstep(0.25, 0.85, p) * 0.30
		pose.step_cycle = sin(cycle) * amplitude
	return {"monster_pose": pose, "root_offset": root, "move_family": f}
