extends SceneTree
## Native visual proof, isolated from player saves and rewards.
## godot --path . --resolution 1200x640 --script tests/show_technique_duels.gd
## Pass --resolution before movie capture starts; root resize is later than writer initialization.
## TECHNIQUE_DUELS_LIVE=1 keeps the completed comparison on screen.
## TECHNIQUE_DUELS_SECONDS=18 changes the duration; space pauses all timelines.
const Walk = preload("res://scripts/character_sidewalk.gd")
const Duel = preload("res://scripts/duel_timeline.gd")

class DuelProof extends Node2D:
	const SERIF = preload("res://assets/fonts/MaShanZheng-Regular.ttf")
	const LATIN = preload("res://assets/fonts/DejaVuSans.ttf")
	const PROFILE_IDS := ["mist", "petal", "ember", "stillness"]
	const TITLES := ["云岚剑诀", "落英身法", "照炉心法", "止水内功"]
	const SUBTITLES := ["直刺 / 挑锋 / 三叠", "游身 / 真闪避 / 回锋", "聚火 / 火掌 / 双炎息", "沉息 / 真格挡 / 推掌"]
	const COLORS := [Color("63838c"), Color("9e7a8c"), Color("bf784c"), Color("6f8669")]
	const EQUIPMENT := ["sword", "fan", "sword", "sword"]
	var rigs: Array = []
	var duels: Array = []
	var records: Array[Dictionary] = []
	var background: Texture2D
	var sword: Texture2D
	var fan: Texture2D
	var beast: Dictionary = {}
	var clock := 0.0
	var duration := 18.0
	var paused := false
	var complete := false
	var saved: Dictionary = {}
	var completed_emitted := false

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		background = load("res://assets/cultivation/routes/bamboo_pass.png")
		sword = Walk.filtered_weapon(load("res://assets/cultivation/avatars/sword.png"))
		fan = Walk.filtered_weapon(load("res://assets/cultivation/avatars/fan.png"))
		for key in ["idle", "windup", "attack"]:
			beast[key] = load("res://assets/cultivation/beasts/bamboo_pass_boss_" + key + ".png")
		var requested := OS.get_environment("TECHNIQUE_DUELS_SECONDS")
		if not requested.is_empty():
			duration = clampf(requested.to_float(), 1.0, 120.0)
		for index in range(4):
			rigs.append(Walk.new())
			var sim := Duel.new()
			sim.start({"hp": 100, "attack": 11, "defense": 1, "technique_level": 1},
				{"id": "proof_moss_king", "name": "同一青苔兽王", "hp": 400, "attack": 8, "defense": 1,
				"visual_type": "moss_beast", "boss": true, "boss_move": "charge", "dodge_chance": 0.025, "guard_chance": 0.06,
				"engagement_distance": 128.0, "enemy_front_extent": 42.0},
				PROFILE_IDS[index], EQUIPMENT[index], 377)
			duels.append(sim)
			records.append({"last": "尚未接触", "previous": "", "age": 10.0, "damage": 0, "dodges": 0, "guards": 0, "hits": 0, "target": "", "resolution": "", "event": {}})
		print("TECHNIQUE_PROOF_START: same moss boss 400 HP / 8 attack / 1 defense; hero 100 HP / 11 effective attack / 1 defense; seed 377; profiles differ by real mechanics.")

	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE:
				paused = not paused
			elif event.keycode == KEY_ESCAPE:
				get_tree().quit()

	func _process(delta: float) -> void:
		if not paused and not complete:
			var step := minf(delta, duration - clock)
			clock += step
			for index in range(4):
				records[index].age += step
				for event in duels[index].advance(step):
					if event.type == "contact":
						_contact(index, event)
			if clock >= duration:
				complete = true
				print("TECHNIQUE_PROOF_COMPLETE: %.3f seconds" % clock)
				for index in range(4):
					print("  %s hero=%d enemy=%d dealt=%d dodges=%d guards=%d" % [PROFILE_IDS[index], duels[index].hero_hp, duels[index].enemy_hp, records[index].damage, records[index].dodges, records[index].guards])
		queue_redraw()
		if DisplayServer.get_name() != "headless":
			for at in [2.75, 7.30, 12.50, 17.8]:
				if clock >= at and not saved.has(at):
					saved[at] = true
					_capture.call_deferred("Technique-Duels-%02d.png" % int(at))
		if complete and not completed_emitted:
			completed_emitted = true
			_finish.call_deferred()

	func _contact(index: int, event: Dictionary) -> void:
		var r: Dictionary = records[index]
		var name := "修士" if event.target == "hero" else "兽王"
		var outcome := "命中"
		if event.resolution == "dodge":
			outcome = "闪避"
		elif event.resolution == "guard":
			outcome = "格挡"
		r.previous = r.last
		r.last = "%s%s  %d → %d" % [name, outcome, event.pre_hp, event.post_hp]
		r.event = event.duplicate(true)
		r.age = 0.0
		r.target = event.target
		r.resolution = event.resolution
		if event.actor == "hero":
			r.damage += event.damage
		else:
			if event.resolution == "dodge": r.dodges += 1
			elif event.resolution == "guard": r.guards += 1
			else: r.hits += 1
		print("TECHNIQUE_CONTACT %s %.2f %s %s damage=%d HP=%d->%d id=%s" % [PROFILE_IDS[index], event.time, event.actor, event.resolution, event.damage, event.pre_hp, event.post_hp, event.contact_id])

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1200, 640), Color("eee8db"))
		_text("同场试招 · 四门功法", Vector2(28, 37), 28, Color("34574c"))
		_text("同一兽王 / 同等攻防 / 同一种子 · 动作与血量共用真实战斗时钟", Vector2(30, 66), 16, Color("6e7969"))
		_text("%.1f / %.0f s%s" % [clock, duration, "   暂停" if paused else ""], Vector2(1004, 43), 16, Color("56685a"), LATIN)
		for index in range(4):
			_draw_column(index)
		_text("受伤只在接触时结算 · 闪避为零伤害 · 格挡有实际减伤 · 空格暂停 / Esc 退出", Vector2(30, 620), 16, Color("697362"))

	func _draw_column(index: int) -> void:
		var left := 18.0 + index * 296.0
		var color: Color = COLORS[index]
		var panel := Rect2(left, 88, 280, 510)
		draw_style_box(_paper(), panel)
		draw_rect(Rect2(left + 13, 101, 4, 38), color)
		_text(TITLES[index], Vector2(left + 27, 122), 24, color)
		_text(SUBTITLES[index], Vector2(left + 17, 151), 15, Color("756f5e"))
		var scenery := Rect2(left + 1, 166, 278, 236)
		if background:
			draw_texture_rect_region(background, scenery, Rect2(120 + index * 18, 0, 330, 280), Color(1, 1, 1, 0.56))
		draw_rect(scenery, Color(0.96, 0.94, 0.86, 0.18))
		var p: Dictionary = duels[index].pose()
		var motion: Dictionary = {"phase": 0.0, "blend": 0.0, "facing": 1.0, "turn": 1.0}
		motion.merge(p.hero, true)
		var hero := Vector2(left + 63, 380)
		var enemy := Vector2(left + 191, 380)
		if p.actor == "enemy": enemy.x -= float(p.actor_lunge)
		var reaction: Dictionary = p.enemy
		if reaction.defense_action == "dodge": enemy.x += 24.0 * float(reaction.reaction_amount)
		elif reaction.defense_action == "hit": enemy.x += 5.0 * float(reaction.reaction_amount)
		_shadow(hero, Vector2(24, 4))
		_shadow(enemy, Vector2(43, 6))
		var palms: bool = PROFILE_IDS[index] in ["ember", "stillness"]
		var weapon_pose: Dictionary = Walk.weapon_pose(motion, 1.13, 0.0, EQUIPMENT[index])
		if bool(weapon_pose.draw_behind):
			# Same stowed transform as the live rig, never a sword in the fire palm.
			_draw_equipped(hero + Vector2(weapon_pose.offset), EQUIPMENT[index], float(weapon_pose.rotation), 1.13)
		var visual := {"head": "head_pin", "chest": "chest_blue", "legs": "legs_jade", "feet": "feet_boots"}
		rigs[index].draw_avatar_layers(self, hero, {}, visual, motion, 1.13)
		var hand := hero + Walk.attachment_offset(Vector2.ZERO, motion, 1.13)
		if not bool(weapon_pose.draw_behind):
			_draw_equipped(hero + Vector2(weapon_pose.offset), EQUIPMENT[index], (0.22 if EQUIPMENT[index] == "sword" else 0.0) + float(weapon_pose.rotation), 1.13)
		var beast_pose := "idle"
		if p.actor == "enemy":
			if p.phase == "windup" or ("burst" in str(p.move) and p.phase in ["strike", "contact"]): beast_pose = "windup"
			elif p.phase in ["strike", "contact"]: beast_pose = "attack"
		var texture: Texture2D = beast[beast_pose]
		var beast_size := 122.0
		draw_texture_rect(texture, Rect2(enemy + Vector2(-beast_size * 0.5, -beast_size * 232.0 / 256.0), Vector2.ONE * beast_size), false)
		_draw_effects(index, p, hand, hero, enemy)
		_text("剑归鞘 · 双掌施法" if palms else ("持剑 · 随招换锋" if index == 0 else "持扇 · 闪身回击"), Vector2(left + 17, 189), 14, color)
		_draw_health(Rect2(left + 16, 414, 112, 5), duels[index].hero_hp, 100, Color("6e9071"))
		_draw_health(Rect2(left + 151, 414, 112, 5), duels[index].enemy_hp, 400, Color("ac785c"))
		_text("修士 %d/100" % duels[index].hero_hp, Vector2(left + 16, 437), 14, Color("4e6656"))
		_text("兽王 %d/400" % duels[index].enemy_hp, Vector2(left + 150, 437), 14, Color("866348"))
		_draw_phase_strip(left, p, color)
		_text(str(p.telegraph), Vector2(left + 15, 496), 13, Color("675a48"))
		var r: Dictionary = records[index]
		_text(str(r.last), Vector2(left + 15, 524), 16, color)
		if not r.event.is_empty():
			var e: Dictionary = r.event
			var arithmetic := "实际伤害 %d" % e.damage
			if e.resolution == "guard": arithmetic = "格挡减伤 %d → %d" % [e.unguarded_damage, e.damage]
			elif e.resolution == "dodge": arithmetic = "闪避成功 · 实际伤害 0"
			_text(arithmetic, Vector2(left + 15, 546), 14, Color("776f5a"))
		_text("伤害 %d · 闪 %d · 挡 %d" % [r.damage, r.dodges, r.guards], Vector2(left + 15, 580), 15, Color("5f7361"))

	func _draw_phase_strip(left: float, p: Dictionary, color: Color) -> void:
		var names := ["windup", "strike", "contact", "recovery"]
		var titles := ["蓄势", "出招", "接触", "收势"]
		for j in range(4):
			var rect := Rect2(left + 15 + j * 63, 450, 59, 24)
			var selected: bool = str(p.phase) == names[j]
			draw_rect(rect, Color(color, 0.14 if selected else 0.035))
			if selected:
				draw_rect(Rect2(rect.position + Vector2(0, 22), Vector2(rect.size.x * float(p.phase_progress), 2)), color)
			_text(titles[j], rect.position + Vector2(10, 17), 14, color if selected else Color("b1ac9c"))

	func _draw_effects(index: int, p: Dictionary, hand: Vector2, hero: Vector2, enemy: Vector2) -> void:
		var move := str(p.move)
		var phase := str(p.phase)
		var progress := float(p.phase_progress)
		var target := enemy + Vector2(-33, -55)
		# Ranged palm effects keep their committed aim when the enemy evades.
		# They must not visually chase a successful zero-damage dodge.
		if str(p.enemy.defense_action) == "dodge":
			target.x -= 24.0 * float(p.enemy.reaction_amount)
		if p.actor == "hero":
			if move.begins_with("ember"):
				var strength := progress if phase == "windup" else (1.0 - progress if phase == "recovery" else 1.0)
				if phase in ["windup", "strike", "contact", "recovery"]:
					for j in range(5):
						var angle := j * TAU / 5.0 + clock * 2.4
						draw_circle(hand + Vector2(cos(angle), sin(angle)) * (5 + strength * 7), 1.7 + strength, Color(0.87, 0.45, 0.19, strength * 0.7))
				if phase in ["strike", "contact"]:
					var point := hand.lerp(target, progress if phase == "strike" else 1.0)
					for j in range(3): draw_arc(point, 7 + j * 5, -1.2, 1.2, 20, Color(0.91, 0.50, 0.21, 0.72 - j * 0.16), 2.0, true)
			elif move.begins_with("stillness") and phase in ["strike", "contact"]:
				for j in range(3):
					draw_arc(hand + Vector2(progress * 35 - j * 6, 0), 10 + j * 4, -1.3, 1.3, 20, Color(0.44, 0.64, 0.50, 0.65 - j * 0.15), 1.5, true)
			elif move.begins_with("mist") and phase in ["strike", "contact"]:
				var angle := 0.22 + Walk.attachment_rotation(p.hero)
				var tip := hand + Vector2(0, -60).rotated(angle)
				draw_line(hand, tip, Color(0.71, 0.86, 0.88, 0.7), 2.2, true)
				if move != "mist_thrust": draw_arc(hand, 55, angle - PI * 0.65, angle - PI * 0.40, 20, Color(0.68, 0.81, 0.86, 0.5), 2.0, true)
			elif move.begins_with("petal") and phase in ["strike", "contact"]:
				for j in range(4):
					var point := hand + Vector2(progress * 31 + j * 6, sin(j * 2.3) * 9)
					draw_circle(point, 2.2, Color(0.74, 0.50, 0.60, 0.65))
		elif phase == "windup":
			var danger := Color(0.69, 0.41, 0.27, 0.2 + progress * 0.55)
			if "charge" in move:
				for j in range(3): draw_line(enemy + Vector2(-28 - j * 19, 1), enemy + Vector2(-38 - j * 19, 5), danger, 2.0, true)
			elif "sweep" in move:
				draw_arc(enemy + Vector2(-15, -8), 48, PI * 0.55, PI * 1.45, 22, danger, 1.8, true)
			else:
				for j in range(6): draw_circle(enemy + Vector2(cos(j * TAU / 6 + progress) * 20, sin(j * TAU / 6 + progress) * 12 - 52), 2.0, danger)
		elif phase in ["strike", "contact"]:
			# Enemy attacks visibly traverse the remaining distance on the same
			# strike/contact clock as HP. A dodge leaves the committed aim behind.
			var flight := smoothstep(0.0, 1.0, progress) if phase == "strike" else 1.0
			var fade := 0.78 if phase == "strike" else 0.78 * (1.0 - progress * 0.65)
			var impact := hero + Vector2(10, -48)
			if "sweep" in move:
				var origin := enemy + Vector2(-18, -44)
				var bend := (origin + impact) * 0.5 + Vector2(0, -31)
				var trail := PackedVector2Array()
				for j in range(18):
					var t := lerpf(maxf(0.0, flight - 0.56), flight, float(j) / 17.0)
					trail.append(origin.lerp(bend, t).lerp(bend.lerp(impact, t), t))
				if trail.size() > 1:
					draw_polyline(trail, Color(0.62, 0.54, 0.31, fade * 0.32), 9.0, true)
					draw_polyline(trail, Color(0.70, 0.62, 0.39, fade), 2.3, true)
			elif "burst" in move:
				var origin := enemy + Vector2(-16, -57)
				var point := origin.lerp(impact, flight)
				var direction := (impact - origin).normalized()
				for j in range(3):
					var stone := point - direction * j * 8.0
					draw_circle(stone, 4.8 - j * 0.7, Color(0.61, 0.57, 0.36, fade * (1.0 - j * 0.2)))
					draw_circle(stone + Vector2(-1, -1), 1.8, Color(0.90, 0.81, 0.55, fade))
				if phase == "contact":
					draw_arc(impact, 9 + progress * 9, -PI, PI, 22, Color(0.75, 0.63, 0.38, fade * (1.0 - progress)), 1.7, true)
		var response := str(p.hero.defense_action)
		var amount := float(p.hero.reaction_amount)
		if response == "guard": draw_arc(hero + Vector2(25, -57), 29, -1.3, 1.2, 24, Color(0.50, 0.70, 0.54, amount * 0.8), 2.6, true)
		if response == "dodge":
			for j in range(3): draw_line(hero + Vector2(28 - j * 4, -48 - j * 6), hero + Vector2(41 - j * 4, -53 - j * 6), Color(0.66, 0.46, 0.59, amount * 0.7), 1.6, true)
		var r: Dictionary = records[index]
		if float(r.age) < 0.75 and not r.event.is_empty():
			var e: Dictionary = r.event
			var point := (hero if e.target == "hero" else enemy) + Vector2(-10, -110 - float(r.age) * 13)
			var caption := "-%d" % e.damage
			if e.resolution == "dodge": caption = "闪 0"
			elif e.resolution == "guard": caption = "挡 %d" % e.damage
			_text(caption, point, 20, Color(COLORS[index], 1.0 - float(r.age) / 0.75))

	func _draw_equipped(point: Vector2, item: String, angle: float, scale_value: float) -> void:
		draw_set_transform(point, angle, Vector2.ONE * scale_value)
		draw_texture_rect(sword if item == "sword" else fan,
			Rect2(-7.8, -53.7, 26, 76) if item == "sword" else Rect2(-23.3, -25.6, 48, 40), false)
		draw_set_transform(Vector2.ZERO)

	func _draw_health(rect: Rect2, hp: int, max_hp: int, color: Color) -> void:
		draw_rect(rect, Color(0.36, 0.40, 0.31, 0.13))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * float(hp) / max_hp, rect.size.y)), color)

	func _shadow(point: Vector2, scale_value: Vector2) -> void:
		draw_set_transform(point, 0.0, scale_value)
		draw_circle(Vector2.ZERO, 1.0, Color(0.23, 0.31, 0.22, 0.15))
		draw_set_transform(Vector2.ZERO)

	func _text(value: String, point: Vector2, size_value: int, color: Color, font: Font = SERIF) -> void:
		draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_value, color)

	func _paper() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("f7f1e4")
		box.border_color = Color("d8d0be")
		box.set_border_width_all(1)
		box.set_corner_radius_all(8)
		return box

	func _capture(filename: String) -> void:
		await RenderingServer.frame_post_draw
		var output := "res://builds/full-v1/" + filename
		DirAccess.make_dir_recursive_absolute("res://builds/full-v1")
		var shot := get_viewport().get_texture().get_image()
		if shot:
			print("TECHNIQUE_SCREENSHOT: ", output, " status=", shot.save_png(output))

	func _finish() -> void:
		if OS.get_environment("TECHNIQUE_DUELS_LIVE") == "1": return
		if DisplayServer.get_name() != "headless":
			await get_tree().create_timer(0.35).timeout
		get_tree().quit()


func _initialize() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1200, 640)
	root.title = "Mountain Still | Four Technique Duel Proof"
	root.add_child(DuelProof.new())
	_resize.call_deferred()


func _resize() -> void:
	# The desktop compositor may restore its previous geometry during startup.
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1200, 640)
	await process_frame
	root.size = Vector2i(1200, 640)
