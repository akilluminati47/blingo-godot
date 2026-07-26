extends Node
## Host-authoritative sync: snapshot building, zombie ghost streaming,
## interest management, and RPC request handling.
##
## The host runs the world simulation (zombies, spawner, pickups, crates).
## Every 100ms (10Hz) a snapshot is built and streamed to each client via
## the LobbyManager.
##
## Interest filtering: each client only receives zombies near THEIR hero.
## Backpressure: skip a snapshot if the send buffer is backed up.

const SNAPSHOT_INTERVAL := 0.1
const INTEREST_RADIUS := 150.0
const RECONNECT_GRACE_MS := 60000

# Dependencies (set via find_node or exported)
var lobby_manager: Node

var snapshot_timer: float = 0.0
var next_net_id: int = 1

# Track host-side pose state for each connected player peer
var player_states: Dictionary = {}  # peer_id -> {pose, hp, weapon, downed, ...}

# Drop hold: peer_id -> {cousin, player_num, expiry_ms, token}
var dropped_holds: Dictionary = {}

# Actor movement tracking for delta compression
var _actor_positions: Dictionary = {}


func _ready() -> void:
	set_process(false)


func setup(lobby: Node) -> void:
	lobby_manager = lobby
	_connect_signals()


func _connect_signals() -> void:
	if not lobby_manager:
		return
	# Connect all RPC relay signals from lobby_manager (host side)
	var lm := lobby_manager
	if lm.has_signal("rpc_hi"):
		lm.rpc_hi.connect(_on_client_hi)
	if lm.has_signal("rpc_shot_zombie"):
		lm.rpc_shot_zombie.connect(_on_client_shot)
	if lm.has_signal("rpc_pew"):
		lm.rpc_pew.connect(_on_client_pew)
	if lm.has_signal("rpc_emote"):
		lm.rpc_emote.connect(_on_client_emote)
	if lm.has_signal("rpc_crate_open"):
		lm.rpc_crate_open.connect(_on_client_crate_open)
	if lm.has_signal("rpc_pickup_take"):
		lm.rpc_pickup_take.connect(_on_client_pickup_take)
	if lm.has_signal("rpc_revive_req"):
		lm.rpc_revive_req.connect(_on_client_revive_req)
	if lm.has_signal("rpc_recruit_req"):
		lm.rpc_recruit_req.connect(_on_client_recruit_req)
	if lm.has_signal("rpc_trade_req"):
		lm.rpc_trade_req.connect(_on_client_trade_req)
	if lm.has_signal("rpc_npc_trade"):
		lm.rpc_npc_trade.connect(_on_client_npc_trade)
	if lm.has_signal("rpc_grandma_req"):
		lm.rpc_grandma_req.connect(_on_client_grandma_req)
	if lm.has_signal("rpc_jelly_req"):
		lm.rpc_jelly_req.connect(_on_client_jelly_req)
	if lm.has_signal("rpc_chili_req"):
		lm.rpc_chili_req.connect(_on_client_chili_req)
	if lm.has_signal("rpc_dead"):
		lm.rpc_dead.connect(_on_client_dead)
	if lm.has_signal("rpc_leave"):
		lm.rpc_leave.connect(_on_client_leave)
	if lm.has_signal("client_pose_received"):
		lm.client_pose_received.connect(_on_client_pose_received)


func start_host_sync() -> void:
	snapshot_timer = 0.0
	set_process(true)


func stop_host_sync() -> void:
	set_process(false)


func _process(delta: float) -> void:
	sweep_holds()
	snapshot_timer -= delta
	if snapshot_timer <= 0.0:
		snapshot_timer = SNAPSHOT_INTERVAL
		build_and_send_snapshots()


func register_net_id() -> int:
	next_net_id += 1
	return next_net_id - 1


# ---- Snapshot building ----

func build_and_send_snapshots() -> void:
	if not multiplayer.is_server():
		return

	var base := _base_snapshot()
	var zb: Array = _collect_zombie_states()
	var pk: Array = _collect_pickup_states()
	var cr: Array = _collect_crate_states()
	var cw_states: Array = _collect_crow_states()

	for peer_id in multiplayer.get_peers():
		var hero_pos := _get_client_hero_pos(peer_id)

		var snap := base.duplicate(true)
		snap["zb"] = _filter_interest(zb, hero_pos.x, hero_pos.z, INTEREST_RADIUS)
		snap["pk"] = _filter_interest(pk, hero_pos.x, hero_pos.z, INTEREST_RADIUS)
		snap["cr"] = _filter_interest(cr, hero_pos.x, hero_pos.z, INTEREST_RADIUS)
		snap["cw"] = cw_states

		if lobby_manager:
			lobby_manager.rpc_id(peer_id, "_rpc_snapshot", snap)


func _base_snapshot() -> Dictionary:
	return {
		"t": "s",
		"tm": _get_game_time(),
		"k": _get_game_kills(),
		"ac": _build_actor_states(),
		"rc": _build_recruit_states(),
	}


func _build_actor_states() -> Array:
	var ac: Array = []

	# Host (player 1)
	ac.append(_net_actor_of(1, _get_host_cousin(), _get_host_pos(), _get_host_rot(),
		_get_host_weapon(), _get_host_hp(), _get_host_downed(), _get_host_gun_angle(),
		_get_host_giant_scale()))

	# Remote player-controlled cousins
	for peer_id in player_states:
		var ps: Dictionary = player_states[peer_id]
		if not ps.has("player_num"):
			continue
		ac.append(_net_actor_of(
			ps["player_num"],
			ps.get("cousin", ""),
			ps.get("x", 0.0), ps.get("z", 0.0), ps.get("y", 0.0),
			ps.get("yw", 0.0), ps.get("wp", "fists"),
			ps.get("hp", 100), ps.get("dn", false),
			ps.get("ar", -PI / 2.0), ps.get("gs", 1.0)
		))

	return ac


func _net_actor_of(p_num: int, cousin_id: String, pos: Vector3, yaw: float,
		wp: String, hp: float, dn: bool, gun_angle: float,
		giant_scale: float = 1.0) -> Dictionary:

	const R := func(v: float) -> float: return snappedf(v, 0.05)

	var key := ("p%d" % p_num) if p_num > 0 else ("ai%s" % cousin_id)
	var mv := 0
	if not _actor_positions.has(key):
		_actor_positions[key] = Vector2(pos.x, pos.z)
		mv = 1
	else:
		var prev: Vector2 = _actor_positions[key]
		if (Vector2(pos.x, pos.z) - prev).length() > 0.03:
			_actor_positions[key] = Vector2(pos.x, pos.z)
			mv = 1

	var state: Dictionary = {
		"p": p_num,
		"c": cousin_id,
		"x": R(pos.x), "z": R(pos.z), "y": R(pos.y),
		"yw": R(yaw), "wp": wp, "hp": int(hp),
		"dn": 1 if dn else 0,
		"mv": mv,
		"ar": snappedf(gun_angle, 0.01),
	}
	if giant_scale > 1.02:
		state["gs"] = snappedf(giant_scale, 0.05)
	return state


func zombie_to_snapshot_entry(z: Dictionary) -> Dictionary:
	const R := func(v: float) -> float: return snappedf(v, 0.05)
	if not z.has("nid") or z["nid"] == 0:
		z["nid"] = register_net_id()

	return {
		"i": z["nid"],
		"x": R(z.get("x", 0.0)), "z": R(z.get("z", 0.0)),
		"yw": R(z.get("yw", 0.0)),
		"st": _zombie_state_code(z.get("state", "chase")),
		"sc": R(z.get("scale", 1.0)),
		"pu": 1 if z.get("purple", false) else 0,
		"re": 1 if z.get("red", false) else 0,
		"gr": 1 if z.get("green", false) else 0,
		"gh": 1 if z.get("gore_horn", false) else 0,
		"ho": 1 if z.get("horn_visible", false) else 0,
		"bo": 1 if z.get("is_boss", false) else 0,
		"b2": 1 if z.get("is_boss2", false) else 0,
		"b3": 1 if z.get("is_boss3", false) else 0,
		"b4": 1 if z.get("is_boss4", false) else 0,
		"sh": 1 if z.get("shielded", false) else 0,
		"gd": 1 if z.get("shield_guard", false) else 0,
		"fb": 1 if z.get("is_fbi", false) else 0,
		"bg": 1 if z.get("is_bluga", false) else 0,
		"dp": 1 if z.get("died_pop", false) else 0,
		"he": 1 if z.get("rot_hang_eye", false) else 0,
		"rb": 1 if z.get("rot_ribs", false) else 0,
		"rr": 1 if z.get("rot_ribs_r", false) else 0,
		"pb": 1 if z.get("rot_belly", false) else 0,
	}


func _zombie_state_code(state: String) -> int:
	match state:
		"dying": return 1
		"sleep", "emerge", "corpse": return 2
		_: return 0


func _filter_interest(entries: Array, cx: float, cz: float, radius: float) -> Array:
	var filtered: Array = []
	for entry in entries:
		var keep := entry.get("bo", 0) == 1 or entry.get("fb", 0) == 1
		if not keep:
			var ex: float = entry.get("x", 0.0)
			var ez: float = entry.get("z", 0.0)
			keep = absf(ex - cx) < radius and absf(ez - cz) < radius
		if keep:
			filtered.append(entry)
	return filtered


func _get_client_hero_pos(peer_id: int) -> Vector3:
	if player_states.has(peer_id):
		var ps: Dictionary = player_states[peer_id]
		return Vector3(ps.get("x", 0.0), ps.get("y", 0.0), ps.get("z", 0.0))
	return _get_host_pos()


# ---- Client pose received from lobby ----

func _on_client_pose_received(sender: int, pose: Dictionary) -> void:
	player_states[sender] = pose


# ---- Client join flow ----

func _on_client_hi(sender: int, cousin: String, token: String) -> void:
	if not multiplayer.is_server():
		return

	# Check reconnection
	if not token.is_empty() and dropped_holds.has(sender):
		var hold: Dictionary = dropped_holds[sender]
		if hold.get("token", "") == token:
			dropped_holds.erase(sender)
			var num: int = hold["player_num"]
			if lobby_manager:
				lobby_manager.rpc_id(sender, "_rpc_welcome", num, hold["cousin"], {})
			# Emit reconnected through lobby
			if lobby_manager and lobby_manager.has_signal("player_reconnected"):
				lobby_manager.player_reconnected.emit(sender)
			return

	# New player
	if multiplayer.get_peers().size() >= 6:
		if lobby_manager:
			lobby_manager.rpc_id(sender, "_rpc_full")
		return

	var num := _assign_player_number()
	player_states[sender] = {
		"cousin": cousin,
		"player_num": num,
		"x": _get_host_pos().x,
		"z": _get_host_pos().z,
		"y": _get_host_pos().y,
		"yw": 0.0,
		"wp": "fists",
		"hp": 100,
		"dn": false,
		"ar": -PI / 2.0,
		"gs": 1.0,
		"token": token,
	}

	if lobby_manager:
		lobby_manager.rpc_id(sender, "_rpc_welcome", num, cousin, {
			"x": _get_host_pos().x,
			"z": _get_host_pos().z,
			"tm": _get_game_time(),
			"k": _get_game_kills(),
		})

	# Broadcast to other clients
	for pid in multiplayer.get_peers():
		if pid != sender:
			lobby_manager.rpc_id(pid, "_rpc_remote_pose", sender, {
				"cousin": cousin, "player_num": num,
				"x": _get_host_pos().x, "z": _get_host_pos().z,
				"wp": "fists", "hp": 100, "dn": 0,
			})


# ---- Player seat management ----

func _on_client_leave(sender: int) -> void:
	_free_seat(sender, true)


func _on_client_dead(sender: int) -> void:
	_free_seat(sender, false)


func _free_seat(peer_id: int, gone: bool) -> void:
	if not player_states.has(peer_id):
		return

	var ps: Dictionary = player_states[peer_id]
	var player_num_val: int = ps.get("player_num", 0)
	var cousin: String = ps.get("cousin", "")
	var token: String = ps.get("token", "")

	if gone:
		player_states.erase(peer_id)
		if lobby_manager:
			lobby_manager.connections.erase(peer_id)
			if lobby_manager.has_signal("player_disconnected"):
				lobby_manager.player_disconnected.emit(peer_id)
	else:
		dropped_holds[peer_id] = {
			"cousin": cousin,
			"player_num": player_num_val,
			"expiry_ms": Time.get_ticks_msec() + RECONNECT_GRACE_MS,
			"token": token,
		}
		player_states.erase(peer_id)
		if lobby_manager and lobby_manager.has_signal("player_disconnected"):
			lobby_manager.player_disconnected.emit(peer_id)


func sweep_holds() -> void:
	var now := Time.get_ticks_msec()
	var expired: Array = []
	for pid in dropped_holds:
		if dropped_holds[pid]["expiry_ms"] < now:
			expired.append(pid)
	for pid in expired:
		dropped_holds.erase(pid)


func _assign_player_number() -> int:
	var taken: Array = [1]
	for ps in player_states.values():
		if ps.has("player_num"):
			taken.append(ps["player_num"] as int)
	var num := 2
	while num in taken:
		num += 1
	return num


# ---- Client RPC handlers ----

func _on_client_shot(sender: int, zombie_nid: int, damage: float, is_head: bool, weapon_id: String, dist: float) -> void:
	if has_signal("damage_zombie_requested"):
		damage_zombie_requested.emit(zombie_nid, damage, is_head, weapon_id, sender)


func _on_client_pew(sender: int, x: float, y: float, z: float, hit_x: float, hit_y: float, hit_z: float, weapon_id: String) -> void:
	if has_signal("pew_visual_requested"):
		pew_visual_requested.emit(sender, x, y, z, Vector3(hit_x, hit_y, hit_z), weapon_id)


func _on_client_emote(sender: int, emote_index: int) -> void:
	if has_signal("emote_requested"):
		emote_requested.emit(sender, emote_index)


func _on_client_crate_open(sender: int, crate_nid: int) -> void:
	if has_signal("crate_open_requested"):
		crate_open_requested.emit(crate_nid, sender)


func _on_client_pickup_take(sender: int, pickup_nid: int) -> void:
	if has_signal("pickup_take_requested"):
		pickup_take_requested.emit(pickup_nid, sender)


func _on_client_revive_req(sender: int, target_player_num: int) -> void:
	if has_signal("revive_requested"):
		revive_requested.emit(target_player_num, sender)


func _on_client_recruit_req(sender: int, cousin_id: String) -> void:
	if has_signal("recruit_requested"):
		recruit_requested.emit(cousin_id, sender)


func _on_client_trade_req(sender: int, target_peer: int) -> void:
	if has_signal("trade_requested"):
		trade_requested.emit(sender, target_peer)


func _on_client_npc_trade(sender: int, cousin_id: String, my_weapon: String) -> void:
	if has_signal("npc_trade_requested"):
		npc_trade_requested.emit(cousin_id, my_weapon, sender)


func _on_client_grandma_req(sender: int) -> void:
	if has_signal("grandma_requested"):
		grandma_requested.emit(sender)


func _on_client_jelly_req(sender: int, jar_index: int) -> void:
	if has_signal("jelly_requested"):
		jelly_requested.emit(jar_index, sender)


func _on_client_chili_req(sender: int) -> void:
	if has_signal("chili_requested"):
		chili_requested.emit(sender)


# ---- Collectors: these would call out to the game world ----
# In the full game, these connect to the zombie manager, pickup manager, etc.

func _collect_zombie_states() -> Array:
	var out: Array = []
	if has_signal("request_zombie_states"):
		request_zombie_states.emit(out)
	return out


func _collect_pickup_states() -> Array:
	var out: Array = []
	if has_signal("request_pickup_states"):
		request_pickup_states.emit(out)
	return out


func _collect_crate_states() -> Array:
	var out: Array = []
	if has_signal("request_crate_states"):
		request_crate_states.emit(out)
	return out


func _collect_crow_states() -> Array:
	var out: Array = []
	if has_signal("request_crow_states"):
		request_crow_states.emit(out)
	return out


func _build_recruit_states() -> Array:
	var out: Array = []
	if has_signal("request_recruit_states"):
		request_recruit_states.emit(out)
	return out


# ---- Game state stubs (overridden by game manager) ----

func _get_host_cousin() -> String:
	return "blingo"

func _get_host_pos() -> Vector3:
	return Vector3.ZERO

func _get_host_rot() -> float:
	return 0.0

func _get_host_weapon() -> String:
	return "fists"

func _get_host_hp() -> float:
	return 100.0

func _get_host_downed() -> bool:
	return false

func _get_host_gun_angle() -> float:
	return -PI / 2.0

func _get_host_giant_scale() -> float:
	return 1.0

func _get_game_time() -> float:
	return 0.0

func _get_game_kills() -> int:
	return 0


# ---- Signals ----
signal request_zombie_states(out: Array)
signal request_pickup_states(out: Array)
signal request_crate_states(out: Array)
signal request_crow_states(out: Array)
signal request_recruit_states(out: Array)
signal damage_zombie_requested(zombie_nid: int, damage: float, is_head: bool, weapon_id: String, sender: int)
signal pew_visual_requested(sender: int, x: float, y: float, z: float, hit_pos: Vector3, weapon_id: String)
signal emote_requested(sender: int, emote_index: int)
signal crate_open_requested(crate_nid: int, sender: int)
signal pickup_take_requested(pickup_nid: int, sender: int)
signal revive_requested(target_player_num: int, sender: int)
signal recruit_requested(cousin_id: String, sender: int)
signal trade_requested(sender: int, target_peer: int)
signal npc_trade_requested(cousin_id: String, my_weapon: String, sender: int)
signal grandma_requested(sender: int)
signal jelly_requested(jar_index: int, sender: int)
signal chili_requested(sender: int)
