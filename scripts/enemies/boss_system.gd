extends Node3D
class_name BossSystem

const BOSS_PURPLE: int = 0x9b4dff
const BOSS_CRIMSON: int = 0xd43a3a
const BOSS_INFECTED: int = 0x2f9e34
const BOSS_ROTTEN: int = 0x77a12c
const BLUGA_FACE: int = 0x6fd8ff

const BOSS_HP: int = 650
const BOSS2_HP: int = 813
const BOSS3_HP: int = 813
const BOSS3_BIG: float = 1.15
const BOSS4_HP: int = 976
const CRIMSON_HANDS: int = 0x4a1a1a
const INFECTED_HANDS: int = 0x145414
const ROTTEN_HANDS: int = 0x3f5a14

const BOSS_BEAM_HEIGHT: float = 64.0
const BOSS_BEAM_OPACITY: float = 0.22

var boss: Dictionary = {}
var beam_mesh: MeshInstance3D = null
var beam_material: StandardMaterial3D = null
var beam_fade: bool = false
var boss_bar_visible: bool = false
var current_boss_kind: int = 0

var world_node: Node3D = null
var boss_glow_scene: PackedScene = null

static var _bank_pos := Vector3(0.0, 0.0, -37.7)
static var _church_pos := Vector3(25.0, 0.0, 81.0)
static var _lot_pos := Vector3(77.0, 0.0, 23.0)
static var _park_center := Vector3(129.0, 0.0, -42.0)
static var _jelly_pos := Vector3(124.0, 0.0, 178.0)
static var _jelly_inside := Vector3(124.0, 0.0, 182.2)
static var _fountain := Vector3(0.0, 0.0, -28.2)


func _ready() -> void:
	SignalBus.toast_show.connect(_on_toast)
	SignalBus.boss_defeated.connect(_on_boss_defeated_signal)


func setup(p_world: Node3D) -> void:
	world_node = p_world


func _on_toast(message: String, _important: bool) -> void:
	pass


func _on_boss_defeated_signal(boss_index: int) -> void:
	pass


func ground_height(x: float, z: float) -> float:
	return 0.0


func maybe_spawn_boss1() -> void:
	if GameState.boss_spawned or GameState.boss_defeated:
		return
	if GameState.state != GameState.GameStateEnum.PLAYING:
		return
	if not GameState.all_cousins_recruited:
		return
	spawn_boss1()


func spawn_boss1() -> void:
	GameState.boss_spawned = true
	current_boss_kind = 1

	var bp := _bank_pos
	var blob := BlobBuilder.new()
	blob.body_color = Color.hex(BOSS_PURPLE)
	blob.is_zombie = true
	blob.scale = 2.7

	add_child(blob)
	blob.global_position = Vector3(bp.x, ground_height(bp.x, bp.z), bp.z)

	_attach_horns(blob, 0x2a1a3a)
	_attach_boss_glow(blob, BOSS_PURPLE)

	var hp := roundi(BOSS_HP * (1.0 + 0.4 * GameState.cycle))
	boss = {
		"blob": blob,
		"pos": Vector3(bp.x, 0.0, bp.z),
		"hp": hp, "max_hp": hp,
		"speed": 1.15, "yaw": 0.0,
		"state": "dormant", "attack_t": 0.0, "dead_t": 0.0,
		"walk_phase": 0.0, "groan_t": 2.0, "scale": 2.7,
		"brain_exposed": false, "blind": false, "step_t": 0.0,
		"bleeding": false, "drip_t": 0.0,
		"is_boss": true, "is_boss2": false, "is_boss3": false, "is_boss4": false,
		"waves_fired": 0, "dash_t": 0.0, "dash_cd_t": -9.0,
		"bite_mult": 1.0,
	}

	_spawn_beam(bp, Color.hex(0xb03cff))
	SignalBus.toast_show.emit("ALL COUSINS FOUND . . SOMETHING STIRS BY THE BANK .ᐟ", true)
	SignalBus.boss_spawned.emit(1, bp.x, bp.z)


func spawn_boss2() -> void:
	GameState.boss2_spawned = true
	current_boss_kind = 2

	var bp := _church_pos
	var blob := BlobBuilder.new()
	blob.body_color = Color.hex(BOSS_CRIMSON)
	blob.is_zombie = true
	blob.scale = 2.7

	add_child(blob)
	blob.global_position = Vector3(bp.x, ground_height(bp.x, bp.z), bp.z)

	_attach_horns(blob, 0x3a1414)
	_attach_boss_glow(blob, BOSS_CRIMSON)

	var hp := roundi(BOSS2_HP * (1.0 + 0.4 * GameState.cycle))
	boss = {
		"blob": blob,
		"pos": Vector3(bp.x, 0.0, bp.z),
		"hp": hp, "max_hp": hp,
		"speed": 1.15, "yaw": -PI / 2.0,
		"state": "dormant", "attack_t": 0.0, "dead_t": 0.0,
		"walk_phase": 0.0, "groan_t": 2.0, "scale": 2.7,
		"brain_exposed": false, "blind": false, "step_t": 0.0,
		"bleeding": false, "drip_t": 0.0,
		"is_boss": true, "is_boss2": true, "is_boss3": false, "is_boss4": false,
		"waves_fired": 0, "dash_t": 0.0, "dash_cd_t": -9.0,
		"bite_mult": 1.35, "red": true,
	}

	_spawn_beam(bp, Color.hex(0xff3030))
	SignalBus.toast_show.emit("BLOCK SCOURED . . BUT THE GRAVES SHIFT BY THE OLD CHURCH .ᐟ", true)
	SignalBus.boss_spawned.emit(2, bp.x, bp.z)


func spawn_boss3() -> void:
	GameState.boss3_spawned = true
	current_boss_kind = 3

	var bp := _lot_pos
	var sc := 2.7 * BOSS3_BIG
	var blob := BlobBuilder.new()
	blob.body_color = Color.hex(BOSS_INFECTED)
	blob.is_zombie = true
	blob.scale = sc

	add_child(blob)
	blob.global_position = Vector3(bp.x, ground_height(bp.x, bp.z), bp.z)

	_attach_horns(blob, 0x123a12)
	_attach_boss_glow(blob, BOSS_INFECTED)

	var hp := roundi(BOSS3_HP * (1.0 + 0.4 * GameState.cycle))
	boss = {
		"blob": blob,
		"pos": Vector3(bp.x, 0.0, bp.z),
		"hp": hp, "max_hp": hp,
		"speed": 1.15 * BOSS3_BIG, "yaw": PI,
		"state": "dormant", "attack_t": 0.0, "dead_t": 0.0,
		"walk_phase": 0.0, "groan_t": 2.0, "scale": sc,
		"brain_exposed": false, "blind": false, "step_t": 0.0,
		"bleeding": false, "drip_t": 0.0,
		"is_boss": true, "is_boss2": false, "is_boss3": true, "is_boss4": false,
		"waves_fired": 0, "dash_t": 0.0, "dash_cd_t": -9.0,
		"bite_mult": 1.35, "green": true,
	}

	_spawn_beam(bp, Color.hex(0x3ae04a))
	SignalBus.toast_show.emit("THE CHURCH IS QUIET . . SOMETHING STIRS UNDER THE LOT LIGHTS .ᐟ", true)
	SignalBus.boss_spawned.emit(3, bp.x, bp.z)


func spawn_boss4() -> void:
	GameState.boss4_spawned = true
	current_boss_kind = 4

	var bp := _park_center + Vector3(0.0, 0.0, 6.0)
	var sc := 2.7 * BOSS3_BIG
	var blob := BlobBuilder.new()
	blob.body_color = Color.hex(BOSS_ROTTEN)
	blob.is_zombie = true
	blob.scale = sc

	add_child(blob)
	blob.global_position = Vector3(bp.x, ground_height(bp.x, bp.z), bp.z)

	_attach_boss_glow(blob, BOSS_ROTTEN)

	var hp := roundi(BOSS4_HP * (1.0 + 0.4 * GameState.cycle))
	boss = {
		"blob": blob,
		"pos": Vector3(bp.x, 0.0, bp.z),
		"hp": hp, "max_hp": hp,
		"speed": 1.15 * BOSS3_BIG, "yaw": 0.0,
		"state": "dormant", "attack_t": 0.0, "dead_t": 0.0,
		"walk_phase": 0.0, "groan_t": 2.0, "scale": sc,
		"head_t": 0.5, "head_anim": null,
		"brain_exposed": false, "blind": false, "step_t": 0.0,
		"bleeding": false, "drip_t": 0.0,
		"is_boss": true, "is_boss2": false, "is_boss3": false, "is_boss4": true,
		"waves_fired": 0, "dash_t": 0.0, "dash_cd_t": -9.0,
		"bite_mult": 1.35,
	}

	_spawn_beam(bp, Color.hex(0xb8e03a))
	SignalBus.boss_spawned.emit(4, bp.x, bp.z)


func _attach_horns(blob: BlobBuilder, horn_color: int) -> void:
	if not blob.head:
		return
	for s in [-1, 1]:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.02
		horn.bottom_radius = 0.15
		horn.height = 0.55

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.hex(horn_color)
		mat.roughness = 0.6

		var mi := MeshInstance3D.new()
		mi.mesh = horn
		mi.set_surface_override_material(0, mat)

		mi.position = Vector3(0.22 * s, 0.3, 0.02)
		mi.rotation_degrees = Vector3(-14.3, 0.0, -31.5 * s)

		blob.head.add_child(mi)


func _attach_boss_glow(blob: BlobBuilder, _color: int) -> void:
	pass


func _spawn_beam(pos: Vector3, col: Color) -> void:
	if beam_mesh:
		_remove_beam()

	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.7
	cyl.bottom_radius = 1.7
	cyl.height = 130.0

	beam_material = StandardMaterial3D.new()
	beam_material.albedo_color = col
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.albedo_color.a = BOSS_BEAM_OPACITY
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	beam_mesh = MeshInstance3D.new()
	beam_mesh.mesh = cyl
	beam_mesh.set_surface_override_material(0, beam_material)
	beam_mesh.position = Vector3(pos.x, ground_height(pos.x, pos.z) + BOSS_BEAM_HEIGHT, pos.z)

	add_child(beam_mesh)
	beam_fade = false


func _remove_beam() -> void:
	if beam_mesh:
		beam_mesh.queue_free()
		beam_mesh = null
		beam_material = null
	beam_fade = false


func wake_boss() -> void:
	if boss.get("state") != "dormant":
		return
	boss["state"] = "chase"
	beam_fade = true

	var k := current_boss_kind
	match k:
		4:
			SignalBus.toast_show.emit("THE ROTTEN ONE CRASHES THE PICNIC .ᐟ", true)
		3:
			SignalBus.toast_show.emit("THE INFECTED ONE DISTURBS THE LOT .ᐟ", true)
		2:
			SignalBus.toast_show.emit("THE CRIMSON ONE RISES AT THE CHURCH DOOR .ᐟ", true)
		_:
			SignalBus.toast_show.emit("THE TWO HORNED ONE AWAKENS .ᐟ", true)

	SignalBus.screen_shake.emit(0.4)
	SignalBus.rumble.emit(400, 1.0, 1.0)
	_dress_boss_bar()
	SignalBus.boss_bar_show.emit(true)


func _dress_boss_bar() -> void:
	var k := current_boss_kind
	var label := ""
	match k:
		4: label = "The Rotten One"
		3: label = "The Infected One"
		2: label = "The Crimson One"
		_: label = "The Two Horned One"

	var style := ""
	match k:
		2: style = "crimson"
		3: style = "infected"
		4: style = "rotten"

	SignalBus.boss_bar_label.emit(label)
	if style != "":
		SignalBus.boss_bar_style.emit(style)


func boss_dash() -> void:
	if boss.get("state") == "dying":
		return
	boss["dash_t"] = 0.85
	boss["dash_cd_t"] = GameState.time + 4.0
	SignalBus.screen_shake.emit(0.15)


func fire_boss_wave(n: int) -> void:
	if not boss.size():
		return
	boss["waves_fired"] = n

	if boss.get("is_boss4"):
		_fire_rotten_wave(n)
	elif boss.get("is_boss3"):
		_fire_infected_wave(n)
	elif boss.get("is_boss2"):
		_fire_crimson_wave(n)
	else:
		_fire_horned_wave(n)

	boss_dash()

	if boss.get("is_boss4"):
		SignalBus.toast_show.emit("WAVE " + str(n) + ": THE ROT SHIELDS HIM .ᐟ CULL THE SWARM, THEN THE HEART .ᐟ", true)
	else:
		SignalBus.toast_show.emit("WAVE " + str(n) + ": KILL THE HORNED GUARDS TO BREAK HIS SHIELD", true)

	SignalBus.screen_shake.emit(0.2)


func _fire_horned_wave(n: int) -> void:
	var count := 4 + n * 3
	for k in range(count):
		var guard := k < ceili(float(count) / 2.0)
		var x: float = randf_range(-6.0, 6.0)
		var z: float = -40.8 + randf_range(0.0, 1.8)
		_spawn_guard(Vector3(x, 0.0, z), guard, false, false, 0x9b4dff, 0x4a1a7a)


func _fire_crimson_wave(n: int) -> void:
	var count := 6 + n * 4
	for k in range(count):
		var kind := k % 3
		if kind == 0:
			var x: float = _church_pos.x - 4.5 + randf_range(0.0, 3.0)
			var z: float = _church_pos.z - 2.0 + randf_range(0.0, 4.0)
			_spawn_guard(Vector3(x, 0.0, z), true, false, false, 0x9b4dff, 0x4a1a7a)
		elif kind == 1:
			var x: float = _church_pos.x - 4.5 + randf_range(0.0, 3.0)
			var z: float = _church_pos.z - 2.0 + randf_range(0.0, 4.0)
			_spawn_guard(Vector3(x, 0.0, z), false, true, false, 0xd43a3a, 0x4a1a1a)
		else:
			pass


func _fire_infected_wave(n: int) -> void:
	var count := 7 + n * 4
	for k in range(count):
		var x: float = _lot_pos.x + randf_range(-4.0, 4.0)
		var z: float = _lot_pos.z + randf_range(-3.0, 3.0)
		if n == 1:
			if k < ceili(float(count) / 2.0):
				_spawn_guard(Vector3(x, 0.0, z), true, false, true, 0x39b83a, 0x145414)
			else:
				pass
		elif n == 2:
			if k < ceili(float(count) / 2.0):
				_spawn_guard(Vector3(x, 0.0, z), true, false, false, 0x9b4dff, 0x4a1a7a)
			else:
				pass
		else:
			var kind := k % 3
			match kind:
				0: _spawn_guard(Vector3(x, 0.0, z), true, false, true, 0x39b83a, 0x145414)
				1: _spawn_guard(Vector3(x, 0.0, z), true, false, false, 0x9b4dff, 0x4a1a7a)
				2: _spawn_guard(Vector3(x, 0.0, z), true, true, false, 0xd43a3a, 0x4a1a1a)


func _fire_rotten_wave(n: int) -> void:
	var count := 12 + n * 5
	var cx: float = _park_center.x
	var cz: float = _park_center.z
	for _k in range(count):
		var px: float = cx
		var pz: float = cz
		var ok := false
		for _tries in range(12):
			if ok:
				break
			var a: float = randf_range(0.0, TAU)
			var dist: float = 22.0 + randf_range(0.0, 48.0)
			px = cx + sin(a) * dist
			pz = cz + cos(a) * dist
			ok = true
		if ok:
			pass


func _spawn_guard(pos: Vector3, has_horns: bool, is_red: bool, is_green: bool,
		_color: int, _hands_color: int) -> void:
	pass


func is_boss_shielded() -> bool:
	return false


func update_boss_state(_dt: float, player_pos: Vector3) -> void:
	if not boss.size():
		return

	if boss["state"] == "dormant":
		var d := boss["pos"].distance_to(player_pos)
		if d < 18.0:
			wake_boss()
		return

	var taken: float = 1.0 - float(boss["hp"]) / float(boss["max_hp"])
	var wf: int = boss["waves_fired"]
	if wf < 1 and taken >= 0.33:
		fire_boss_wave(1)
	elif wf < 2 and taken >= 0.50:
		fire_boss_wave(2)
	elif wf < 3 and taken >= 0.75:
		fire_boss_wave(3)


func update_boss_fx(dt: float) -> void:
	if beam_mesh and beam_material:
		if beam_fade:
			beam_material.albedo_color.a -= dt * 0.16
			if beam_material.albedo_color.a <= 0.0:
				_remove_beam()
		else:
			beam_material.albedo_color.a = 0.16 + sin(Time.get_ticks_msec() * 0.004) * 0.08

	if boss.size() and boss["state"] != "dormant" and boss_bar_visible:
		var ratio: float = clampf(float(boss["hp"]) / float(boss["max_hp"]), 0.0, 1.0)
		SignalBus.boss_bar_hp.emit(ratio)


func damage_boss(damage: int) -> void:
	if not boss.size():
		return
	if is_boss_shielded():
		return
	boss["hp"] = maxi(0, boss["hp"] - damage)


func on_boss_defeated() -> void:
	if not boss.size():
		return

	if boss.get("is_boss4", false):
		GameState.boss4_defeated = true
		_remove_beam()
		SignalBus.boss_bar_show.emit(false)
		SignalBus.toast_show.emit("THE ROTTEN ONE FALLS .ᐟ", true)
		SignalBus.screen_shake.emit(0.4)
		SignalBus.rumble.emit(600, 1.0, 1.0)
		SignalBus.boss_defeated.emit(4)
		if GameState.prestige_run:
			SignalBus.bluga_final_started.emit()
		else:
			SignalBus.jelly_house_beacon.emit()
		_clear_boss()
		return

	if boss.get("is_boss3", false):
		GameState.boss3_defeated = true
		_remove_beam()
		SignalBus.boss_bar_show.emit(false)
		SignalBus.toast_show.emit("THE INFECTED ONE FALLS . . BUT SOMETHING ROTS ON THE JELLY PARK .ᐟ", true)
		SignalBus.screen_shake.emit(0.4)
		SignalBus.rumble.emit(600, 1.0, 1.0)
		SignalBus.boss_defeated.emit(3)
		_clear_boss()
		spawn_boss4()
		return

	if boss.get("is_boss2", false):
		GameState.boss2_defeated = true
		_remove_beam()
		SignalBus.boss_bar_show.emit(false)
		SignalBus.toast_show.emit("THE CRIMSON ONE FALLS . . BUT THE LOT LIGHTS ARE STUTTERING .ᐟ", true)
		SignalBus.screen_shake.emit(0.4)
		SignalBus.rumble.emit(600, 1.0, 1.0)
		SignalBus.boss_defeated.emit(2)
		_clear_boss()
		spawn_boss3()
		return

	GameState.boss_defeated = true
	_remove_beam()
	SignalBus.boss_bar_show.emit(false)
	GameState.cleanup_active = true
	GameState.clear_target = ceili(float(GameState.kills + 1 + 100) / 100.0) * 100
	GameState.quota_total = GameState.clear_target - GameState.kills
	SignalBus.quota_show.emit(true, GameState.quota_total, GameState.clear_target)
	SignalBus.toast_show.emit("BOSS DOWN .ᐟ REACH " + str(GameState.clear_target) + " KILLS TO SECURE THE BLOCK .ᐟ", true)
	SignalBus.screen_shake.emit(0.4)
	SignalBus.rumble.emit(600, 1.0, 1.0)
	SignalBus.boss_defeated.emit(1)
	_clear_boss()


func cleanup_kill_check() -> void:
	if not GameState.cleanup_active:
		return
	if GameState.kills >= GameState.clear_target and not GameState.boss2_spawned and not GameState.boss2_defeated:
		GameState.cleanup_active = false
		SignalBus.quota_show.emit(false, 0, 0)
		spawn_boss2()
		SignalBus.cleanup_complete.emit()


func complete_cleanup() -> void:
	GameState.cleanup_active = false
	SignalBus.quota_show.emit(false, 0, 0)
	if not GameState.boss2_spawned and not GameState.boss2_defeated:
		spawn_boss2()
		return
	GameState.celebrate_t = 5.5
	SignalBus.toast_show.emit("BLOCK SECURED .ᐟ", true)
	SignalBus.rumble.emit(600, 1.0, 1.0)


func _clear_boss() -> void:
	boss = {}
	current_boss_kind = 0


func set_church_pos(pos: Vector3) -> void:
	_church_pos = pos


func set_lot_pos(pos: Vector3) -> void:
	_lot_pos = pos


func set_park_center(pos: Vector3) -> void:
	_park_center = pos


func set_jelly_pos(pos: Vector3) -> void:
	_jelly_pos = pos


func set_jelly_inside(pos: Vector3) -> void:
	_jelly_inside = pos


static func get_bank_pos() -> Vector3:
	return _bank_pos


static func get_fountain_pos() -> Vector3:
	return _fountain_pos


static func get_church_pos() -> Vector3:
	return _church_pos


static func get_jelly_pos() -> Vector3:
	return _jelly_pos


static func get_jelly_inside() -> Vector3:
	return _jelly_inside


static func get_park_center() -> Vector3:
	return _park_center
