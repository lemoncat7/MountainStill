extends SceneTree
## godot --headless --path . --script tests/test_character_walk.gd
const Walk = preload("res://scripts/character_walk.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_distance_clock()
	_test_direction_and_idle()
	_test_contacts_and_lengths()
	_test_skin_triangles()
	print("Character walk: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _test_distance_clock() -> void:
	var a := Walk.new()
	var b := Walk.new()
	for i in range(60):a.update_motion(1.0/60.0, 65.0)
	for i in range(120):b.update_motion(1.0/120.0, 65.0)
	_check(is_equal_approx(a.phase, b.phase), "phase is frame-rate invariant")
	var c := Walk.new()
	c.update_motion(1.0, 130.0, 2.0)
	_check(is_equal_approx(a.phase, c.phase), "preview scale preserves stride speed")
	var grip := Walk.attachment_offset(Vector2(318,414),{"facing":1.0,"bob":0.0,"body_tilt":0.0})
	_check(grip.is_equal_approx(Vector2(62,-82)*Walk.PIXEL_SCALE), "weapon uses aligned hand anchor")
	var mirrored := Walk.attachment_offset(Vector2(318,414),{"facing":-1.0,"bob":0.0,"body_tilt":0.0},2.0)
	_check(mirrored.is_equal_approx(grip*Vector2(-2,2)), "weapon mirrors and scales with dressed body")
	var start := a.phase
	a.update_motion(0.0, 65.0)
	_check(is_equal_approx(a.phase, start), "zero time never advances phase")

func _test_direction_and_idle() -> void:
	var walk := Walk.new()
	var right := walk.update_motion(0.3, 65.0)
	_check(right.facing == 1.0 and right.blend == 1.0, "right movement blends in")
	var left := walk.update_motion(0.1, -65.0)
	_check(left.facing == -1.0, "left movement flips entire rig")
	var stopped := walk.update_motion(0.3, 0.0)
	_check(stopped.blend == 0.0 and stopped.phase == 0.0 and stopped.facing == -1.0, "stop settles into stable facing idle")
	var pose := Walk.sample_pose({"phase":0.7,"blend":0.0,"facing":-1.0,"bob":0.0})
	_check(pose.left.knee.is_equal_approx(Walk.KNEE_LEFT) and pose.left.ankle.is_equal_approx(Walk.ANKLE_LEFT), "idle returns exact original silhouette")
	_check(pose.left.foot_angle == 0.0 and pose.right.foot_angle == 0.0, "idle shoes lie flat")

func _test_contacts_and_lengths() -> void:
	for i in range(120):
		var phase := float(i) / 120.0
		var bob := (20.0 + 2.5*sin(phase*TAU*2.0))*Walk.PIXEL_SCALE
		var pose := Walk.sample_pose({"phase":phase,"blend":1.0,"bob":bob})
		_check(pose.left.planted or pose.right.planted, "at least one foot supports body")
		for name in ["left","right"]:
			var leg: Dictionary = pose[name]
			_check(absf(leg.hip.distance_to(leg.knee)-Walk.UPPER_LENGTH)<0.001, "fixed upper-leg length")
			_check(absf(leg.knee.distance_to(leg.ankle)-Walk.LOWER_LENGTH)<0.001, "fixed lower-leg length")
			_check(leg.ankle.y <= 482.01, "feet never go below ground")
			if leg.planted:
				_check(absf(leg.ankle.y-482.0)<0.03 and leg.foot_angle == 0.0, "supporting foot lies flat on ground")
	# During unblended stance, local backward travel cancels measured world travel.
	var p0 := Walk.sample_pose({"phase":0.1,"blend":1.0,"bob":20.0*Walk.PIXEL_SCALE})
	var p1 := Walk.sample_pose({"phase":0.2,"blend":1.0,"bob":20.0*Walk.PIXEL_SCALE})
	var world_delta := Walk.CYCLE_DISTANCE * 0.1
	_check(absf((p1.left.ankle.x-p0.left.ankle.x)*Walk.PIXEL_SCALE+world_delta)<0.001, "planted foot does not skate")
	# Facing mirrors both body travel and the stance correction, including preview scale.
	for direction in [-1.0,1.0]:
		for scale in [1.0,1.8]:
			var foot_delta: float = (p1.left.ankle.x-p0.left.ankle.x)*Walk.PIXEL_SCALE*scale*direction
			_check(absf(foot_delta+world_delta*scale*direction)<0.001, "both directions/scales keep contact planted")
	# All source vertices return exactly to their original shape at rest.
	var rest := Walk.sample_pose({"blend":0.0,"bob":0.0})
	for y in range(399,503,3):
		for x in [210.0,235.0,255.0]:
			var point := Vector2(x,float(y))
			_check(Walk._skin_point(point,rest.left,Vector2.ZERO,false).is_equal_approx(point), "base and trousers retain original idle shape")
			_check(Walk._skin_point(point,rest.left,Vector2.ZERO,true).is_equal_approx(point), "footwear retains original idle shape")
	var lift := Walk.sample_pose({"phase":0.8,"blend":1.0,"bob":20.0*Walk.PIXEL_SCALE})
	_check(lift.left.lift > 21.0 and lift.right.planted, "swing foot visibly lifts while other supports")


func _test_skin_triangles() -> void:
	# Exercise the exact quad-to-triangle path used for bare legs, trousers and
	# both boot heights at all gait phases, both sides and during stop blending.
	for amount in [0.0,0.35,1.0]:
		for i in range(120):
			var phase := float(i)/120.0
			var bob: float = amount*(20.0+2.5*sin(phase*TAU*2.0))*Walk.PIXEL_SCALE
			var pose := Walk.sample_pose({"phase":phase,"blend":amount,"bob":bob})
			for name in ["left","right"]:
				for shoe in [false,true]:
					var x := 180.0 if name == "left" else 256.0
					for y in range(397,506,8):
						var source := PackedVector2Array([Vector2(x,y),Vector2(x+78,y),Vector2(x+78,y+8),Vector2(x,y+8)])
						var vertices := PackedVector2Array()
						var uv := PackedVector2Array()
						for point in source:
							vertices.append(Walk._skin_point(point,pose[name],pose.body_shift,shoe)-Walk.FOOT_ANCHOR)
							uv.append(point/512.0)
						var triangles := Walk._quad_triangles(vertices,uv)
						_check(not triangles.is_empty(), "noncollapsed leg strip has triangles")
						for triangle in triangles:
							_check(Geometry2D.triangulate_polygon(triangle.vertices).size()==3, "skinned triangle always triangulates")
							_check(triangle.vertices.size()==triangle.uv.size(), "triangle UV correspondence preserved")
