extends SceneTree
## Geometry invariants for seated articulation and independent paper-doll slots.
const Meditation = preload("res://scripts/character_meditation.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_test_exact_rest()
	_test_fold_and_breath()
	_test_continuity()
	_test_real_foot_bounds()
	print("Character meditation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _test_exact_rest() -> void:
	var pose := Meditation.sample_pose(0.0, 1.7)
	_check(pose.body_shift == Vector2.ZERO and pose.breath == 0.0, "zero amount is exact resting body")
	for name in ["left","right"]:
		var leg: Dictionary = pose[name]
		for y in range(397,507,3):
			for x in [190.0,220.0,245.0]:
				var p := Vector2(x if name == "left" else 512.0-x,y)
				_check(Meditation.skin_leg_point(p,leg,pose,false).is_equal_approx(p),"zero blend keeps original leg art")
				_check(Meditation.skin_leg_point(p,leg,pose,true).is_equal_approx(p),"zero blend keeps original shoe art")
		for y in range(326,432,3):
			var p := Vector2(204 if name == "left" else 308,y)
			_check(Meditation.skin_arm_point(p,leg,pose).is_equal_approx(p),"zero blend keeps original arm art")
func _test_fold_and_breath() -> void:
	var pose := Meditation.sample_pose(1.0,0.0)
	_check(pose.left.knee.x < pose.left.hip.x - 35.0 and pose.right.knee.x > pose.right.hip.x + 35.0,"thighs turn outward")
	_check(pose.left.ankle.x > pose.left.knee.x + 48.0 and pose.right.ankle.x < pose.right.knee.x - 48.0,"shins fold inward")
	_check(pose.left.ankle.y - pose.left.knee.y < 18.0 and pose.right.ankle.y - pose.right.knee.y < 18.0,"calves rest nearly horizontal")
	_check(pose.left.wrist.distance_to(pose.left.knee)<16.0 and pose.right.wrist.distance_to(pose.right.knee)<16.0,"hands rest above knees")
	var inhale := Meditation.sample_pose(1.0,Meditation.BREATH_PERIOD/4.0)
	var exhale := Meditation.sample_pose(1.0,Meditation.BREATH_PERIOD*3.0/4.0)
	for name in ["left","right"]:
		_check(inhale[name].hip.is_equal_approx(exhale[name].hip),"breath keeps pelvis grounded")
		_check(inhale[name].ankle.is_equal_approx(exhale[name].ankle),"breath keeps tucked feet grounded")
		_check(inhale[name].wrist.is_equal_approx(exhale[name].wrist),"hands remain on resting knees")
		_check(inhale[name].shoulder.y < exhale[name].shoulder.y,"shoulders breathe with spine")
func _test_continuity() -> void:
	for i in range(100):
		var a := float(i)/100.0
		var p0 := Meditation.sample_pose(a,1.0)
		var p1 := Meditation.sample_pose(a+0.01,1.0)
		for name in ["left","right"]:
			for key in ["hip","knee","ankle","shoulder","elbow","wrist"]:
				_check(p0[name][key].distance_to(p1[name][key])<2.0,"sit/stand transitions remain continuous")
			for y in range(399,503,8):
				var p := Vector2(220 if name == "left" else 292,y)
				var skinned := Meditation.skin_leg_point(p,p0[name],p0)
				_check(is_finite(skinned.x) and is_finite(skinned.y),"deeply bent skin stays finite")

func _test_real_foot_bounds() -> void:
	# Use actual opacity, not guessed rectangles, to guard against soles sinking
	# through the ground during the enter/exit arc. 501 source px is 1.3 screen px
	# below the 496 anchor, including painterly outlines on tall boots.
	for key in ["base","feet_cloth","feet_boots"]:
		var texture: Texture2D = load("res://assets/cultivation/equipment/"+key+".png")
		var image := texture.get_image()
		for i in range(21):
			var pose := Meditation.sample_pose(float(i)/20.0,0.0)
			var bottom := 0.0
			for side in [0,1]:
				var leg: Dictionary = pose.left if side==0 else pose.right
				for y in range(452 if key=="base" else 437,501):
					for x in range(192,256):
						var point := Vector2(x if side==0 else 512-x,y)
						if image.get_pixelv(point).a<0.5:
							continue
						bottom = maxf(bottom,Meditation.skin_leg_point(point,leg,pose,key!="base").y)
			_check(bottom <= 501.0,"real bare feet and shoe pixels remain above ground tolerance throughout sit/stand")
