extends Node3D
class_name ZombieSpawner

# ── Zombie Spawner System ──
# Time-based spawning with interval/max, variant selection, grave spots,
# runner spawns, fog-line spawning, cleanup phase, and churchyard vigil.
# Mirrors the original game.js updateSpawner.

# ── Configuration ──
@export var enabled: bool = true
@export var spawn_rate: float = 1.0           # maps to settings.zombieSpawn
@export var gore_horde: bool = false          # Extra Gore maxed
@export var extra_gore: float = 0.0           # extraGore slider value

# ── Spawn timer ──
var spawn_t: float = 2.0
var game_time: float = 0.0

# ── Grave spots (set by world builder) ──
var grave_spots: Array[Vector2] = []

# ── Active zombies list ──
var zombies: Array[ZombieAI] = []

# ── Spawner caps ──
var _current_max: int = 4
var _current_interval: float = 4.2

# ── Special locations ──
var churchyard_position: Vector2 = Vector2.ZERO
const CHURCHYARD_NEAR: float = 42.0

# ── Boss state references ──
var boss_spawned_2: bool = false
var boss_defeated_2: bool = false
var boss_spawned_4: bool = false
var boss_defeated_4: bool = false
var jelly_awake: bool = false

# ── Power scaling ──
const POWER_SCALE_TIME: float = 240.0

# ── RNG ──
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ── Signal ──
signal zombie_spawned(zombie: ZombieAI)
signal spawner_paused
signal spawner_resumed


func _ready() -> void:
	rng.randomize()
	spawn_t = rng.randf_range(2.0, 5.0)


func _process(dt: float) -> void:
	if not enabled:
		return
	
	game_time += dt
	_update_caps()
	spawn_t -= dt
	
	if spawn_t <= 0.0 and zombies.size() < _current_max:
		_try_spawn()


func _update_caps() -> void:
	var horde_mult: float = ZombieData.SPAWNER_GORE_HORDE_MULT if gore_horde else 1.0
	_current_max = mini(
		ZombieData.SPAWNER_HARD_CAP,
		int(round((ZombieData.SPAWNER_BASE_MAX + game_time / ZombieData.SPAWNER_MAX_PER_TIME + GameState.kills / ZombieData.SPAWNER_MAX_PER_KILL) * spawn_rate * horde_mult))
	)
	_current_interval = maxf(
		ZombieData.SPAWNER_MIN_INTERVAL,
		(ZombieData.SPAWNER_BASE_INTERVAL - game_time / ZombieData.SPAWNER_INTERVAL_DECAY) / spawn_rate / horde_mult
	)


func _try_spawn() -> void:
	# Guard: don't spawn during celebration or if jelly has woken
	if GameState.celebrate_t > 0.0 or jelly_awake:
		return
	
	# Guard: cleanup phase — don't exceed clear target
	if GameState.cleanup:
		var alive := _count_alive()
		if GameState.kills + alive >= GameState.clear_target:
			return
	
	# Churchyard vigil: only spawn if someone is near
	var vigil := _churchyard_vigil()
	if vigil:
		var nearest := _nearest_player_dist_to(churchyard_position)
		if nearest > CHURCHYARD_NEAR:
			return
	
	spawn_t = _current_interval
	
	var power := 1.0 + game_time / POWER_SCALE_TIME
	
	# Grave spawns — some claw up out of the mounds
	if grave_spots.size() > 0 and (vigil or rng.randf() < ZombieData.SPAWN_GRAVE_CHANCE):
		var gs := grave_spots[rng.randi_range(0, grave_spots.size() - 1)]
		var d := _nearest_player_dist_to(gs)
		if d > ZombieData.GRAVE_SPAWN_RANGE_NEAR and d < ZombieData.GRAVE_SPAWN_RANGE_FAR:
			_spawn_at(gs.x, gs.y, power, ZombieData.SpawnMode.GRAVE, ZombieData.Variant.NONE)
			return
	
	# During vigil, only graves spawn
	if vigil:
		return
	
	# Street spawn
	var runner := rng.randf() < ZombieData.SPAWN_RUNNER_CHANCE
	var anchor := _spawn_anchor()
	
	var x: float
	var z: float
	var ok: bool = false
	
	for _tries in range(8):
		if ok:
			break
		var ang := rng.randf() * TAU
		var d: float
		if runner:
			d = _fog_far() + ZombieData.SPAWN_FOG_PADDING + rng.randf() * ZombieData.SPAWN_FOG_SPREAD
		else:
			d = ZombieData.SPAWN_NEAR_MIN + rng.randf() * (ZombieData.SPAWN_NEAR_MAX - ZombieData.SPAWN_NEAR_MIN)
		x = anchor.x + sin(ang) * d
		z = anchor.y + cos(ang) * d
		
		# Check spawn validity
		if not _is_valid_spawn(x, z):
			continue
		
		ok = true
	
	if not ok:
		return
	
	# Gore-horde brutes while Extra Gore is maxed
	if gore_horde and not runner and rng.randf() < ZombieData.SPAWN_GORE_HORN_CHANCE:
		_spawn_at(x, z, power, ZombieData.SpawnMode.GRAVE, ZombieData.Variant.GORE_HORN)
		return
	
	var mode := ZombieData.SpawnMode.GRAVE
	if runner:
		mode = ZombieData.SpawnMode.RUNNER
	elif GameState.cleanup:
		mode = ZombieData.SpawnMode.GRAVE
	elif _on_road(x, z) or rng.randf() < ZombieData.SPAWN_ROAD_SLEEPER_CHANCE:
		if _boss_phase():
			mode = ZombieData.SpawnMode.GRAVE
		else:
			mode = ZombieData.SpawnMode.SLEEPER
	
	_spawn_at(x, z, power, mode, ZombieData.Variant.NONE)
	
	# Sleepers come doubled with a corpse
	if mode == ZombieData.SpawnMode.SLEEPER:
		var corpse_count := 0
		for zz in zombies:
			if zz.state == ZombieData.State.CORPSE:
				corpse_count += 1
		
		if corpse_count < 6:
			var ca := rng.randf() * TAU
			var cd := 1.5 + rng.randf() * 1.4
			var cxx := x + sin(ca) * cd
			var czz := z + cos(ca) * cd
			
			var clear := true
			for zz in zombies:
				if zz.state != ZombieData.State.DYING:
					if Vector2(zz.global_position.x - cxx, zz.global_position.z - czz).length() < 1.1:
						clear = false
						break
			
			if clear and _is_valid_spawn(cxx, czz):
				_spawn_at(cxx, czz, power, ZombieData.SpawnMode.CORPSE, ZombieData.Variant.NONE)


func _spawn_at(x: float, z: float, power_scale: float, mode: ZombieData.SpawnMode, variant: ZombieData.Variant) -> ZombieAI:
	var zombie := _create_zombie(x, z, power_scale, mode, variant)
	if zombie:
		add_child(zombie)
		zombies.append(zombie)
		zombie.zombie_killed.connect(_on_zombie_killed.bind(zombie))
		zombie_spawned.emit(zombie)
	return zombie


func _create_zombie(x: float, z: float, power_scale: float, mode: ZombieData.SpawnMode, variant: ZombieData.Variant) -> ZombieAI:
	var zombie := ZombieAI.new()
	zombie.spawn_mode = mode
	zombie.variant_type = variant
	zombie.gore_horn = variant == ZombieData.Variant.GORE_HORN
	
	var is_green := variant == ZombieData.Variant.GREEN or variant == ZombieData.Variant.GORE_HORN
	var is_red := variant == ZombieData.Variant.RED
	var is_purple := variant == ZombieData.Variant.PURPLE
	var is_corpse := mode == ZombieData.SpawnMode.CORPSE
	var is_runner := mode == ZombieData.SpawnMode.RUNNER
	
	# Scale
	zombie.zombie_scale = ZombieData.random_scale(rng, is_green)
	
	# Traits
	zombie.droopy = not is_corpse and not is_purple and not is_red and not is_green and rng.randf() < ZombieData.DROOPY_CHANCE
	zombie.brain_exposed = (is_corpse and rng.randf() < ZombieData.BRAIN_CORPSE_CHANCE) or rng.randf() < ZombieData.BRAIN_EXPOSED_CHANCE
	zombie.blind = not is_corpse and not is_purple and not is_red and not is_green and rng.randf() < ZombieData.BLIND_CHANCE
	zombie.bleeding = is_corpse or (_extra_gore_on() and rng.randf() < ZombieData.WOUNDED_EXTRA_GORE_CHANCE + extra_gore * 0.5)
	
	var variant_mult := is_purple or is_red or is_green
	
	# HP
	if is_corpse:
		zombie.hp = ZombieData.corpse_hp(rng, zombie.zombie_scale)
	else:
		zombie.hp = ZombieData.random_hp(rng, zombie.zombie_scale, power_scale, variant_mult)
	zombie.max_hp = zombie.hp
	
	# Speed
	zombie.move_speed = ZombieData.random_speed(rng, power_scale, variant, is_runner)
	
	# Bite mult
	zombie.bite_mult = ZombieData.BITE_MULT_RED_GREEN if (is_red or is_green) else 1.0
	
	# Horns
	zombie.horn_wave = variant == ZombieData.Variant.PURPLE or variant == ZombieData.Variant.RED or variant == ZombieData.Variant.GREEN
	zombie.horn_vis = variant != ZombieData.Variant.NONE and variant != ZombieData.Variant.GORE_HORN
	if variant == ZombieData.Variant.GORE_HORN:
		zombie.horn_vis = true  # Horned appearance but no shield
	
	# Far-born flag for runners
	zombie.far_born = is_runner
	
	# Spawn-in missing arm
	if rng.randf() < (ZombieData.ARM_GONE_CORPSE_CHANCE if is_corpse else ZombieData.ARM_GONE_CHANCE):
		var idx := 0 if rng.randf() < 0.5 else 1
		zombie.arm_gone[idx] = true
	
	# Start state
	match mode:
		ZombieData.SpawnMode.GRAVE:
			zombie.state = ZombieData.State.EMERGE
		ZombieData.SpawnMode.SLEEPER:
			zombie.state = ZombieData.State.SLEEP
		ZombieData.SpawnMode.CORPSE:
			zombie.state = ZombieData.State.CORPSE
		ZombieData.SpawnMode.RUNNER, ZombieData.SpawnMode.POP:
			zombie.state = ZombieData.State.CHASE
	
	zombie.global_position = Vector3(x, _ground_height(x, z), z)
	zombie.feet_y = _ground_height(x, z)
	zombie.rotation.y = rng.randf() * TAU
	
	return zombie


# ── Prefab spawning (for boss waves, specific placements) ──

func spawn_wave_zombie(x: float, z: float, power_scale: float, variant: ZombieData.Variant, horns: bool = false, shield: bool = false) -> ZombieAI:
	var z_ai := _create_zombie(x, z, power_scale, ZombieData.SpawnMode.POP, variant)
	if z_ai:
		z_ai.horn_wave = horns or shield
		z_ai.horn_vis = horns
		add_child(z_ai)
		zombies.append(z_ai)
		z_ai.zombie_killed.connect(_on_zombie_killed.bind(z_ai))
		zombie_spawned.emit(z_ai)
	return z_ai


# ── Despawn distant zombies ──

func cull_distant_zombies(player_positions: Array[Vector3]) -> void:
	var fog_far := _fog_far()
	
	for i in range(zombies.size() - 1, -1, -1):
		var z := zombies[i]
		if z.is_boss or z.is_fbi:
			continue
		
		var nearest := INF
		for pp in player_positions:
			var d := Vector2(z.global_position.x - pp.x, z.global_position.z - pp.z).length()
			nearest = minf(nearest, d)
		
		var leash := fog_far + (ZombieData.DESPAWN_FARBORN_OFFSET if z.far_born else ZombieData.DESPAWN_FOG_OFFSET)
		if nearest > leash:
			_remove_zombie(z, i)


func _remove_zombie(z: ZombieAI, idx: int) -> void:
	zombies.remove_at(idx)
	z.queue_free()


func _on_zombie_killed(zombie: ZombieAI, _head_pop: bool) -> void:
	# Zombie will self-remove after sink animation
	# We track kills in GameState
	GameState.kills += 1
	# Remove from active list after sink
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = ZombieData.CORPSE_SINK_TIME + 0.1
	t.timeout.connect(_remove_dead_zombie.bind(zombie, t))
	add_child(t)
	t.start()


func _remove_dead_zombie(z: ZombieAI, timer: Timer) -> void:
	var idx := zombies.find(z)
	if idx >= 0:
		zombies.remove_at(idx)
	timer.queue_free()


# ── Helpers ──

func _count_alive() -> int:
	var n := 0
	for z in zombies:
		if z.state != ZombieData.State.DYING:
			n += 1
	return n


func _churchyard_vigil() -> bool:
	return boss_spawned_2 and not boss_defeated_2  # Crimson One still sleeping


func _boss_phase() -> bool:
	# Any boss spawned
	return true  # Simplified — wire to actual boss state


func _spawn_anchor() -> Vector2:
	# Return position of a random player to spawn near
	var player_node := _get_player_node()
	if player_node:
		return Vector2(player_node.global_position.x, player_node.global_position.z)
	return Vector2.ZERO


func _get_player_node() -> Node3D:
	var tree := get_tree()
	if tree:
		var players := tree.get_nodes_in_group("player")
		if players.size() > 0:
			return players[rng.randi_range(0, players.size() - 1)]
	return null


func _fog_far() -> float:
	# Stub — return current fog far distance
	return 108.0


func _ground_height(x: float, z: float) -> float:
	# Stub — replace with actual terrain height lookup
	return 0.0


func _on_road(x: float, z: float) -> bool:
	# Stub — check if position is on a road
	return false


func _is_valid_spawn(x: float, z: float) -> bool:
	# Stub — check if spawn point is valid (not inside building, not in park)
	return true


func _nearest_player_dist_to(pos: Vector2) -> float:
	var best := INF
	var player := _get_player_node()
	if player:
		best = Vector2(player.global_position.x - pos.x, player.global_position.z - pos.y).length()
	return best


func _extra_gore_on() -> bool:
	# Stub
	return false


# ── Public API ──

func set_grave_spots(spots: Array[Vector2]) -> void:
	grave_spots = spots


func set_churchyard(x: float, z: float) -> void:
	churchyard_position = Vector2(x, z)


func pause_spawner() -> void:
	enabled = false
	spawner_paused.emit()


func resume_spawner() -> void:
	enabled = true
	spawner_resumed.emit()


func get_active_count() -> int:
	return _count_alive()


func get_total_zombies() -> int:
	return zombies.size()


func clear_all() -> void:
	for z in zombies:
		if is_instance_valid(z):
			z.queue_free()
	zombies.clear()
	game_time = 0.0
	spawn_t = 2.0
