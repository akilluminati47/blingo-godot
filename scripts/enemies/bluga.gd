extends Node3D
class_name BlugaSystem

const FBI_BLACK: int = 0x141519
const FBI_BLACK_DK: int = 0x0a0b0e
const BLUGA_FACE_COLOR: int = 0x6fd8ff
const BLUGA_BEAM_COLOR: int = 0x2b3550

var phase: String = "idle"
var bluga_boss: Dictionary = {}
var cameo: Dictionary = {}
var cam_t: float = 0.0
var cam_done: bool = false
var wave_count: int = 0
var appear_t: float = 0.0
var smoke_t: float = 0.0
var beam_mesh: MeshInstance3D = null
var beam_material: StandardMaterial3D = null

var boss_system: BossSystem = null


func _ready() -> void:
	SignalBus.bluga_cameo_started.connect(_on_cameo_started)
	SignalBus.bluga_final_started.connect(_on_final_started)


func setup(p_boss_system: BossSystem) -> void:
	boss_system = p_boss_system


func reset_bluga() -> void:
	if cameo.size() and cameo.get("blob"):
		var b: BlobBuilder = cameo["blob"]
		b.queue_free()
	cameo = {}
	phase = "idle"
	bluga_boss = {}
	cam_t = 0.0
	cam_done = false
	wave_count = 0
	appear_t = 0.0
	smoke_t = 0.0
	_remove_beam()


func _on_cameo_started() -> void:
	start_cameo()


func _on_final_started() -> void:
	spawn_bluga_final()


func maybe_start_cameo() -> void:
	if phase != "idle" or cam_done:
		return
	if not GameState.prestige_run:
		return
	if GameState.time < 1.5:
		return
	start_cameo()


func start_cameo() -> void:
	phase = "cameo"
	cam_t = 0.0

	var cx: float = BossSystem.get_bank_pos().x
	var cz: float = BossSystem.get_bank_pos().z

	var blob := _build_fbi_blob(BLUGA_FACE_COLOR, true)
	blob.global_position = Vector3(cx, _ground_y(cx, cz), cz)
	add_child(blob)

	cameo = {
		"blob": blob,
		"pos": Vector3(cx, 0.0, cz),
		"yaw": 0.0,
		"shoot_cd": 0.0,
		"prey": [],
		"wander_t": 0.0,
		"wx": cx,
		"wz": cz,
		"walk": 0.0,
		"greet_t": 0.0,
		"greeted": false,
		"exit_phase": 0,
		"show_done": 0.0,
	}

	SignalBus.toast_show.emit("WHO IS THAT BY THE FOUNTAIN .ᐟ", true)
	SignalBus.bluga_cameo_started.emit()


func update_cameo(dt: float) -> void:
	if not cameo.size():
		return
	cam_t += dt

	var c := cameo
	var b: BlobBuilder = c["blob"]
	var gy: float = _ground_y(c["pos"].x, c["pos"].z)
	var t: float = cam_t

	var alive: Array = []
	for p in c["prey"]:
		if is_instance_valid(p):
			alive.append(p)

	if t < 7.0 and not (alive.is_empty() and t > 1.2):
		c["wander_t"] -= dt
		if c["wander_t"] <= 0.0:
			c["wander_t"] = 0.9 + randf_range(0.0, 0.8)
			var a: float = randf_range(0.0, TAU)
			var d: float = 1.5 + randf_range(0.0, 4.0)
			c["wx"] = BossSystem.get_bank_pos().x + sin(a) * d
			c["wz"] = BossSystem.get_bank_pos().z + cos(a) * d

		var wd: float = Vector2(c["wx"] - c["pos"].x, c["wz"] - c["pos"].z).length()
		if wd > 0.3:
			var sp: float = 4.2 * dt
			c["pos"].x += (c["wx"] - c["pos"].x) / wd * sp
			c["pos"].z += (c["wz"] - c["pos"].z) / wd * sp
			c["walk"] = c.get("walk", 0.0) + sp * 6.0

		var sw: float = sin(c["walk"]) * 0.5
		if b.legs.size() >= 2:
			b.legs[0].rotation.x = sw
			b.legs[1].rotation.x = -sw

		var tgt: Node3D = null
		var td: float = INF
		for p in alive:
			var d: float = Vector2(p.global_position.x - c["pos"].x, p.global_position.z - c["pos"].z).length()
			if d < td:
				td = d
				tgt = p

		if tgt:
			var want: float = atan2(tgt.global_position.x - c["pos"].x, tgt.global_position.z - c["pos"].z)
			c["yaw"] = lerp_angle(c["yaw"], want, 1.0 - exp(-10.0 * dt))
			c["shoot_cd"] -= dt
			if c["shoot_cd"] <= 0.0 and abs(angle_difference(c["yaw"], want)) < 0.3:
				c["shoot_cd"] = 0.22
				if b.arms.size() > 0:
					b.arms[0].rotation.x = -PI / 2.0 + 0.25

		c["show_done"] = t
	elif c["greet_t"] == 0.0:
		c["greet_t"] = t

	if c["greet_t"] != 0.0 and t < c["greet_t"] + 2.2:
		var want: float = atan2(
			0.0 - c["pos"].x,
			0.0 - c["pos"].z
		)
		c["yaw"] = lerp_angle(c["yaw"], want, 1.0 - exp(-8.0 * dt))
		if b.arms.size() > 0:
			b.arms[0].rotation.x = lerpf(b.arms[0].rotation.x, -0.15, 1.0 - exp(-8.0 * dt))
		if b.legs.size() >= 2:
			b.legs[0].rotation.x = 0.0
			b.legs[1].rotation.x = 0.0
		if not c["greeted"] and t > c["greet_t"] + 0.7:
			c["greeted"] = true
	elif c["greet_t"] != 0.0:
		var front_x: float = 0.0
		var front_z: float = -39.4
		var door_x: float = 0.0
		var door_z: float = -42.0

		if c["exit_phase"] == 0:
			c["exit_phase"] = 1

		if c["exit_phase"] == 1:
			var dx: float = front_x - c["pos"].x
			var dz: float = front_z - c["pos"].z
			var d: float = sqrt(dx * dx + dz * dz)
			c["yaw"] = lerp_angle(c["yaw"], atan2(dx, dz), 1.0 - exp(-8.0 * dt))
			if d > 0.4:
				var step: float = minf(4.6 * dt, d)
				c["pos"].x += dx / d * step
				c["pos"].z += dz / d * step
				c["walk"] = c.get("walk", 0.0) + step * 6.0
				var sw2: float = sin(c["walk"]) * 0.5
				if b.legs.size() >= 2:
					b.legs[0].rotation.x = sw2
					b.legs[1].rotation.x = -sw2
				if b.arms.size() > 0:
					b.arms[0].rotation.x = lerpf(b.arms[0].rotation.x, -0.15, 1.0 - exp(-8.0 * dt))
			else:
				c["exit_phase"] = 2
		else:
			var dx: float = door_x - c["pos"].x
			var dz: float = door_z - c["pos"].z
			var d: float = maxf(sqrt(dx * dx + dz * dz), 0.01)
			c["yaw"] = atan2(dx, dz)
			c["pos"].x += dx / d * 14.0 * dt
			c["pos"].z += dz / d * 14.0 * dt
			if d < 0.5:
				b.queue_free()
				cameo = {}
				phase = "idle"
				cam_done = true
				return

	b.global_position = Vector3(c["pos"].x, _ground_y(c["pos"].x, c["pos"].z), c["pos"].z)
	b.rotation.y = c["yaw"]


func spawn_bluga_final() -> void:
	if bluga_boss.size():
		return
	phase = "final"
	wave_count = 0

	var jx: float = BossSystem.get_jelly_pos().x
	var jz: float = BossSystem.get_jelly_pos().z
	var gy: float = _ground_y(jx, jz)

	_spawn_bluga_beam(Vector3(jx, gy + 100.0, jz))

	var jgx: float = BossSystem.get_jelly_inside().x
	var jgz: float = BossSystem.get_jelly_inside().z - 2.0

	var z := _spawn_fbi(Vector3(jgx, 0.0, jgz), "rifle", true)
	z["vanished"] = true
	if z.get("blob"):
		z["blob"].visible = false
	bluga_boss = z

	for i in range(5):
		var a: float = (float(i) / 5.0) * TAU + 0.4
		var gx: float = jx + sin(a) * 13.0
		var gz: float = jz + cos(a) * 13.0
		_spawn_fbi(Vector3(gx, 0.0, gz), "", false)

	SignalBus.boss_bar_label.emit("Bluga the Bad Blob")
	SignalBus.boss_bar_style.emit("bluga")
	SignalBus.boss_bar_show.emit(true)
	SignalBus.toast_show.emit("BLUGA THE BAD BLOB .ᐟ CULL THE SQUAD TO UNMASK HIM .ᐟ", true)


func bluga_fire_wave() -> void:
	wave_count += 1
	var n: int = wave_count
	for _i in range(3):
		var a: float = randf_range(0.0, TAU)
		var dist: float = 16.0 + randf_range(0.0, 8.0)
		var gx: float = BossSystem.get_jelly_pos().x + sin(a) * dist
		var gz: float = BossSystem.get_jelly_pos().z + cos(a) * dist
		_spawn_fbi(Vector3(gx, 0.0, gz), "", false)

	SignalBus.toast_show.emit("WAVE " + str(n) + " .ᐟ SPEC OPS CLOSING IN .ᐟ", true)


func update_bluga(dt: float) -> void:
	maybe_start_cameo()
	if phase == "cameo":
		update_cameo(dt)

	var z: Dictionary = bluga_boss
	if not z.size():
		return

	var hp: int = z.get("hp", 0)
	var max_hp: int = z.get("max_hp", 1)

	if z.get("state") == "dying" or hp <= 0:
		return

	if not z.get("vanished", true):
		var taken: float = 1.0 - float(hp) / float(max_hp)
		if wave_count < 1 and taken >= 0.30:
			bluga_fire_wave()
		elif wave_count < 2 and taken >= 0.55:
			bluga_fire_wave()
		elif wave_count < 3 and taken >= 0.80:
			bluga_fire_wave()

	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	SignalBus.boss_bar_hp.emit(ratio)

	if beam_mesh and beam_material:
		if z.get("vanished", true):
			beam_material.albedo_color.a = 0.24 + sin(Time.get_ticks_msec() * 0.004) * 0.08
		else:
			beam_material.albedo_color.a = maxf(0.0, beam_material.albedo_color.a - dt * 0.2)


func _spawn_bluga_beam(pos: Vector3) -> void:
	_remove_beam()

	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.6
	cyl.bottom_radius = 2.6
	cyl.height = 220.0

	beam_material = StandardMaterial3D.new()
	beam_material.albedo_color = Color.hex(BLUGA_BEAM_COLOR)
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.albedo_color.a = 0.32
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	beam_mesh = MeshInstance3D.new()
	beam_mesh.mesh = cyl
	beam_mesh.set_surface_override_material(0, beam_material)
	beam_mesh.position = pos

	add_child(beam_mesh)


func _remove_beam() -> void:
	if beam_mesh:
		beam_mesh.queue_free()
		beam_mesh = null
		beam_material = null


func _build_fbi_blob(face_color: int, big: bool) -> BlobBuilder:
	var blob := BlobBuilder.new()
	blob.body_color = Color.hex(FBI_BLACK)
	blob.is_zombie = true
	blob.scale = 1.4 if big else 1.0

	return blob


func _spawn_fbi(pos: Vector3, weapon: String, is_bluga: bool) -> Dictionary:
	var face_color := BLUGA_FACE_COLOR if is_bluga else _random_cousin_color()
	var wid: String = weapon
	if wid == "":
		wid = "smg" if randf() < 0.5 else "rifle"

	var blob := _build_fbi_blob(face_color, is_bluga)
	var gy: float = _ground_y(pos.x, pos.z)
	blob.global_position = Vector3(pos.x, gy, pos.z)
	add_child(blob)

	var power: float = 1.0 + GameState.time / 240.0
	var minion_hp: int = roundi((9.0 + randf_range(0.0, 6.0)) * 1.2 * power)

	return {
		"blob": blob,
		"pos": Vector3(pos.x, 0.0, pos.z),
		"yaw": randf_range(0.0, TAU),
		"scale": 1.4 if is_bluga else 1.0,
		"hp": roundi(BossSystem.BOSS2_HP * 0.9) if is_bluga else minion_hp,
		"max_hp": roundi(BossSystem.BOSS2_HP * 0.9) if is_bluga else minion_hp,
		"minion_hp": minion_hp,
		"state": "chase", "dead_t": 0.0,
		"walk_phase": randf_range(0.0, 9.0),
		"speed": (1.5 + randf_range(0.0, 1.4)) * 1.25 * (0.9 + power * 0.1),
		"fbi": true, "fbi_wave": false, "fbi_face": face_color,
		"fbi_weapon": wid, "bluga": is_bluga,
		"home_x": pos.x, "home_z": pos.z, "y": gy,
		"vy": 0.0, "grounded": true, "aim_pitch": 0.0,
		"shoot_cd": randf_range(0.0, 0.7),
		"attack_t": 0.0, "bite_mult": 1.0,
		"vanished": false, "blind": false, "alerted": false,
		"fbi_slide_t": 0.0, "slide_vx": 0.0, "slide_vz": 0.0,
	}


func fbi_guards_alive() -> bool:
	return false


func on_bluga_defeated(z: Dictionary) -> void:
	bluga_boss = {}
	phase = "done"
	_remove_beam()
	SignalBus.boss_bar_show.emit(false)
	SignalBus.toast_show.emit("BLUGA FALLS .ᐟ THE BLOCK IS FINALLY QUIET .ᐟ", true)
	SignalBus.screen_shake.emit(0.4)
	SignalBus.rumble.emit(600, 1.0, 1.0)
	SignalBus.jelly_house_beacon.emit()
	SignalBus.bluga_defeated.emit()


func _ground_y(x: float, z: float) -> float:
	return 0.0


func _random_cousin_color() -> int:
	var colors: Array[int] = [0xff8c42, 0xff4444, 0x6fd8ff, 0x39b83a, 0xd43a3a, 0xffd24a]
	return colors[randi() % colors.size()]


static func get_beam_color() -> Color:
	return Color.hex(BLUGA_BEAM_COLOR)
