extends CharacterBody3D
class_name ZombieAI

# ── Zombie AI Controller ──
# Handles state machine, chase behavior, attack, knockback, navigation, and animations.
# Mirrors the original game.js spawnZombie / updateZombies / damageZombie systems.

# ── Stats ──
@export var hp: float = 12.0
@export var max_hp: float = 12.0
@export var move_speed: float = 2.0
@export var zombie_scale: float = 1.0
@export var bite_mult: float = 1.0
@export var is_boss: bool = false
@export var is_boss2: bool = false
@export var is_boss3: bool = false
@export var is_boss4: bool = false
@export var variant_type: ZombieData.Variant = ZombieData.Variant.NONE
@export var spawn_mode: ZombieData.SpawnMode = ZombieData.SpawnMode.GRAVE
@export var is_fbi: bool = false

# ── State ──
var state: ZombieData.State = ZombieData.State.CHASE
var emerge_t: float = 0.0
var dead_t: float = 0.0
var walk_phase: float = 0.0
var groan_t: float = 0.0
var step_t: float = 0.0
var attack_t: float = 0.0
var punch_t: float = 0.0
var wander_t: float = 0.0
var wander_yaw: float = 0.0
var shot_ignore_t: float = -99.0
var reach_t: float = 0.0
var claw_phase: float = 0.0
var head_t: float = 0.0
var drip_t: float = 0.0
var dash_t: float = 0.0
var dash_cd_t: float = -9.0
var waves_fired: int = 0

# ── Knockback ──
var kvx: float = 0.0
var kvz: float = 0.0
var blocked: bool = false

# ── Vertical movement ──
var feet_y: float = 0.0
var vy: float = 0.0
var grounded: bool = true

# ── Traits ──
var brain_exposed: bool = false
var blind: bool = false
var droopy: bool = false
var bleeding: bool = false
var far_born: bool = false
var horn_wave: bool = false
var horn_vis: bool = false
var gore_horn: bool = false
var died_pop: bool = false
var vanished: bool = false

# ── Rot gore flags ──
var rot_e: bool = false
var rot_r: bool = false
var rot_rr: bool = false
var rot_b: bool = false

# ── Limb tracking ──
var arm_gone: Array[bool] = [false, false]
var leg_gone: Array[bool] = [false, false]
var head_gone: bool = false

# ── Head animation ──
var head_anim: Dictionary = {}
var repathed: bool = false
var skull_hits: int = 0

# ── Smooth velocity (for gunners to lead) ──
var vx: float = 0.0
var vz: float = 0.0

# ── Node references ──
var blob_builder: BlobBuilder
var navigation_agent: NavigationAgent3D
var attack_area: Area3D
var bite_cooldown_timer: Timer
var world_manager: Node  # Reference to world/terrain for ground height & collision

# ── Target tracking ──
var target_player: Node3D = null
var target_companion: Node3D = null
var current_target_pos: Vector3 = Vector3.ZERO
var has_target: bool = false
var surrounding: bool = false

# ── RNG ──
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ── Signals ──
signal zombie_damaged(zombie: ZombieAI, damage: float, knock_dir: Vector3, is_headshot: bool)
signal zombie_killed(zombie: ZombieAI, head_pop: bool)
signal zombie_attacked(target: Node3D, damage: float)


func _ready() -> void:
	rng.randomize()
	_blob_builder()
	_setup_navigation()
	_setup_attack_area()
	_setup_timers()
	groan_t = rng.randf_range(ZombieData.GROAN_INTERVAL_MIN, ZombieData.GROAN_INTERVAL_MAX)
	step_t = rng.randf()
	head_t = rng.randf_range(0, 2.5)
	walk_phase = rng.randf() * 10.0
	wander_yaw = rng.randf() * TAU
	claw_phase = rng.randf() * TAU
	feet_y = _ground_height(global_position.x, global_position.z)
	
	if spawn_mode == ZombieData.SpawnMode.GRAVE:
		state = ZombieData.State.EMERGE
	elif spawn_mode == ZombieData.SpawnMode.SLEEPER:
		state = ZombieData.State.SLEEP
	elif spawn_mode == ZombieData.SpawnMode.CORPSE:
		state = ZombieData.State.CORPSE
	
	if state == ZombieData.State.SLEEP or state == ZombieData.State.CORPSE:
		if blob_builder:
			blob_builder.rotation.x = -1.45


func _blob_builder() -> void:
	blob_builder = BlobBuilder.new()
	blob_builder.is_zombie = true
	blob_builder.droopy_eyes = droopy
	blob_builder.brain_exposed = brain_exposed
	blob_builder.blind = blind
	blob_builder.body_color = _body_color()
	blob_builder.scale_value = zombie_scale
	add_child(blob_builder)
	blob_builder.build_blob()


func _body_color() -> Color:
	match variant_type:
		ZombieData.Variant.GREEN, ZombieData.Variant.GORE_HORN:
			return ZombieData.GREEN_COLOR
		ZombieData.Variant.RED:
			return ZombieData.RED_COLOR
		ZombieData.Variant.PURPLE:
			return ZombieData.PURPLE_COLOR
	return ZombieData.random_zombie_color(rng)


func _setup_navigation() -> void:
	navigation_agent = NavigationAgent3D.new()
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = ZombieData.STOP_DIST
	navigation_agent.path_max_distance = 100.0
	navigation_agent.avoidance_enabled = true
	navigation_agent.radius = ZombieData.ZOMBIE_RADIUS * zombie_scale
	add_child(navigation_agent)


func _setup_attack_area() -> void:
	attack_area = Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = ZombieData.BITE_RANGE
	shape.shape = sphere
	attack_area.add_child(shape)
	attack_area.collision_layer = 0
	attack_area.collision_mask = 2  # Player layer
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)
	add_child(attack_area)


func _setup_timers() -> void:
	bite_cooldown_timer = Timer.new()
	bite_cooldown_timer.one_shot = true
	bite_cooldown_timer.wait_time = ZombieData.ATTACK_COOLDOWN
	add_child(bite_cooldown_timer)


func _physics_process(dt: float) -> void:
	if not is_inside_tree():
		return
	
	# Knockback rides on after the hit
	_apply_knockback(dt)
	
	match state:
		ZombieData.State.DYING:
			_process_dying(dt)
		ZombieData.State.EMERGE:
			_process_emerge(dt)
		ZombieData.State.SLEEP:
			_process_sleep(dt)
		ZombieData.State.CORPSE:
			_process_corpse(dt)
		ZombieData.State.WAKE:
			_process_wake(dt)
		ZombieData.State.CHASE, ZombieData.State.DORMANT:
			_process_chase(dt)
	
	# Drip blood trail
	_process_bleeding(dt)


func _apply_knockback(dt: float) -> void:
	if abs(kvx) > 0.001 or abs(kvz) > 0.001:
		global_position.x += kvx * dt
		global_position.z += kvz * dt
		var decay := exp(-ZombieData.KNOCKBACK_DECAY * dt)
		kvx *= decay
		kvz *= decay
		if Vector2(kvx, kvz).length() < ZombieData.KNOCKBACK_MIN:
			kvx = 0.0
			kvz = 0.0


func _process_dying(dt: float) -> void:
	dead_t += dt
	if blob_builder:
		blob_builder.rotation.x = minf(dead_t * 4.0, PI / 2.0)
		if dead_t > ZombieData.CORPSE_SINK_START:
			blob_builder.position.y -= dt * ZombieData.CORPSE_SINK_SPEED
	if dead_t > ZombieData.CORPSE_SINK_TIME:
		queue_free()


func _process_emerge(dt: float) -> void:
	emerge_t += dt
	var t := minf(emerge_t / ZombieData.EMERGE_DURATION, 1.0)
	var gy := _ground_height(global_position.x, global_position.z)
	global_position.y = gy - 1.5 * (1.0 - t)
	rotation.y = _yaw_to_target()
	
	if blob_builder and blob_builder.arms.size() >= 2:
		blob_builder.arms[0].rotation.x = -2.7 + t * 1.3
		blob_builder.arms[1].rotation.x = -2.3 + t * 0.9
	
	# Dirt particles
	if rng.randf() < 0.25:
		pass  # TODO: spawn dirt particles
	
	if t >= 1.0:
		state = ZombieData.State.CHASE


func _process_sleep(_dt: float) -> void:
	var gy := _ground_height(global_position.x, global_position.z)
	global_position.y = gy + 0.05
	if blob_builder:
		blob_builder.rotation.x = -1.45
	
	if _nearest_player_dist() < ZombieData.WAKE_DISTANCE:
		state = ZombieData.State.WAKE
		emerge_t = 0.0


func _process_corpse(_dt: float) -> void:
	var gy := _ground_height(global_position.x, global_position.z)
	global_position.y = gy + 0.05
	if blob_builder:
		blob_builder.rotation.x = -1.45
	
	# Rotten One's sickness can stir corpses
	if _rot_on_block() and _nearest_player_dist() < ZombieData.CORPSE_WAKE_DISTANCE:
		state = ZombieData.State.WAKE
		emerge_t = 0.0
		hp = maxf(hp, (7.0 + rng.randf() * 5.0) * zombie_scale)


func _process_wake(dt: float) -> void:
	emerge_t += dt
	var t := minf(emerge_t / ZombieData.WAKE_DURATION, 1.0)
	var gy := _ground_height(global_position.x, global_position.z)
	if blob_builder:
		blob_builder.rotation.x = -1.45 * (1.0 - t)
	global_position.y = gy + 0.05 * (1.0 - t)
	
	if t >= 1.0:
		state = ZombieData.State.CHASE
		if blob_builder:
			blob_builder.rotation.x = 0.0


func _process_chase(dt: float) -> void:
	var prev_x := global_position.x
	var prev_z := global_position.z
	
	_pick_target()
	_update_navigation(dt)
	_update_attack(dt)
	_step_physics(dt)
	_animate_walk(dt)
	_animate_head(dt)
	_animate_rot_gore()
	_process_groans(dt)
	
	# Smooth velocity for gunners
	var inv := 1.0 / maxf(dt, 0.001)
	vx = lerpf(vx, (global_position.x - prev_x) * inv, 0.25)
	vz = lerpf(vz, (global_position.z - prev_z) * inv, 0.25)


func _pick_target() -> void:
	if blind:
		_pick_blind_target()
	else:
		_pick_sighted_target()


func _pick_blind_target() -> void:
	var heard := GameState.time - _last_shot_time() < ZombieData.BLIND_SHOT_HEAR_RANGE and _last_shot_time() > shot_ignore_t
	
	if heard:
		current_target_pos = _last_shot_position()
		has_target = true
		surrounding = false
		if global_position.distance_to(current_target_pos) < ZombieData.BLIND_SHOT_CLOSE:
			shot_ignore_t = _last_shot_time()
			_wander_target()
	else:
		_wander_target()


func _wander_target() -> void:
	wander_t -= get_physics_process_delta_time()
	if wander_t <= 0.0:
		wander_t = rng.randf_range(ZombieData.BLIND_WANDER_TIME_MIN, ZombieData.BLIND_WANDER_TIME_MAX)
		wander_yaw = rng.randf() * TAU
		repathed = true
	current_target_pos = global_position + Vector3(sin(wander_yaw), 0, cos(wander_yaw)) * ZombieData.BLIND_WANDER_RANGE
	has_target = true
	surrounding = false


func _pick_sighted_target() -> void:
	var best_dist: float = INF
	var best_pos: Vector3 = Vector3.ZERO
	has_target = false
	surrounding = false
	
	# Player first
	if target_player and not _is_player_dead_or_downed(target_player):
		var d := global_position.distance_to(target_player.global_position)
		if d < best_dist:
			best_dist = d
			best_pos = target_player.global_position
			has_target = true
	
	# Companions
	if target_companion and not _is_companion_downed(target_companion):
		var d := global_position.distance_to(target_companion.global_position)
		if d < best_dist:
			best_dist = d
			best_pos = target_companion.global_position
			has_target = true
	
	if has_target:
		current_target_pos = best_pos


func _update_navigation(dt: float) -> void:
	if not has_target or is_boss:
		# Bosses path directly (simple chase)
		return
	
	var dx := current_target_pos.x - global_position.x
	var dz := current_target_pos.z - global_position.z
	var dist := sqrt(dx * dx + dz * dz)
	
	blocked = false
	var stop_dist := ZombieData.SURROUND_STOP_DIST if surrounding else ZombieData.STOP_DIST
	
	if dist > stop_dist and dist < INF:
		var sp := move_speed
		if dist < ZombieData.SPEED_CLOSE_DIST:
			sp *= ZombieData.SPEED_CLOSE_MULT
		if blind:
			sp *= ZombieData.SPEED_WANDER_MULT
		if is_boss and dash_t > 0.0:
			sp *= 5.0
		
		var nx := global_position.x + dx / dist * sp * dt
		var nz := global_position.z + dz / dist * sp * dt
		
		# Separation from other zombies
		for other in _nearby_zombies():
			if other == self or other.state == ZombieData.State.DYING:
				continue
			var sx := nx - other.global_position.x
			var sz := nz - other.global_position.z
			var sd := sqrt(sx * sx + sz * sz)
			if sd < ZombieData.ZOMBIE_SEPARATION and sd > 0.001:
				nx += sx / sd * (ZombieData.ZOMBIE_SEPARATION - sd) * ZombieData.ZOMBIE_SEP_FORCE
				nz += sz / sd * (ZombieData.ZOMBIE_SEPARATION - sd) * ZombieData.ZOMBIE_SEP_FORCE
		
		var ox := global_position.x
		var oz := global_position.z
		global_position.x = nx
		global_position.z = nz
		
		# Check if movement was blocked
		var moved := sqrt((nx - ox) * (nx - ox) + (nz - oz) * (nz - oz))
		blocked = moved < sp * dt * ZombieData.BLOCKED_THRESHOLD
		
		walk_phase += dt * move_speed * ZombieData.WALK_PHASE_SPEED
		step_t -= dt * move_speed
		if step_t <= 0.0:
			step_t = ZombieData.STEP_INTERVAL
	
	# Face target
	if dist < INF:
		var target_yaw := atan2(dx, dz)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-6.0 * dt))


func _update_attack(dt: float) -> void:
	attack_t -= dt
	if punch_t > 0.0:
		punch_t -= dt
	
	var prey_dist := global_position.distance_to(current_target_pos) if has_target else INF
	
	# Reach / claw wave
	var engaging := not is_boss and prey_dist < ZombieData.ENGAGE_DIST and attack_t < ZombieData.ENGAGE_ATTACK_THRESH
	var reaching := not is_boss and attack_t < ZombieData.REACH_ATTACK_THRESH and (surrounding or engaging or (blocked and prey_dist < ZombieData.REACH_MAX_DIST) or (prey_dist <= ZombieData.REACH_MIN_DIST and prey_dist > ZombieData.REACH_FAR_DIST and prey_dist < ZombieData.REACH_MAX_DIST))
	
	reach_t = clampf(reach_t + (1.0 if reaching else -1.0) * dt * ZombieData.CLAW_FADE_SPEED, 0.0, 1.0)
	if reach_t > 0.01:
		claw_phase += dt * ZombieData.CLAW_SPEED
	
	# Bite
	if attack_t <= 0.0 and has_target:
		var reach := ZombieData.BOSS_BITE_RANGE if is_boss else ZombieData.BITE_RANGE
		var v_reach := ZombieData.BOSS_BITE_V_REACH if is_boss else ZombieData.BITE_V_REACH
		
		if target_player and not _is_player_dead_or_downed(target_player):
			var pd := global_position.distance_to(target_player.global_position)
			var vd := absf(target_player.global_position.y - global_position.y)
			if pd < reach and vd < v_reach:
				_do_bite(target_player, pd)
		elif target_companion and not _is_companion_downed(target_companion):
			var cd := global_position.distance_to(target_companion.global_position)
			if cd < reach:
				_do_bite_companion(target_companion)


func _do_bite(target: Node3D, dist: float) -> void:
	attack_t = ZombieData.BOSS_ATTACK_COOLDOWN if is_boss else ZombieData.ATTACK_COOLDOWN
	
	if not is_boss and not arm_gone[0] and not arm_gone[1] and rng.randf() < ZombieData.PUNCH_CHANCE:
		# Rare haymaker
		punch_t = 0.34
		var dmg := rng.randf_range(ZombieData.PUNCH_DAMAGE_MIN, ZombieData.PUNCH_DAMAGE_MAX)
		zombie_attacked.emit(target, dmg * bite_mult)
	else:
		var dmg: float
		if is_boss:
			dmg = rng.randf_range(ZombieData.BOSS_BITE_DAMAGE_MIN, ZombieData.BOSS_BITE_DAMAGE_MAX)
		else:
			dmg = rng.randf_range(ZombieData.BITE_DAMAGE_MIN, ZombieData.BITE_DAMAGE_MAX)
		zombie_attacked.emit(target, dmg * bite_mult)


func _do_bite_companion(target: Node3D) -> void:
	attack_t = ZombieData.BOSS_ATTACK_COOLDOWN if is_boss else ZombieData.ATTACK_COOLDOWN
	var dmg: float
	if is_boss:
		dmg = 22.0
	else:
		dmg = 7.0 + rng.randf() * 5.0
	zombie_attacked.emit(target, dmg * bite_mult)


func _step_physics(dt: float) -> void:
	if is_boss:
		# Bosses keep to the dirt
		global_position.y = _ground_height(global_position.x, global_position.z)
		return
	
	var sup_y := _support_top(global_position.x, global_position.z, feet_y)
	
	if grounded:
		if sup_y < feet_y - 0.1:
			grounded = false
			vy = 0.0
		else:
			feet_y = sup_y
	else:
		vy -= ZombieData.GRAVITY * dt
		feet_y += vy * dt
		if vy <= 0.0 and feet_y <= sup_y:
			feet_y = sup_y
			vy = 0.0
			grounded = true
	
	global_position.y = feet_y


func _animate_walk(_dt: float) -> void:
	if not blob_builder:
		return
	
	var sw := sin(walk_phase)
	
	# Legs
	if blob_builder.legs.size() >= 2:
		blob_builder.legs[0].rotation.x = sw * ZombieData.LEG_SWING_AMP
		blob_builder.legs[1].rotation.x = -sw * ZombieData.LEG_SWING_AMP
	
	# Arms — shamble or claw
	var a0 := ZombieData.ARM_SWING_BASE + sw * ZombieData.ARM_SWING_AMP
	var a1 := ZombieData.ARM_SWING_BASE - sw * ZombieData.ARM_SWING_AMP
	
	if reach_t > 0.01:
		var cp := claw_phase
		var claw0 := ZombieData.CLAW_ARM_RAISE + sin(cp) * ZombieData.CLAW_ARM_SWING
		var claw1 := ZombieData.CLAW_ARM_RAISE + sin(cp + PI) * ZombieData.CLAW_ARM_SWING
		a0 = a0 * (1.0 - reach_t) + claw0 * reach_t
		a1 = a1 * (1.0 - reach_t) + claw1 * reach_t
	
	# Punch
	if punch_t > 0.0 and blob_builder.arms.size() >= 1:
		a0 = -PI / 2.0 - (1.0 - punch_t / 0.34) * 0.6
	
	if blob_builder.arms.size() >= 2:
		blob_builder.arms[0].rotation.x = a0
		blob_builder.arms[1].rotation.x = a1
	
	# Lunge
	var lunge := 0.0
	if attack_t > 0.62:
		lunge = (attack_t - 0.62) * 3.0
	blob_builder.wob.rotation.x = 0.15 + lunge * ZombieData.LUNGE_AMOUNT
	
	# Wobble
	var wobble := sw * 0.05
	blob_builder.wob.scale = Vector3(1.0 + wobble, 1.0 - wobble, 1.0 + wobble)


func _animate_head(dt: float) -> void:
	if not blob_builder or not blob_builder.head:
		return
	
	var head_node := blob_builder.head
	var mouth: Node3D = null  # TODO: track mouth mesh
	
	var rx: float = 0.0
	var ry: float = 0.0
	var rz: float = 0.0
	var grow: float = 0.0
	
	# Blind double-take on repath
	if blind and repathed:
		repathed = false
		head_anim = { "type": "double", "t": 0.0, "dur": 0.6 }
		head_t = rng.randf_range(1.4, 3.4)
	
	var anim: Dictionary = head_anim
	if not anim.is_empty():
		anim.t += dt
		var p := anim.t / anim.dur
		var e := 1.0 - p
		
		match anim.get("type", ""):
			"twitch":
				ry = sin(anim.t * 46.0) * 0.14 * e
				rx = sin(anim.t * 40.0) * 0.07 * e
			"shake":
				ry = sin(anim.t * 30.0) * 0.22 * e
				rz = cos(anim.t * 30.0) * 0.06 * e
			"double":
				ry = sin(p * PI) * (0.5 if p < 0.5 else -0.28)
				rx = sin(p * PI) * 0.08
			"gape":
				var open_amt := minf(minf(anim.t / 0.35, (anim.dur - anim.t) / 0.3), 1.0)
				grow = maxf(open_amt, 0.0) * (1.6 + sin(anim.t * 22.0) * 0.28)
				ry = sin(anim.t * 17.0) * 0.05 * maxf(open_amt, 0.0)
		
		if anim.t >= anim.dur:
			head_anim = {}
	else:
		head_t -= dt
		if head_t <= 0.0:
			_pick_head_anim()
	
	var base_sway := sin(walk_phase * 0.5) * 0.18
	if head_node:
		head_node.rotation.x = rx
		head_node.rotation.y = ry
		head_node.rotation.z = base_sway + rz


func _pick_head_anim() -> void:
	var wants: bool
	var engaging := not is_boss and global_position.distance_to(current_target_pos) < ZombieData.ENGAGE_DIST and attack_t < ZombieData.ENGAGE_ATTACK_THRESH
	
	if is_boss4:
		wants = true
	else:
		wants = bleeding or engaging or (not droopy and rng.randf() < ZombieData.HEAD_ANIM_CHANCE)
	
	if wants:
		head_anim = _random_head_anim()
		if is_boss4:
			head_t = rng.randf_range(ZombieData.HEAD_ANIM_BOSS4_MIN, ZombieData.HEAD_ANIM_BOSS4_MAX)
		elif engaging:
			head_t = rng.randf_range(ZombieData.HEAD_ANIM_ENGAGING_MIN, ZombieData.HEAD_ANIM_ENGAGING_MAX)
		elif bleeding:
			head_t = rng.randf_range(ZombieData.HEAD_ANIM_BLEEDING_MIN, ZombieData.HEAD_ANIM_BLEEDING_MAX)
		else:
			head_t = rng.randf_range(ZombieData.HEAD_ANIM_IDLE_MIN, ZombieData.HEAD_ANIM_IDLE_MAX)
	else:
		head_t = rng.randf_range(1.5, 4.0)


func _random_head_anim() -> Dictionary:
	var r := rng.randf()
	if r < 0.4:
		return { "type": "twitch", "t": 0.0, "dur": 0.35 }
	elif r < 0.68:
		return { "type": "gape", "t": 0.0, "dur": 1.0 }
	elif r < 0.82:
		return { "type": "shake", "t": 0.0, "dur": 0.4 }
	return { "type": "double", "t": 0.0, "dur": 0.6 }


func _animate_rot_gore() -> void:
	# Heart beat animation would be driven from blob_builder.rot_heart node
	# Eye swing animation would be driven from blob_builder.hang_eye node
	pass


func _process_groans(dt: float) -> void:
	groan_t -= dt
	if groan_t < 0.0:
		groan_t = rng.randf_range(ZombieData.GROAN_INTERVAL_MIN, ZombieData.GROAN_INTERVAL_MAX)
		# TODO: play groan sound 3D


func _process_bleeding(dt: float) -> void:
	if not bleeding:
		return
	drip_t -= dt
	if drip_t <= 0.0:
		drip_t = rng.randf_range(0.22, 0.42)
		# TODO: spawn ground splat


# ── Damage system ──

func damage_zombie(dmg: float, knock_dir: Vector3, knock_amount: float, is_headshot: bool, weapon_data: Dictionary = {}) -> void:
	if state == ZombieData.State.DYING or vanished:
		return
	
	# Boss shield check
	if is_boss and _boss_shielded():
		_flash_green()
		return
	
	# Wake boss on hit
	if is_boss:
		_wake_boss()
	
	# Wake sleeper on hit
	if state == ZombieData.State.SLEEP:
		state = ZombieData.State.WAKE
		emerge_t = 0.0
	
	var is_head_gib := weapon_data.get("gib", false) or brain_exposed
	
	# Head gib = instant kill
	if is_headshot and not head_gone and not is_boss and is_head_gib:
		kill_zombie(knock_dir, true)
		return
	
	hp -= dmg
	_flash_red()
	
	# Knockback
	var kb := ZombieData.BOSS_KNOCKBACK_MULT if is_boss else 1.0
	global_position.x += knock_dir.x * knock_amount * ZombieData.KNOCKBACK_POS_MULT * kb
	global_position.z += knock_dir.z * knock_amount * ZombieData.KNOCKBACK_POS_MULT * kb
	kvx += knock_dir.x * knock_amount * ZombieData.KNOCKBACK_IMPULSE_MULT * kb
	kvz += knock_dir.z * knock_amount * ZombieData.KNOCKBACK_IMPULSE_MULT * kb
	
	bleeding = true
	# TODO: spawn blood particles
	
	# Headshot skull crack
	if is_headshot and not brain_exposed and not is_boss and not is_fbi:
		var w := weapon_data.get("id", "")
		if w == "pistol":
			skull_hits += 1
			if skull_hits >= 2:
				_expose_brain()
			elif rng.randf() < 0.25:
				_add_hanging_eye()
		else:
			_expose_brain()
	
	zombie_damaged.emit(self, dmg, knock_dir, is_headshot)
	
	if hp <= 0.0:
		kill_zombie(knock_dir, is_headshot and not is_fbi and (weapon_data.get("gib", false) or brain_exposed))


func kill_zombie(knock_dir: Vector3, head_pop: bool) -> void:
	if state == ZombieData.State.DYING:
		return
	state = ZombieData.State.DYING
	dead_t = 0.0
	hp = 0.0
	died_pop = head_pop
	
	# TODO: spawn blood, play splat sound
	if head_pop:
		_pop_head(knock_dir)
	
	zombie_killed.emit(self, head_pop)


func _pop_head(knock_dir: Vector3) -> void:
	if head_gone or not blob_builder:
		return
	head_gone = true
	if blob_builder.head:
		blob_builder.head.visible = false
	# TODO: spawn gibs, blood, play headpop sound


func _expose_brain() -> void:
	if brain_exposed:
		return
	brain_exposed = true
	# TODO: show brain mesh, hide skull


func _add_hanging_eye() -> void:
	rot_e = true
	# TODO: add rot gore hanging eye to blob


func _flash_red() -> void:
	# TODO: flash blob red on damage
	pass


func _flash_green() -> void:
	# TODO: flash blob green on shielded hit
	pass


func _wake_boss() -> void:
	if state != ZombieData.State.DORMANT:
		return
	state = ZombieData.State.CHASE
	# TODO: boss bar, toast, sfx, camera shake


func _boss_shielded() -> bool:
	# Check if any horn-wave guard is still alive
	for z in _nearby_zombies():
		if z != self and z.horn_wave and z.state != ZombieData.State.DYING:
			return true
	return false


# ── Helpers ──

func _yaw_to_target() -> float:
	if has_target:
		var dx := current_target_pos.x - global_position.x
		var dz := current_target_pos.z - global_position.z
		return atan2(dx, dz)
	return rotation.y


func _ground_height(x: float, z: float) -> float:
	# Stub — replace with actual terrain height lookup
	return 0.0


func _support_top(x: float, z: float, current_y: float) -> float:
	# Stub — replace with actual terrain/world support surface lookup
	return _ground_height(x, z)


func _nearest_player_dist() -> float:
	if target_player:
		return global_position.distance_to(target_player.global_position)
	return INF


func _is_player_dead_or_downed(p: Node3D) -> bool:
	if p.has_method("is_dead"):
		return p.is_dead()
	if p.has_method("is_downed"):
		return p.is_downed()
	return false


func _is_companion_downed(c: Node3D) -> bool:
	if c.has_method("is_downed"):
		return c.is_downed()
	return false


func _last_shot_time() -> float:
	# Stub — read from GameState or SignalBus
	return -999.0


func _last_shot_position() -> Vector3:
	# Stub
	return Vector3.ZERO


func _rot_on_block() -> bool:
	# Stub — check if Rotten One has risen
	return false


func _nearby_zombies() -> Array[ZombieAI]:
	# Stub — return all active zombies from the parent node or group
	return []


# ── Attack area callbacks ──

func _on_attack_area_body_entered(body: Node3D) -> void:
	if body == target_player:
		pass  # Target in range — bite will trigger next frame
	pass


func _on_attack_area_body_exited(body: Node3D) -> void:
	if body == target_player:
		pass
	pass
