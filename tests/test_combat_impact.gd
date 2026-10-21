extends SceneTree
## Deterministic presentation/audio contract. This never modifies duel outcomes.
## Optional --output=/absolute/path writes 21 WAVs, a timed combined-demo.wav
## at actual host gains, and audio-manifest.json. No listening claim is implied.
const Impact = preload("res://scripts/combat_impact.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_contract()
	_test_materials()
	_test_ground_contact()
	_test_audio()
	print("Combat impact: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


static func event(move: String, actor: String = "hero", material: String = "moss_beast") -> Dictionary:
	return {"type": "contact", "actor": actor, "target": "enemy" if actor == "hero" else "hero",
		"move": move, "resolution": "hit", "poise_broken": false, "raw_damage": 12.0,
		"damage": 9, "action_kind": "basic" if actor == "hero" else "enemy",
		"skill_id": "", "basic_style": "sword" if actor == "hero" else "",
		"enemy_visual_type": material, "hero_style": "sword", "action_id": 3,
		"hit_index": 0, "contact_id": "3:0"}


static func examples() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in [
		["sword-on-moss", "basic_sword_cut", "hero", "moss_beast"],
		["sword-on-feather", "basic_sword_cut", "hero", "cloud_crane"],
		["fan-on-moss", "basic_fan_flick", "hero", "moss_beast"],
		["palm-on-body", "basic_unarmed_palm", "hero", "human"],
		["moss-pounce", "moss_beast_sweep", "enemy", "moss_beast"],
		["moss-rush", "moss_beast_charge", "enemy", "moss_beast"],
		["moss-slam", "moss_beast_burst", "enemy", "moss_beast"],
		["crane-peck", "cloud_crane_burst", "enemy", "cloud_crane"],
		["crane-sweep", "cloud_crane_sweep", "enemy", "cloud_crane"],
		["crane-dive", "cloud_crane_charge", "enemy", "cloud_crane"],
		["frost-on-stone", "frost_seal", "hero", "river_stone"],
		["ember-on-feather", "ember_palm", "hero", "cloud_crane"],
		["thunder-on-moss", "thunder_strike", "hero", "moss_beast"],
	]:
		var contact := event(item[1], item[2], item[3])
		if "fan" in item[1]:
			contact.basic_style = "fan"
		elif "unarmed" in item[1]:
			contact.basic_style = "unarmed"
		elif item[1] in ["frost_seal", "ember_palm", "thunder_strike"]:
			contact.action_kind = "spell"
			contact.skill_id = "frost" if item[1] == "frost_seal" else "ember" if item[1] == "ember_palm" else "thunder"
		result.append({"name": item[0], "event": contact})
	for guard in ["metal", "wood", "shield", "air"]:
		var contact := event("moss_beast_charge", "enemy")
		contact.resolution = "guard"
		contact.guard_material = guard
		contact.damage = 2
		result.append({"name": "guard-" + guard, "event": contact})
	var broken := event("thunder_strike")
	broken.poise_broken = true
	broken.skill_id = "thunder"
	broken.action_kind = "spell"
	result.append({"name": "guardbreak-wood", "event": broken})
	var aftershock := event("moss_beast_burst", "enemy")
	aftershock.contact_role = "aftershock"
	result.append({"name": "moss-aftershock", "event": aftershock})
	return result


func _test_contract() -> void:
	var input := event("basic_sword_cut")
	var untouched := input.duplicate(true)
	var light := Impact.describe(input)
	check(input == untouched, "describe never changes source event")
	for key in ["active", "kind", "intensity", "material", "strike_material", "hitstop",
		"reaction_duration", "reaction_magnitude", "knockback", "duration", "direction", "gain_db"]:
		check(light.has(key), "host profile contract: " + key)
	var heavy := Impact.describe(event("moss_beast_burst", "enemy"))
	var guard_event := event("moss_beast_burst", "enemy")
	guard_event.resolution = "guard"
	var guard := Impact.describe(guard_event)
	guard_event.poise_broken = true
	var broken := Impact.describe(guard_event)
	check(light.kind == "light" and heavy.kind == "heavy" and guard.kind == "block" and broken.kind == "guardbreak", "resolution hierarchy has four distinct tactile classes")
	check(light.hitstop < heavy.hitstop and heavy.hitstop < broken.hitstop, "hitstop weight hierarchy")
	check(heavy.hitstop >= 0.055 and broken.hitstop >= 0.085 and broken.hitstop <= 0.100, "large contacts visibly hold 3–6 60Hz frames")
	check(guard.reaction_magnitude < light.reaction_magnitude and light.reaction_magnitude < heavy.reaction_magnitude, "block absorbs, light yields, heavy recoils")
	check(guard.knockback < light.knockback and light.knockback < heavy.knockback and heavy.knockback < broken.knockback, "knockback hierarchy")
	check(broken.reaction_duration > heavy.reaction_duration and heavy.reaction_duration > light.reaction_duration, "settle durations differ")
	check(Impact.reaction(light, float(light.reaction_duration)).amount == 0.0, "reaction ends exactly")
	check(Impact.reaction(light, 0.01).amount > Impact.reaction(light, 0.18).amount, "reaction recovers monotonically")
	for resolution in ["dodge", "whiff", "heal", "support", "shield"]:
		var no_contact := event("mending_bloom")
		no_contact.resolution = resolution
		no_contact.damage = 0
		no_contact.raw_damage = 0
		var profile := Impact.describe(no_contact)
		check(not profile.active and profile.hitstop == 0.0 and Impact.stream(profile) == null, "no fake contact for " + resolution)
	var shielded := event("moss_beast_charge", "enemy")
	shielded.damage = 0
	shielded.shield_absorbed = 12
	var shield := Impact.describe(shielded)
	check(shield.active and shield.kind == "block" and shield.material == "shield", "fully absorbed attack has shield contact")
	var shock_event := event("moss_beast_burst", "enemy")
	shock_event.contact_role = "aftershock"
	var shock := Impact.describe(shock_event)
	check(shock.hitstop < light.hitstop and shock.knockback < light.knockback, "repeated ground aftershock does not chain heavy holds")
	var progression := event("basic_sword_cut")
	progression.damage = 999999
	progression.raw_damage = 999999
	check(Impact.describe(progression).kind == "light", "stat progression preserves authored light identity")
	for item in examples():
		var profile := Impact.describe(item.event)
		check(profile.screen_shake == 0.0 and profile.global_time_scale == 1.0, "background/UI steady: " + str(item.name))
		check(profile.duration <= 0.34 and profile.knockback <= 14.0, "restrained spatial/temporal footprint: " + str(item.name))


func _test_materials() -> void:
	var moss := Impact.describe(event("basic_sword_cut", "hero", "moss_beast"))
	var feather := Impact.describe(event("basic_sword_cut", "hero", "cloud_crane"))
	check(moss.material == "moss" and feather.material == "feather", "target species has physical contact texture")
	check(moss.strike_material == "metal", "weapon and target preserve two separate layers")
	for family in ["moss_rush", "moss_pounce", "moss_slam", "crane_peck", "crane_sweep", "crane_dive"]:
		var contact := event("legacy_name", "enemy")
		contact.move_family = family
		check(Impact.describe(contact).family == family, "explicit family metadata wins over legacy id: " + family)
	var invalid := event("basic_sword_cut")
	invalid.impact_weight = NAN
	invalid.raw_damage = INF
	invalid.impact_direction = Vector2(NAN, INF)
	var safe := Impact.describe(invalid)
	check(is_finite(float(safe.intensity)) and safe.direction.is_finite(), "malformed numeric metadata has finite fallback")


func _test_ground_contact() -> void:
	var slam := Impact.describe(event("moss_beast_burst", "enemy"))
	var shock_event := event("moss_beast_burst", "enemy")
	shock_event.contact_role = "aftershock"
	var shock := Impact.describe(shock_event)
	var heavy_ground := Impact.ground_contact(slam, 0.035)
	var small_ground := Impact.ground_contact(shock, 0.035)
	check(not heavy_ground.is_empty() and not small_ground.is_empty(), "slam and aftershock both mark physical ground contact")
	check(heavy_ground.radius > small_ground.radius and heavy_ground.dust_count > small_ground.dust_count, "aftershock has smaller ground footprint")
	check(heavy_ground.wave_alpha > small_ground.wave_alpha and heavy_ground.compression_alpha > small_ground.compression_alpha, "first stomp carries stronger soil pressure")
	check(Impact.ground_contact(slam, 0.08).compression_alpha == 0.0, "ground compression is brief, not a permanent dark patch")
	check(Impact.ground_contact(slam, 0.28).is_empty() and Impact.ground_contact(shock, 0.19).is_empty(), "ground traces expire promptly")
	check(Impact.ground_contact(Impact.describe(event("moss_beast_charge", "enemy")), 0.03).is_empty(), "rush does not fabricate a ground slam")
	check(Impact.ground_contact(slam, -0.01).is_empty(), "ground contact never appears before impact")
	for resolution in ["dodge", "whiff"]:
		var missed := event("moss_beast_burst", "enemy")
		missed.resolution = resolution
		missed.damage = 0
		check(Impact.ground_contact(Impact.describe(missed), 0.03).is_empty(), "no ground damage flash for " + resolution)
	for i in range(28):
		var sample := Impact.ground_contact(slam, float(i) * 0.01)
		check(sample.radius <= 30.0 and sample.height <= 3.5 and sample.wave_alpha <= 0.40, "stomp ground trace remains shallow, local and restrained")


func _test_audio() -> void:
	var directory := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			directory = arg.trim_prefix("--output=")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var clips: Array[Dictionary] = examples()
	clips.append({"name": "step-earth", "profile": Impact.footstep_profile("earth", 0)})
	clips.append({"name": "step-stone", "profile": Impact.footstep_profile("stone", 1)})
	var manifest: Array[Dictionary] = []
	var mixed := PackedByteArray()
	var hashes: Dictionary = {}
	for item in clips:
		var profile: Dictionary = item.get("profile", Impact.describe(item.get("event", {})))
		var audio := Impact.stream(profile)
		var again := Impact.stream(profile)
		check(audio == again and audio.data == again.data, "cached deterministic stream: " + str(item.name))
		check(audio.mix_rate == 32000 and audio.format == AudioStreamWAV.FORMAT_16_BITS and not audio.stereo, "native bounded PCM: " + str(item.name))
		var peak := 0.0
		var sum := 0.0
		var energy := 0.0
		var count := audio.data.size() / 2
		for i in range(count):
			var sample := float(audio.data.decode_s16(i * 2)) / 32768.0
			peak = maxf(peak, absf(sample))
			energy += sample * sample
			sum += sample
		var rms := sqrt(energy / float(count))
		var dc := sum / float(count)
		check(peak < 0.60 and peak > 0.25, "headroom maintained: " + str(item.name))
		check(absf(dc) < 0.012, "no substantial DC: " + str(item.name))
		check(audio.data.decode_s16(0) == 0 and audio.data.decode_s16(audio.data.size() - 2) == 0, "click-free zero endpoints: " + str(item.name))
		var signature := audio.data.hex_encode().hash()
		check(not hashes.has(signature), "material/strike combination produces distinct sample: " + str(item.name))
		hashes[signature] = true
		var offset := float(mixed.size() / 2) / Impact.SAMPLE_RATE
		var gain := db_to_linear(float(profile.gain_db))
		var entry := {"name": item.name, "kind": profile.kind, "material": profile.material,
			"strike_material": profile.strike_material, "duration": float(count) / Impact.SAMPLE_RATE,
			"peak": peak, "rms": rms, "dc": dc, "gain_db": profile.gain_db, "mixed_peak": peak * gain,
			"offset_seconds": offset, "file": str(item.name) + ".wav"}
		manifest.append(entry)
		if not directory.is_empty():
			check(audio.save_to_wav(directory.path_join(entry.file)) == OK, "save WAV: " + str(item.name))
		var previous_size := mixed.size()
		mixed.resize(previous_size + audio.data.size() + int(Impact.SAMPLE_RATE * 0.24) * 2)
		for i in range(count):
			mixed.encode_s16(previous_size + i * 2, roundi(float(audio.data.decode_s16(i * 2)) * gain))
	var last := Impact.describe(event("basic_sword_cut"))
	var variants: Dictionary = {}
	for index in range(4):
		var contact := event("basic_sword_cut")
		contact.hit_index = index
		contact.contact_id = "variation-" + str(index)
		var profile := Impact.describe(contact)
		variants[profile.sound_key] = true
	check(variants.size() >= 2, "repeated contacts vary pitch/noise without randomness in outcomes")
	if not directory.is_empty():
		var demo := AudioStreamWAV.new()
		demo.mix_rate = Impact.SAMPLE_RATE
		demo.format = AudioStreamWAV.FORMAT_16_BITS
		demo.data = mixed
		check(demo.save_to_wav(directory.path_join("combined-demo.wav")) == OK, "save full audio reel at host mix levels")
		var report := {"engine": Engine.get_version_info().string, "rate": Impact.SAMPLE_RATE,
			"channels": 1, "clips": manifest, "listened": false, "demo": "combined-demo.wav",
			"demo_duration": float(mixed.size() / 2) / Impact.SAMPLE_RATE}
		var file := FileAccess.open(directory.path_join("audio-manifest.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
		print("IMPACT_AUDIO_PROOF: ", directory)
