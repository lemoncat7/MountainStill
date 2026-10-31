extends "res://scripts/duel_timeline.gd"
## Frozen scalar contact path for exact batched-path regression tests.
func _measure_enemy_contact(action: Dictionary, current: Dictionary) -> Dictionary:
	var geometry: Dictionary = action.get("strike_geometry",{})
	var reach := float(geometry.get("reach",24.0))
	var result := {"gap": INF, "reach": reach, "contact": false, "point": Vector2.ZERO, "target": Vector2.ZERO, "area": bool(geometry.get("area",false)),
		"spacing_correction": float(current.enemy.get("body_separation", 0.0)), "spacing_reservation": float(current.enemy.get("body_reservation", 0.0))}
	for hero_front in MeleeGeometry.hero_body_fronts(current.hero):
		var front := MeleeGeometry.body_front(current.enemy, _enemy, hero_front.y)
		if not bool(front.valid): continue
		var gap := Vector2(front.point).x - hero_front.x
		if gap < float(result.gap):
			result.merge({"gap": gap, "contact": gap <= reach and gap >= -1.0, "point": hero_front, "target": front.point}, true)
	return result

