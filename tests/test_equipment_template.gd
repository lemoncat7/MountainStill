extends SceneTree
## Canonical clothing socket regression: generated pixels AND live rig contract.
const Template = preload("res://assets/cultivation/sidewalk/template.gd")
const Rig = preload("res://scripts/character_sidewalk.gd")
const ART := "res://assets/cultivation/sidewalk/"
var checks := 0
var failures: Dictionary = {}
var images: Dictionary = {}

func _initialize() -> void:
	_test_generated_assets()
	_test_seam_pixels()
	_test_runtime_contract()
	_test_hand_socket_reference()
	_test_pose_attachment_matrix()
	for label in failures:
		push_error(str(label) + " (%d occurrences)" % int(failures[label]))
	print("Equipment attachment template: %d checks; %d distinct failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures[label] = int(failures.get(label, 0)) + 1

func _source_image(path: String) -> Image:
	# Source fixture deliberately audits PNG bytes, not lossy imported textures.
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	check(error == OK, "PNG source decodes: " + path)
	return image

func _test_generated_assets() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Template.ASSET_ROOT + "manifest.json"))
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "template.json"))
	check(int(spec.version) == Template.VERSION, "template version matches generated runtime constants")
	check(manifest.assets.size() == Template.ASSET_KEYS.size(), "all current base and outfit assets are normalized")
	for key in Template.ASSET_KEYS:
		var image := _source_image(Template.ASSET_ROOT + key + ".png")
		check(image != null and not image.is_empty(), "normalized texture exists: " + key)
		if image == null or image.is_empty(): continue
		images[key] = image
		var record: Dictionary = manifest.assets[key]
		var size: Array = spec.canvases[spec.assets[key]]
		check(image.get_size() == Vector2i(int(size[0]), int(size[1])), "fixed family canvas: " + key)
		check(FileAccess.get_sha256(ART + key + ".png") == str(record.source_sha256), "original source remains unchanged: " + key)
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(image.get_data())
		check(hash.finish().hex_encode() == str(record.rgba_sha256), "normalized pixel payload matches manifest: " + key)
		var imported := FileAccess.get_file_as_string(Template.ASSET_ROOT + key + ".png.import")
		check(imported.contains("mipmaps/generate=true"), "normalized texture retains actor mipmaps: " + key)
	# Base pixels and their original placement are not redrawn by migration.
	var original := _source_image(ART + "arm.png")
	check(images.arm.get_region(Rect2i(32, 0, 155, 396)).get_data() == original.get_data(), "bare arm is a lossless padded copy")
	for key in ["head", "torso", "leg", "feet_cloth", "feet_boots"]:
		check(images[key].get_data() == _source_image(ART + key + ".png").get_data(), "unaffected art is pixel-identical: " + key)
	for key in ["legs_blue", "legs_jade"]:
		check(images[key].get_region(Rect2i(0, 0, 210, 255)).get_data() == _source_image(ART + key + ".png").get_region(Rect2i(0, 0, 210, 255)).get_data(), "trouser waist and knee pixels stay fixed: " + key)

func _test_seam_pixels() -> void:
	for sleeve in ["sleeve_blue", "sleeve_jade"]:
		for pixel in [Vector2i(86, 38), Vector2i(80, 30), Vector2i(92, 45)]:
			check(images[sleeve].get_pixelv(pixel).a > .75, "sleeve covers canonical shoulder cap: " + sleeve)
	var armhole := Vector2i(roundi((-24.0 / Rig.TORSO_WIDTH + 34.0) * 4.0), 176)
	for chest in ["chest_blue", "chest_jade"]:
		check(images[chest].get_pixelv(armhole).a > .75, "chest covers common armhole: " + chest)
		check(images[chest].get_pixel(136, 380).a > .75, "chest reaches common waist: " + chest)
		# Neighboring atlas objects are gone in source pixels, not hidden by a
		# runtime UV clipping branch that would affect future clothes.
		check(images[chest].get_pixel(250, 3).a < .01, "detached collar fragment removed offline: " + chest)
	for trousers in ["legs_blue", "legs_jade"]:
		for shoe in ["feet_cloth", "feet_boots"]:
			for y in [420, 426, 432, 436]:
				var overlap := 0
				for x in range(55, 105):
					if images[trousers].get_pixel(x, y).a > .75 and images[shoe].get_pixel(x, y).a > .75:
						overlap += 1
				check(overlap >= 24, "opaque cuff/shoe overlap: %s + %s at %d" % [trousers, shoe, y])

func _test_runtime_contract() -> void:
	check(Rig.ASSET_ROOT == Template.ASSET_ROOT, "renderer consumes only normalized character art")
	var source := FileAccess.get_file_as_string("res://scripts/character_sidewalk.gd")
	check(not source.contains("source_registration"), "no permanent per-garment registration argument")
	check(not source.contains('112 if chest=='), "no per-chest canvas-height correction")
	check(not source.contains('sleeve=="sleeve_blue"'), "no sleeve-name transform branch")
	check(Template.ARM_ORIGIN == Vector2(86, 38), "padded shoulder source origin is fixed")
	check(Template.LEG_ORIGIN == Vector2(102, 20), "hip source origin is fixed")
	check(Template.HEAD_RECT == Rig.HEAD_RECT, "ornaments share the full head canvas")
	check(Template.HIP_BIND == Rig.HIP and Template.NECK_BIND == Rig.NECK, "anatomical hip and neck unchanged")

func _test_hand_socket_reference() -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "template.json"))
	check(str(spec.weapon.socket_provider) == Template.HAND_SOCKET_PROVIDER, "template references the live rig as painted-fist socket authority")
	check(Template.HAND_SOCKET_PROVIDER == "res://scripts/character_sidewalk.gd", "procedural replacement hand is not the active socket provider")
	check(Template.ARM_WRIST_GRIP == Template.ARM_WRIST, "fixed painted fist and weapon share the anatomical wrist")
	check(spec.weapon.hand_local_socket.size() == 2 and is_zero_approx(float(spec.weapon.hand_local_socket[0])) and is_zero_approx(float(spec.weapon.hand_local_socket[1])), "template declares the original fist's zero local socket")
	for style in ["sword", "fan"]:
		for side in ["near", "far"]:
			for roll in [0.0, PI * .5, PI]:
				for angle in [-1.7, .37, 2.1]:
					var arm := {"hand_angle": angle}
					check(Rig._grip_offset(arm, side, style, roll) == Vector2.ZERO, "original painted fist retains zero socket through wrist rotation and axial roll")
		for facing in [-1.0, 1.0]:
			var motion := {"action_kind": "basic", "attack_style": style, "basic_style": style, "combat_phase": "contact", "phase_progress": .5, "combat_stance": 1.0, "facing": facing}
			var pose := Rig.sample_pose(motion)
			var side: String = str(pose.combat.get("attack_hand", "near"))
			var arm: Dictionary = pose.far_arm if side == "far" else pose.near_arm
			var actual := Rig.weapon_pose(motion, 1.0, 0.0, style, pose)
			var authoritative := motion.duplicate()
			authoritative.contact_authority = true
			var unchanged := Rig.weapon_pose(authoritative, 1.0, 0.0, style, pose)
			var expected := Vector2(arm.wrist) * Rig.PIXEL_SCALE * Vector2(facing * lerpf(.40, 1.0, float(pose.turn)), 1.0)
			check(Vector2(actual.offset).distance_to(expected) < .0001, "visible weapon sits on original painted fist joint")
			check(Vector2(actual.offset).distance_to(unchanged.offset) < .0001, "zero socket adds no visual offset to collision-authority path")

func _test_pose_attachment_matrix() -> void:
	# Equipment IDs never enter the pose sample or skinning call. Repeat the
	# mixed-outfit matrix to lock down that shared interface, in both facings.
	for chest in ["chest_blue", "chest_jade"]:
		for trousers in ["legs_blue", "legs_jade"]:
			for shoe in ["feet_cloth", "feet_boots"]:
				for head in ["head_pin", "head_crown"]:
					var outfit: String = chest + "/" + trousers + "/" + shoe + "/" + head
					for style in ["sword", "fan", "unarmed"]:
						for facing in [-1.0, 1.0]:
							for phase in ["idle", "windup", "strike", "contact", "recovery"]:
								for progress in [0.0, .5, 1.0]:
									var motion := {"action_kind": "basic", "attack_style": style, "basic_style": style,
										"combat_phase": phase, "phase_progress": progress, "combat_stance": 1.0,
										"facing": facing, "defense_action": "guard", "reaction_amount": .6}
									var pose := Rig.sample_pose(motion)
									var socket := Rig.shoulder_surface_point(Template.NEAR_ARMHOLE, pose, true)
									check(socket.distance_to(pose.near_arm.shoulder) < .001, "body and sleeve share live shoulder: " + outfit)
									for side in ["near_arm", "far_arm"]:
										var arm: Dictionary = pose[side]
										check(Rig._skin_arm(Template.ARM_ORIGIN, arm).distance_to(arm.shoulder) < .001, "canonical sleeve root maps to live shoulder")
										check(Rig._skin_arm(Template.ARM_WRIST, arm).distance_to(arm.wrist) < .001, "canonical hand origin stays on anatomical wrist")
									for side in ["near_leg", "far_leg"]:
										var leg: Dictionary = pose[side]
										check(Rig._skin_leg(Template.LEG_ORIGIN, leg).distance_to(leg.hip) < .001, "canonical trouser waist stays on hip")
										check(Rig._skin_leg(Template.LEG_ANKLE, leg).is_finite(), "canonical ankle stays finite through shared deformation")
