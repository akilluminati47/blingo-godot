extends Node
## Multiplayer spawner: manages spawning and lifecycle of networked entities
## across the host and all clients.
##
## On the HOST: entities are spawned locally, assigned a network ID, and streamed
## in snapshots. All game logic (damage, pickup, crate opening) runs here.
##
## On the CLIENT: entities are "ghosts" created/deleted based on snapshot presence.
## Input (shots, interactions) is RPC'd to the host for authoritative processing.

# References to networking modules
var lobby_manager: Node
var host_sync: Node
var client_sync: Node

# Network ID assignment
var next_id: int = 1000

# Registry of all networked entities the host manages
var networked_zombies: Dictionary = {}   # nid -> Dictionary
var networked_pickups: Dictionary = {}   # nid -> Dictionary
var networked_crates: Dictionary = {}    # nid -> Dictionary
var networked_crows: Dictionary = {}     # nid -> Dictionary


enum EntityType {
	ZOMBIE,
	PICKUP,
	CRATE,
	CROW,
	ACTOR,
	RECRUIT,
}


func _ready() -> void:
	# Find the autoloads
	if has_node("/root/LobbyManager"):
		lobby_manager = get_node("/root/LobbyManager")
	if has_node("/root/HostSync"):
		host_sync = get_node("/root/HostSync")
	if has_node("/root/ClientSync"):
		client_sync = get_node("/root/ClientSync")


func setup(lobby: Node, host: Node, client: Node) -> void:
	lobby_manager = lobby
	host_sync = host
	client_sync = client
	_connect_signals()


func _connect_signals() -> void:
	if host_sync:
		if host_sync.has_signal("request_zombie_states"):
			host_sync.request_zombie_states.connect(_on_request_zombie_states)
		if host_sync.has_signal("request_pickup_states"):
			host_sync.request_pickup_states.connect(_on_request_pickup_states)
		if host_sync.has_signal("request_crate_states"):
			host_sync.request_crate_states.connect(_on_request_crate_states)
		if host_sync.has_signal("request_crow_states"):
			host_sync.request_crow_states.connect(_on_request_crow_states)
		if host_sync.has_signal("request_recruit_states"):
			host_sync.request_recruit_states.connect(_on_request_recruit_states)
		if host_sync.has_signal("damage_zombie_requested"):
			host_sync.damage_zombie_requested.connect(apply_damage_to_zombie)
		if host_sync.has_signal("crate_open_requested"):
			host_sync.crate_open_requested.connect(handle_crate_open)
		if host_sync.has_signal("pickup_take_requested"):
			host_sync.pickup_take_requested.connect(handle_pickup_take)


# ---- State collectors for snapshot building ----

func _on_request_zombie_states(out: Array) -> void:
	for nid in networked_zombies:
		out.append(_zombie_to_snapshot(networked_zombies[nid]))


func _on_request_pickup_states(out: Array) -> void:
	for nid in networked_pickups:
		var p: Dictionary = networked_pickups[nid]
		if not p.get("picked_up", false):
			out.append(_pickup_to_snapshot(p))


func _on_request_crate_states(out: Array) -> void:
	for nid in networked_crates:
		var c: Dictionary = networked_crates[nid]
		if not c.get("opened", false):
			out.append(_crate_to_snapshot(c))


func _on_request_crow_states(out: Array) -> void:
	for nid in networked_crows:
		out.append(_crow_to_snapshot(networked_crows[nid]))


func _on_request_recruit_states(out: Array) -> void:
	if has_signal("collect_recruit_states"):
		collect_recruit_states.emit(out)


# ---- Registration (host only) ----

func register_zombie(zombie_data: Dictionary) -> int:
	if not multiplayer.is_server():
		return 0
	var nid := next_id
	next_id += 1
	zombie_data["nid"] = nid
	networked_zombies[nid] = zombie_data
	zombie_spawned.emit(nid)
	return nid


func register_pickup(pickup_data: Dictionary) -> int:
	if not multiplayer.is_server():
		return 0
	var nid := next_id
	next_id += 1
	pickup_data["nid"] = nid
	networked_pickups[nid] = pickup_data
	pickup_spawned.emit(nid)
	return nid


func register_crate(crate_data: Dictionary) -> int:
	if not multiplayer.is_server():
		return 0
	var nid := next_id
	next_id += 1
	crate_data["nid"] = nid
	networked_crates[nid] = crate_data
	crate_spawned.emit(nid)
	return nid


func register_crow(crow_data: Dictionary) -> int:
	if not multiplayer.is_server():
		return 0
	var nid := next_id
	next_id += 1
	crow_data["nid"] = nid
	networked_crows[nid] = crow_data
	return nid


func unregister_zombie(nid: int) -> void:
	networked_zombies.erase(nid)


func unregister_pickup(nid: int) -> void:
	networked_pickups.erase(nid)


func unregister_crate(nid: int) -> void:
	networked_crates.erase(nid)


func unregister_crow(nid: int) -> void:
	networked_crows.erase(nid)


# ---- Lookup ----

func get_zombie(nid: int) -> Dictionary:
	return networked_zombies.get(nid, {})


func get_pickup(nid: int) -> Dictionary:
	return networked_pickups.get(nid, {})


func get_crate(nid: int) -> Dictionary:
	return networked_crates.get(nid, {})


func get_crow(nid: int) -> Dictionary:
	return networked_crows.get(nid, {})


# ---- Snapshot packing ----

func _zombie_to_snapshot(z: Dictionary) -> Dictionary:
	const R := func(v: float) -> float: return snappedf(v, 0.05)
	return {
		"i": z.get("nid", 0),
		"x": R(z.get("x", 0.0)),
		"z": R(z.get("z", 0.0)),
		"yw": R(z.get("yw", 0.0)),
		"st": _state_code(z.get("state", "chase")),
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


func _pickup_to_snapshot(p: Dictionary) -> Dictionary:
	const R := func(v: float) -> float: return snappedf(v, 0.05)
	var kind_code := 0
	match p.get("kind", "ammo"):
		"medkit": kind_code = 1
		"bestjelly": kind_code = 2
	return {"i": p.get("nid", 0), "k": kind_code, "x": R(p.get("x", 0.0)), "z": R(p.get("z", 0.0))}


func _crate_to_snapshot(c: Dictionary) -> Dictionary:
	const R := func(v: float) -> float: return snappedf(v, 0.05)
	return {"i": c.get("nid", 0), "x": R(c.get("x", 0.0)), "z": R(c.get("z", 0.0))}


func _crow_to_snapshot(cw: Dictionary) -> Dictionary:
	const R := func(v: float) -> float: return snappedf(v, 0.05)
	return {
		"i": cw.get("nid", 0),
		"x": R(cw.get("x", 0.0)), "y": R(cw.get("y", 0.0)), "z": R(cw.get("z", 0.0)),
		"yw": R(cw.get("yw", 0.0)),
		"st": 1 if cw.get("airborne", true) else 0,
		"pu": 1 if cw.get("purple", false) else 0,
		"rk": 1 if cw.get("red_beak", false) else 0,
		"sc": R(cw.get("scale", 1.0)),
	}


func _state_code(state: String) -> int:
	match state:
		"dying": return 1
		"sleep", "emerge", "corpse": return 2
		_: return 0


# ---- Host-side: Apply damage from a client's shot ----

func apply_damage_to_zombie(nid: int, damage: float, is_head: bool, weapon_id: String, sender_peer: int) -> void:
	if not multiplayer.is_server():
		return
	if not networked_zombies.has(nid):
		return

	var z: Dictionary = networked_zombies[nid]
	var hp := z.get("hp", 100.0) as float
	var final_damage := damage * (2.5 if is_head else 1.0)
	hp -= final_damage

	if hp <= 0.0:
		z["hp"] = 0.0
		z["state"] = "dying"
		z["died_pop"] = is_head
		zombie_killed.emit(nid, sender_peer)
	else:
		z["hp"] = hp

	networked_zombies[nid] = z


# ---- Host-side: Crate open ----

func handle_crate_open(nid: int, _sender_peer: int) -> void:
	if not multiplayer.is_server():
		return
	if not networked_crates.has(nid):
		return

	var c: Dictionary = networked_crates[nid]
	if c.get("opened", false):
		return

	c["opened"] = true
	networked_crates[nid] = c
	crate_opened.emit(nid)


# ---- Host-side: Pickup take ----

func handle_pickup_take(nid: int, _sender_peer: int) -> void:
	if not multiplayer.is_server():
		return
	if not networked_pickups.has(nid):
		return

	var p: Dictionary = networked_pickups[nid]
	if p.get("picked_up", false):
		return

	p["picked_up"] = true
	networked_pickups[nid] = p
	pickup_taken.emit(nid, p.get("kind", "ammo"))


# ---- Client-side: Visual ghost management ----
# These would create/remove 3D nodes for ghost entities.
# The game's visual layer connects to client_sync's ghost_spawned/ghost_removed signals.

func spawn_ghost_entity(entity_type: EntityType, data: Dictionary) -> Node:
	var node := Node3D.new()
	node.set_meta("entity_type", entity_type)
	node.set_meta("nid", data.get("nid", 0))
	return node


func despawn_ghost_entity(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()


# ---- Signals ----

signal zombie_spawned(nid: int)
signal zombie_killed(nid: int, killer_peer: int)
signal pickup_spawned(nid: int)
signal pickup_taken(nid: int, kind: String)
signal crate_spawned(nid: int)
signal crate_opened(nid: int)
signal crow_shot(nid: int)
signal collect_recruit_states(out: Array)
