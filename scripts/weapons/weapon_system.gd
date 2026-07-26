extends Node3D
class_name WeaponSystem

signal weapon_changed(weapon_id: String)
signal shot_fired(origin: Vector3, direction: Vector3, weapon: Dictionary)
signal ammo_updated(clip: int, reserve: int)
signal reload_started
signal reload_completed
signal hit_confirmed

@export var camera: Camera3D
@export var damage_mult: float = 1.0
@export var melee_mult: float = 1.0
@export var reload_speed_mult: float = 1.0
@export var ammo_mult: float = 1.0
@export var max_ray_reach: float = 80.0
@export var muzzle_node: Node3D

var current_weapon: Dictionary
var owned_weapons: Array[String] = ["fists"]
var clip: int = 0
var reserves: Dictionary = {}
var reloading: float = 0.0
var shoot_cooldown: float = 0.0
var swing_timer: float = 0.0
var swing_duration: float = 0.0
var last_shot_time: float = 0.0
var last_punch_time: float = 0.0
var last_melee_time: float = 0.0
var combo_n: int = 0
var melee_combo: int = 0
var melee_chop_timer: float = 0.0
var melee_chop_hop: bool = false
var gun_mesh: Node3D = null

func _ready() -> void:
	equip_weapon("fists")

func _process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return

	shoot_cooldown = maxf(0.0, shoot_cooldown - delta)
	swing_timer = maxf(0.0, swing_timer - delta)

	if melee_chop_timer > 0.0:
		melee_chop_timer -= delta
		if melee_chop_timer <= 0.0:
			_melee_chop_hit()

	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			_finish_reload()

	_handle_input()

func _handle_input() -> void:
	if Input.is_action_just_pressed("reload"):
		if current_weapon.get("id") == "chili":
			pass # eat_chili in full game
		else:
			try_reload()

	if Input.is_action_just_pressed("swap_weapon"):
		cycle_weapon(1)

	var w = current_weapon
	var want_shoot = Input.is_action_pressed("shoot")
	var is_melee = w.get("melee", false)
	var spent = not is_melee and clip <= 0 and (reserves.get(w["id"], 0) | 0) <= 0

	if want_shoot and shoot_cooldown <= 0.0:
		if spent and not is_melee:
			return
		fire_weapon()
		shoot_cooldown = 60.0 / float(w.get("rpm", 300))

func equip_weapon(id: String) -> void:
	var w = WeaponData.get_weapon(id)
	current_weapon = w

	if not owned_weapons.has(id):
		owned_weapons.append(id)
	owned_weapons.sort_custom(func(a, b): return WeaponData.slot_rank(a) < WeaponData.slot_rank(b))

	reloading = 0.0

	if not w.get("melee", false):
		clip = w["mag"]
		if not reserves.has(id):
			reserves[id] = roundi(float(w.get("ammo", 0)) * ammo_mult)
	else:
		clip = -1  # infinite

	weapon_changed.emit(id)
	_emit_ammo_updated()

func cycle_weapon(dir: int = 1) -> void:
	if owned_weapons.size() < 2:
		return

	if reloading > 0.0:
		return

	var idx = owned_weapons.find(current_weapon.get("id", "fists"))
	if idx < 0:
		idx = 0

	var id: String = current_weapon.get("id", "fists")
	for _n in owned_weapons.size():
		idx = wrapi(idx + dir, 0, owned_weapons.size())
		var cand = WeaponData.get_weapon(owned_weapons[idx])
		id = cand["id"]
		break

	if id == current_weapon.get("id", "fists"):
		return

	equip_weapon(id)

func fire_weapon() -> void:
	var w = current_weapon

	if w.get("melee", false):
		_fire_melee()
	else:
		_fire_gun()

func _fire_melee() -> void:
	var w = current_weapon
	var w_id: String = w["id"]

	swing_duration = 60.0 / float(w.get("rpm", 150)) * 0.9
	swing_timer = swing_duration

	if w_id == "fists":
		if GameState.time - last_punch_time > WeaponData.COMBO_WINDOW:
			combo_n = 0
		else:
			combo_n += 1
		last_punch_time = GameState.time
	else:
		var combo_len = 3 if w_id == "bat" else 2
		if GameState.time - last_melee_time > WeaponData.COMBO_WINDOW:
			melee_combo = 0
		else:
			melee_combo = (melee_combo + 1) % combo_len
		last_melee_time = GameState.time

		if w_id == "bat" and melee_combo % 3 == 2:
			swing_duration = swing_timer = swing_duration * 1.35

	var hits = _melee_targets(w)
	if hits.size() > 0:
		for hit in hits:
			if not is_instance_valid(hit):
				continue
			var dx = hit.global_position.x - global_position.x
			var dz = hit.global_position.z - global_position.z
			var d = sqrt(dx * dx + dz * dz)
			if d < 0.001:
				d = 1.0
			var base_dmg: float
			if w_id == "fists":
				base_dmg = 7.0 if combo_n % 2 == 1 else 6.0
			else:
				base_dmg = float(w["dmg"])
			var dmg = base_dmg * melee_mult * WeaponData.close_bonus(w, d)
			_apply_damage(hit, dmg, Vector3(dx / d, 0.0, dz / d), 3.5, {"weapon": w, "dist": d, "isHead": false})

		if w_id != "fists":
			melee_chop_timer = swing_duration * 0.4

func _melee_chop_hit() -> void:
	var w = current_weapon
	if not w.get("melee", false) or w["id"] == "fists":
		return

	var hits = _melee_targets(w)
	if hits.size() == 0:
		return

	var knock = 3.5 * (2.2 if melee_chop_hop else 1.0)
	for hit in hits:
		if not is_instance_valid(hit):
			continue
		var dx = hit.global_position.x - global_position.x
		var dz = hit.global_position.z - global_position.z
		var d = sqrt(dx * dx + dz * dz)
		if d < 0.001:
			d = 1.0
		var dmg = float(w["dmg"]) * melee_mult * WeaponData.close_bonus(w, d) * (2.0 if melee_chop_hop else 1.0)
		_apply_damage(hit, dmg, Vector3(dx / d, 0.0, dz / d), knock, {"weapon": w, "dist": d, "isHead": false})

func _fire_gun() -> void:
	var w = current_weapon

	if reloading > 0.0:
		return

	if clip <= 0:
		if (reserves.get(w["id"], 0) | 0) <= 0:
			return
		clip -= 1
		if clip <= 0:
			clip = 0
			return
	else:
		clip -= 1

	if clip == 0:
		try_reload()

	last_shot_time = GameState.time

	var pellets = w.get("pellets", 1)
	var spread: float = w.get("spread", 0.01)
	var reach: float = max_ray_reach

	# Rifle with full reach gets extended
	if w["id"] == "sniper" or w["id"] == "rifle":
		reach = maxf(80.0, max_ray_reach)

	var space_state = get_world_3d().direct_space_state
	var camera_dir = -camera.global_transform.basis.z
	var muzzle_origin: Vector3

	if muzzle_node:
		muzzle_origin = muzzle_node.global_position
	else:
		muzzle_origin = camera.global_position

	var any_hit = false

	for p in range(pellets):
		var dir = camera_dir
		if spread > 0.0:
			dir.x += (randf() - 0.5) * spread * 2.0
			dir.y += (randf() - 0.5) * spread * 2.0
			dir.z += (randf() - 0.5) * spread * 2.0
			dir = dir.normalized()

		var to = muzzle_origin + dir * reach

		var query = PhysicsRayQueryParameters3D.create(muzzle_origin, to)
		query.collision_mask = 0xFFFFFFFF
		query.hit_from_inside = false
		query.exclude = [self]

		var result = space_state.intersect_ray(query)

		if not result.is_empty():
			any_hit = true
			var hit_point = result["position"]
			var hit_obj = result["collider"]
			var hit_distance = muzzle_origin.distance_to(hit_point)

			if hit_obj and hit_obj.has_method("take_damage"):
				var is_head = result.get("normal", Vector3.UP).y > 0.0  # Simplified; head detection needs proper bone/group check
				var dmg_base = float(w["dmg"]) * damage_mult
				var dmg = dmg_base * (2.0 if is_head else 1.0) * WeaponData.close_bonus(w, hit_distance) * WeaponData.range_factor(w, hit_distance)
				_apply_damage(hit_obj, dmg, dir, 2.0, {"weapon": w, "dist": hit_distance, "isHead": is_head})

			_spawn_tracer(muzzle_origin, hit_point)
			_spawn_impact(hit_point, -dir, w)
		else:
			_spawn_tracer(muzzle_origin, to)

	if any_hit:
		hit_confirmed.emit()

	_emit_ammo_updated()

func try_reload() -> void:
	var w = current_weapon
	if w.get("melee", false):
		return
	if reloading > 0.0:
		return
	if clip >= w["mag"]:
		return

	var res: int = reserves.get(w["id"], 0) | 0
	if res <= 0:
		return

	reloading = 1.4 * reload_speed_mult
	reload_started.emit()

func _finish_reload() -> void:
	var w = current_weapon
	var need = w["mag"] - clip
	var take = mini(need, reserves.get(w["id"], 0) | 0)
	clip += take
	reserves[w["id"]] = reserves[w["id"]] - take

	reload_completed.emit()
	_emit_ammo_updated()

func _melee_targets(w: Dictionary) -> Array[Node3D]:
	var aim_dir = -camera.global_transform.basis.z
	if aim_dir.length_squared() < 0.001:
		return []
	var yaw = atan2(aim_dir.x, aim_dir.z)
	var reach = float(w["range"])
	var out: Array[Node3D] = []

	for enemy in _get_nearby_enemies():
		if not is_instance_valid(enemy):
			continue
		var dx = enemy.global_position.x - global_position.x
		var dz = enemy.global_position.z - global_position.z
		if hypot(dx, dz) >= reach:
			continue
		var angle = atan2(dx, dz)
		var diff = fmod(angle - yaw + PI, TAU) - PI
		if absf(diff) < 1.15:
			out.append(enemy)

	return out

func _get_nearby_enemies() -> Array[Node3D]:
	var enemies: Array[Node3D] = []
	var groups = ["zombies", "enemies"]
	for grp in groups:
		for node in get_tree().get_nodes_in_group(grp):
			if node is Node3D:
				enemies.append(node)
	return enemies

func _apply_damage(target: Node3D, dmg: float, knock_dir: Vector3, knock_force: float, opts: Dictionary) -> void:
	if target.has_method("damage"):
		target.damage(dmg, knock_dir, knock_force, opts)

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var len = from.distance_to(to)
	if len < 0.2:
		return

	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, len)
	tracer.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.88, 0.54)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.88, 0.54)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	tracer.material_override = mat

	tracer.position = from.lerp(to, 0.5)
	tracer.look_at(to)

	get_tree().root.add_child(tracer)

	var tween = create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.07)
	tween.tween_callback(tracer.queue_free)

func _spawn_impact(pos: Vector3, normal: Vector3, _w: Dictionary) -> void:
	pass

func add_reserve_ammo(weapon_id: String, amount: int) -> void:
	if not reserves.has(weapon_id):
		reserves[weapon_id] = 0
	reserves[weapon_id] = reserves[weapon_id] + roundi(float(amount) * ammo_mult)

func give_weapon(id: String) -> void:
	var w = WeaponData.get_weapon(id)
	if not owned_weapons.has(id):
		owned_weapons.append(id)
		owned_weapons.sort_custom(func(a, b): return WeaponData.slot_rank(a) < WeaponData.slot_rank(b))
	if not w.get("melee", false) and not reserves.has(id):
		reserves[id] = roundi(float(w.get("ammo", 0)) * ammo_mult)

func has_weapon(id: String) -> bool:
	return owned_weapons.has(id)

func _emit_ammo_updated() -> void:
	var cl = clip
	var res = reserves.get(current_weapon.get("id", ""), 0) | 0
	if current_weapon.get("melee", false):
		cl = -1
		res = 0
	ammo_updated.emit(cl, res)
