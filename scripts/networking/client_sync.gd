extends Node
## Client-side sync: ghost interpolation, snapshot application, RPC handling.
##
## On the client, all non-local entities are "ghosts" -- interpolated copies of
## the host's authoritative state. Snapshots arrive at 10Hz and set lerp targets.
## Ghosts smoothly interpolate toward their targets each frame.
##
## Player pose is streamed to the host at 15Hz via the LobbyManager RPC layer.

const LERP_SPEED := 10.0
const ANGLE_LERP_SPEED := 12.0
const POSE_INTERVAL := 1.0 / 15.0

var lobby_manager: Node
var host_sync: Node

var pose_timer: float = 0.0
var _prev_x: float = 0.0
var _prev_z: float = 0.0

# Ghosts: nid -> Dictionary
var zombie_ghosts: Dictionary = {}
var actor_ghosts: Dictionary = {}     # key -> ActorGhost (key = "pN" or "aiID")
var recruit_ghosts: Dictionary = {}   # cousin_id -> RecruitGhost
var pickup_ghosts: Dictionary = {}    # nid -> PickupGhost
var crate_ghosts: Dictionary = {}     # nid -> CrateGhost
var crow_ghosts: Dictionary = {}      # nid -> CrowGhost

signal ghost_spawned(type: String, ghost: Dictionary)
signal ghost_removed(type: String, nid: int)
signal snapshot_applied(snap: Dictionary)
signal pose_sent(pose: Dictionary)
signal remote_pew_visualized(ghost: Dictionary, x: float, y: float, z: float, hit_pos: Vector3, weapon_id: String)
signal remote_emote_visualized(ghost: Dictionary, emote_index: int)


func _ready() -> void:
	set_process(false)


func setup(lobby: Node) -> void:
	lobby_manager = lobby
	_connect_signals()


func _connect_signals() -> void:
	if not lobby_manager:
		return
	var lm := lobby_manager
	if lm.has_signal("snapshot_received"):
		lm.snapshot_received.connect(apply_snapshot)
	if lm.has_signal("rpc_remote_pew"):
		lm.rpc_remote_pew.connect(_on_remote_pew)
	if lm.has_signal("rpc_remote_emote"):
		lm.rpc_remote_emote.connect(_on_remote_emote)
	if lm.has_signal("rpc_remote_pose"):
		lm.rpc_remote_pose.connect(_on_remote_pose)


func start_client_sync() -> void:
	pose_timer = 0.0
	set_process(true)


func stop_client_sync() -> void:
	set_process(false)
	clear_all_ghosts()


func _process(delta: float) -> void:
	var k := 1.0 - exp(-LERP_SPEED * delta)

	interpolate_actors(k, delta)
	interpolate_zombie_ghosts(k, delta)
	interpolate_crow_ghosts(k, delta)
	interpolate_recruit_ghosts(k, delta)
	interpolate_pickup_ghosts()
	interpolate_crate_ghosts()

	# Stream our pose to the host at 15Hz
	pose_timer -= delta
	if pose_timer <= 0.0:
		pose_timer = POSE_INTERVAL
		send_pose_update()


## ---- Snapshot application ----

func apply_snapshot(snap: Dictionary) -> void:
	snapshot_applied.emit(snap)

	if snap.has("ac"):
		_apply_actor_ghosts(snap["ac"])
	if snap.has("zb"):
		_apply_zombie_ghosts(snap["zb"])
	if snap.has("pk"):
		_apply_pickup_ghosts(snap["pk"])
	if snap.has("cr"):
		_apply_crate_ghosts(snap["cr"])
	if snap.has("cw"):
		_apply_crow_ghosts(snap["cw"])
	if snap.has("rc"):
		_apply_recruit_ghosts(snap["rc"])


## ---- Actor ghosts ----

func _apply_actor_ghosts(actors: Array) -> void:
	var seen: Dictionary = {}
	var my_num := get_my_player_num()

	for a in actors:
		var p: int = a.get("p", 0)
		if p == my_num:
			continue

		var key := ("p%d" % p) if p > 0 else ("ai%s" % a.get("c", ""))
		seen[key] = true

		if not actor_ghosts.has(key):
			_spawn_actor_ghost(key, a)
		else:
			_update_actor_ghost_target(key, a)

	var to_remove: Array = []
	for key in actor_ghosts:
		if not seen.has(key):
			to_remove.append(key)
	for key in to_remove:
		_remove_actor_ghost(key)


func _spawn_actor_ghost(key: String, a: Dictionary) -> void:
	var ghost: Dictionary = {
		"key": key,
		"cousin_id": a.get("c", ""),
		"player_num": a.get("p", 0),
		"weapon_id": a.get("wp", "fists"),
		"tx": a.get("x", 0.0),
		"tz": a.get("z", 0.0),
		"ty": a.get("y", 0.0),
		"tyw": a.get("yw", 0.0),
		"hp": a.get("hp", 100),
		"downed": a.get("dn", 0) == 1,
		"mv": a.get("mv", 0),
		"tar": a.get("ar", -PI / 2.0),
		"arS": -PI / 2.0,
		"tgs": a.get("gs", 1.0),
		"x": a.get("x", 0.0),
		"z": a.get("z", 0.0),
		"y": a.get("y", 0.0),
		"yw": a.get("yw", 0.0),
		"walk": 0.0,
		"meltT": 0.0,
		"gs": 1.0,
		"node": null,
	}
	actor_ghosts[key] = ghost
	ghost_spawned.emit("actor", ghost)


func _update_actor_ghost_target(key: String, a: Dictionary) -> void:
	var ghost: Dictionary = actor_ghosts[key]

	if a.get("c", "") != ghost["cousin_id"]:
		ghost["cousin_id"] = a.get("c", "")

	var dx := a.get("x", 0.0) - ghost["x"]
	var dz := a.get("z", 0.0) - ghost["z"]
	if absf(dx) > 25.0 or absf(dz) > 25.0:
		ghost["meltT"] = 0.5
		ghost["x"] = a.get("x", 0.0)
		ghost["z"] = a.get("z", 0.0)

	ghost["tx"] = a.get("x", 0.0)
	ghost["tz"] = a.get("z", 0.0)
	ghost["ty"] = a.get("y", 0.0)
	ghost["tyw"] = a.get("yw", 0.0)
	ghost["hp"] = a.get("hp", 100)
	ghost["downed"] = a.get("dn", 0) == 1
	ghost["mv"] = a.get("mv", 0)
	ghost["weapon_id"] = a.get("wp", "fists")
	ghost["tar"] = a.get("ar", -PI / 2.0)
	if a.has("gs"):
		ghost["tgs"] = a["gs"]


func _remove_actor_ghost(key: String) -> void:
	if actor_ghosts.has(key):
		actor_ghosts.erase(key)
		ghost_removed.emit("actor", hash(key))


func interpolate_actors(k: float, delta: float) -> void:
	for key in actor_ghosts:
		var g: Dictionary = actor_ghosts[key]

		if g["meltT"] > 0.0:
			g["meltT"] -= delta
			g["meltT"] = maxf(g["meltT"], 0.0)

		g["x"] = lerpf(g["x"], g["tx"], k)
		g["z"] = lerpf(g["z"], g["tz"], k)
		g["y"] = g["ty"]
		g["yw"] = _ang_lerpf(g["yw"], g["tyw"], k)

		var move_speed := 10.0 if g["mv"] == 1 else 0.0
		g["walk"] += delta * move_speed

		g["arS"] = lerpf(g["arS"], g["tar"], 1.0 - exp(-14.0 * delta))

		var gs_now: float = g.get("gs", 1.0)
		var gs_tgt: float = g.get("tgs", 1.0)
		if absf(gs_now - gs_tgt) > 0.03:
			g["gs"] = lerpf(gs_now, gs_tgt, 1.0 - exp(-6.0 * delta))


## ---- Zombie ghosts ----

func _apply_zombie_ghosts(zombies: Array) -> void:
	var seen: Dictionary = {}

	for zs in zombies:
		var nid: int = zs.get("i", 0)
		seen[nid] = true

		if not zombie_ghosts.has(nid):
			_spawn_zombie_ghost(nid, zs)
		else:
			_update_zombie_ghost_target(nid, zs)

	var to_remove: Array = []
	for nid in zombie_ghosts:
		if not seen.has(nid):
			var g: Dictionary = zombie_ghosts[nid]
			if g.get("state", "chase") != "dying":
				to_remove.append(nid)
	for nid in to_remove:
		_remove_zombie_ghost(nid)


func _spawn_zombie_ghost(nid: int, zs: Dictionary) -> void:
	var ghost: Dictionary = {
		"nid": nid,
		"tx": zs.get("x", 0.0),
		"tz": zs.get("z", 0.0),
		"tyw": zs.get("yw", 0.0),
		"scale": zs.get("sc", 1.0),
		"state": _state_from_code(zs.get("st", 0)),
		"is_boss": zs.get("bo", 0) == 1,
		"is_boss2": zs.get("b2", 0) == 1,
		"is_boss3": zs.get("b3", 0) == 1,
		"is_boss4": zs.get("b4", 0) == 1,
		"shielded": zs.get("sh", 0) == 1,
		"shield_guard": zs.get("gd", 0) == 1,
		"purple": zs.get("pu", 0) == 1,
		"red": zs.get("re", 0) == 1,
		"green": zs.get("gr", 0) == 1,
		"fbi": zs.get("fb", 0) == 1,
		"bluga": zs.get("bg", 0) == 1,
		"died_pop": zs.get("dp", 0) == 1,
		"x": zs.get("x", 0.0),
		"z": zs.get("z", 0.0),
		"yw": zs.get("yw", 0.0),
		"deadT": 0.0,
		"walk_phase": randf() * 9.0,
		"node": null,
	}
	zombie_ghosts[nid] = ghost
	ghost_spawned.emit("zombie", ghost)


func _update_zombie_ghost_target(nid: int, zs: Dictionary) -> void:
	var ghost: Dictionary = zombie_ghosts[nid]
	ghost["tx"] = zs.get("x", 0.0)
	ghost["tz"] = zs.get("z", 0.0)
	ghost["tyw"] = zs.get("yw", 0.0)
	ghost["shielded"] = zs.get("sh", 0) == 1

	var new_state := _state_from_code(zs.get("st", 0))
	if new_state == "dying" and ghost["state"] != "dying":
		ghost["state"] = "dying"
		ghost["deadT"] = 0.0
		if zs.get("dp", 0) == 1:
			ghost["died_pop"] = true


func _remove_zombie_ghost(nid: int) -> void:
	if zombie_ghosts.has(nid):
		zombie_ghosts.erase(nid)
		ghost_removed.emit("zombie", nid)


func interpolate_zombie_ghosts(k: float, delta: float) -> void:
	var to_remove: Array = []
	for nid in zombie_ghosts:
		var g: Dictionary = zombie_ghosts[nid]
		if g["state"] == "dying":
			g["deadT"] += delta
			if g["deadT"] > 2.4:
				to_remove.append(nid)
			continue

		g["x"] = lerpf(g["x"], g["tx"], k)
		g["z"] = lerpf(g["z"], g["tz"], k)
		g["yw"] = _ang_lerpf(g["yw"], g["tyw"], k)
		g["walk_phase"] += delta * 3.0

	for nid in to_remove:
		_remove_zombie_ghost(nid)


## ---- Pickup ghosts ----

func _apply_pickup_ghosts(pickups: Array) -> void:
	var seen: Dictionary = {}
	for p in pickups:
		var nid: int = p.get("i", 0)
		seen[nid] = true
		var kind := ""
		match p.get("k", 0):
			0: kind = "ammo"
			1: kind = "medkit"
			2: kind = "bestjelly"

		if not pickup_ghosts.has(nid):
			var ghost: Dictionary = {
				"nid": nid, "kind": kind,
				"x": p.get("x", 0.0), "z": p.get("z", 0.0),
				"node": null,
			}
			pickup_ghosts[nid] = ghost
			ghost_spawned.emit("pickup", ghost)

	var to_remove: Array = []
	for nid in pickup_ghosts:
		if not seen.has(nid):
			to_remove.append(nid)
	for nid in to_remove:
		pickup_ghosts.erase(nid)
		ghost_removed.emit("pickup", nid)


func interpolate_pickup_ghosts() -> void:
	pass  # Static entities


## ---- Crate ghosts ----

func _apply_crate_ghosts(crates: Array) -> void:
	var seen: Dictionary = {}
	for c in crates:
		var nid: int = c.get("i", 0)
		seen[nid] = true
		if not crate_ghosts.has(nid):
			var ghost: Dictionary = {
				"nid": nid,
				"x": c.get("x", 0.0), "z": c.get("z", 0.0),
				"node": null,
			}
			crate_ghosts[nid] = ghost
			ghost_spawned.emit("crate", ghost)

	var to_remove: Array = []
	for nid in crate_ghosts:
		if not seen.has(nid):
			to_remove.append(nid)
	for nid in to_remove:
		crate_ghosts.erase(nid)
		ghost_removed.emit("crate", nid)


func interpolate_crate_ghosts() -> void:
	pass  # Static entities


## ---- Crow ghosts ----

func _apply_crow_ghosts(crows: Array) -> void:
	var seen: Dictionary = {}
	for cw in crows:
		var nid: int = cw.get("i", 0)
		seen[nid] = true

		if not crow_ghosts.has(nid):
			var ghost: Dictionary = {
				"nid": nid,
				"tx": cw.get("x", 0.0), "ty": cw.get("y", 0.0), "tz": cw.get("z", 0.0),
				"tyw": cw.get("yw", 0.0),
				"airborne": cw.get("st", 0) == 1,
				"purple": cw.get("pu", 0) == 1,
				"red_beak": cw.get("rk", 0) == 1,
				"scale": cw.get("sc", 1.0),
				"x": cw.get("x", 0.0), "y": cw.get("y", 0.0), "z": cw.get("z", 0.0),
				"yw": cw.get("yw", 0.0),
				"node": null,
			}
			crow_ghosts[nid] = ghost
			ghost_spawned.emit("crow", ghost)
		else:
			var g: Dictionary = crow_ghosts[nid]
			g["tx"] = cw.get("x", 0.0)
			g["ty"] = cw.get("y", 0.0)
			g["tz"] = cw.get("z", 0.0)
			g["tyw"] = cw.get("yw", 0.0)
			g["airborne"] = cw.get("st", 0) == 1

	var to_remove: Array = []
	for nid in crow_ghosts:
		if not seen.has(nid):
			to_remove.append(nid)
	for nid in to_remove:
		crow_ghosts.erase(nid)
		ghost_removed.emit("crow", nid)


func interpolate_crow_ghosts(k: float, _delta: float) -> void:
	for nid in crow_ghosts:
		var g: Dictionary = crow_ghosts[nid]
		g["x"] = lerpf(g["x"], g["tx"], k)
		g["y"] = lerpf(g["y"], g["ty"], k)
		g["z"] = lerpf(g["z"], g["tz"], k)
		g["yw"] = _ang_lerpf(g["yw"], g["tyw"], k)


## ---- Recruit ghosts ----

func _apply_recruit_ghosts(recruits: Array) -> void:
	var seen: Dictionary = {}
	for r in recruits:
		var cousin_id: String = r.get("c", "")
		seen[cousin_id] = true
		if not recruit_ghosts.has(cousin_id):
			var ghost: Dictionary = {
				"cousin_id": cousin_id,
				"x": r.get("x", 0.0), "z": r.get("z", 0.0),
				"walk_phase": randf() * 9.0,
				"node": null, "beacon_node": null,
			}
			recruit_ghosts[cousin_id] = ghost
			ghost_spawned.emit("recruit", ghost)
		else:
			var g: Dictionary = recruit_ghosts[cousin_id]
			g["x"] = r.get("x", 0.0)
			g["z"] = r.get("z", 0.0)

	var to_remove: Array = []
	for cousin_id in recruit_ghosts:
		if not seen.has(cousin_id):
			to_remove.append(cousin_id)
	for cousin_id in to_remove:
		recruit_ghosts.erase(cousin_id)
		ghost_removed.emit("recruit", hash(cousin_id))


func interpolate_recruit_ghosts(_k: float, _delta: float) -> void:
	pass  # Static/idle entities


## ---- Pose streaming ----

func send_pose_update() -> void:
	var pos := _get_player_position()
	var rot_y := _get_player_rotation_y()
	var wp := _get_player_weapon()
	var hp := _get_player_hp()
	var dn := _get_player_downed()
	var gun_angle := _get_player_gun_angle()
	var gs := _get_player_giant_scale()

	var mv := 0
	if absf(pos.x - _prev_x) > 0.02 or absf(pos.z - _prev_z) > 0.02:
		mv = 1
	_prev_x = pos.x
	_prev_z = pos.z

	var pose: Dictionary = {
		"t": "p",
		"x": pos.x, "z": pos.z, "y": pos.y,
		"yw": rot_y, "mv": mv,
		"wp": wp, "hp": int(hp),
		"dn": 1 if dn else 0,
		"ar": snappedf(gun_angle, 0.01),
	}
	if gs > 1.02:
		pose["gs"] = snappedf(gs, 0.05)

	pose_sent.emit(pose)

	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_client_pose", pose)


## ---- Remote RPC handlers (called from lobby_manager signals) ----

func _on_remote_pew(from_peer: int, x: float, y: float, z: float,
		hit_x: float, hit_y: float, hit_z: float, weapon_id: String) -> void:
	var ghost := _find_actor_by_peer(from_peer)
	if ghost.is_empty():
		return
	remote_pew_visualized.emit(ghost, x, y, z, Vector3(hit_x, hit_y, hit_z), weapon_id)


func _on_remote_emote(from_peer: int, emote_index: int) -> void:
	var ghost := _find_actor_by_peer(from_peer)
	if ghost.is_empty():
		return
	remote_emote_visualized.emit(ghost, emote_index)


func _on_remote_pose(from_peer: int, pose: Dictionary) -> void:
	var num := pose.get("player_num", 0)
	if num == 0:
		return
	var key := "p%d" % num
	if actor_ghosts.has(key):
		var ghost: Dictionary = actor_ghosts[key]
		ghost["tx"] = pose.get("x", ghost["tx"])
		ghost["tz"] = pose.get("z", ghost["tz"])
		ghost["ty"] = pose.get("y", ghost["ty"])
		ghost["tyw"] = pose.get("yw", ghost["tyw"])
		ghost["hp"] = pose.get("hp", ghost["hp"])
		ghost["downed"] = pose.get("dn", 0) == 1
		ghost["mv"] = pose.get("mv", 0)
		ghost["weapon_id"] = pose.get("wp", ghost["weapon_id"])
		ghost["tar"] = pose.get("ar", ghost["tar"])


## ---- Outgoing RPC sends (called by game code) ----

func send_shot(zombie_nid: int, damage: float, is_head: bool, weapon_id: String, dist: float) -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_shot_zombie", zombie_nid, damage, is_head, weapon_id, dist)


func send_pew(x: float, y: float, z: float, hit_pos: Vector3, weapon_id: String) -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_client_pew", x, y, z, hit_pos.x, hit_pos.y, hit_pos.z, weapon_id)


func send_emote(emote_index: int) -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_emote", emote_index)


func send_crate_open(crate_nid: int) -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_crate_open", crate_nid)


func send_pickup_take(pickup_nid: int) -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_pickup_take", pickup_nid)


func send_revive_request(target_player_num: int) -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_revive_req", target_player_num)


func send_recruit_request(cousin_id: String) -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_recruit_req", cousin_id)


func send_trade_request(target_peer: int) -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_trade_req", target_peer)


func send_npc_trade(cousin_id: String, my_weapon: String) -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_npc_trade", cousin_id, my_weapon)


func send_grandma_request() -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_grandma_req")


func send_jelly_request(jar_index: int) -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_jelly_req", jar_index)


func send_chili_request() -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_chili_req")


func send_dead() -> void:
	if lobby_manager and not multiplayer.is_server():
		lobby_manager.rpc_id(1, "_rpc_dead")


## ---- Helpers ----

func clear_all_ghosts() -> void:
	for dict in [zombie_ghosts, actor_ghosts, recruit_ghosts, pickup_ghosts, crate_ghosts, crow_ghosts]:
		dict.clear()


func _state_from_code(code: int) -> String:
	match code:
		1: return "dying"
		2: return "sleep"
		_: return "chase"


func _ang_lerpf(from_angle: float, to_angle: float, t: float) -> float:
	var diff := fmod(to_angle - from_angle, TAU)
	if diff > PI:
		diff -= TAU
	elif diff < -PI:
		diff += TAU
	return from_angle + diff * t


func _find_actor_by_peer(_peer_id: int) -> Dictionary:
	for key in actor_ghosts:
		var g: Dictionary = actor_ghosts[key]
		if g.get("player_num", 0) == _peer_id:
			return g
	return {}


## ---- Game state stubs (overridden by player/game manager) ----

func _get_player_position() -> Vector3:
	return Vector3.ZERO

func _get_player_rotation_y() -> float:
	return 0.0

func _get_player_weapon() -> String:
	return "fists"

func _get_player_hp() -> float:
	return 100.0

func _get_player_downed() -> bool:
	return false

func _get_player_gun_angle() -> float:
	return -PI / 2.0

func _get_player_giant_scale() -> float:
	return 1.0

func get_my_player_num() -> int:
	if lobby_manager:
		return lobby_manager.player_num
	return 0
