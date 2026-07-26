extends Node
## Lobby manager: creation, joining, code system, public scanning.
## Replaces PeerJS broker with Godot 4's ENetMultiplayerPeer.
##
## Lobby codes work like the original: each cousin name is a public lobby code.
## Private lobbies use custom 12-char alphanumeric codes.
## Public lobbies are discovered by connecting to well-known ports derived from
## cousin names -- the host listens on their cousin's port, scanners probe all six.
##
## ALL network RPCs route through this node. It is meant to be an autoload
## so the same node path exists on every peer, making rpc_id() work correctly.

const NET_SLOTS := 6
const DEFAULT_PORT := 9050
const MAX_CODE_LEN := 12

enum LobbyRole { NONE, HOST, CLIENT }

var role: LobbyRole = LobbyRole.NONE
var lobby_code: String = ""
var player_num: int = 0
var peer: ENetMultiplayerPeer
var connections: Array[int] = []

const PUBLIC_CODES := [
	"blingo", "blazo", "blondie", "blomba", "bloopi", "blotzy"
]

const CODE_PORTS := {
	"blingo": 9050,
	"blazo":   9051,
	"blondie": 9052,
	"blomba":  9053,
	"bloopi":  9054,
	"blotzy":  9055,
}

var selected_cousin: String = "blingo"

# ---- signals ----
signal lobby_found(code: String, slots_filled: int, player_ids: Array)
signal lobby_joined(code: String, player_number: int)
signal lobby_hosted(code: String, is_public: bool)
signal lobby_closed()
signal lobby_error(message: String)
signal scan_complete(found_count: int)
signal scan_started()
signal scan_message(message: String)
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal player_reconnected(peer_id: int)

# Snapshot relay (lobby -> client_sync)
signal snapshot_received(snap: Dictionary)

# Client pose relay (lobby -> host_sync)
signal client_pose_received(sender_peer: int, pose: Dictionary)

# RPC relay signals -- host_sync receives these
signal rpc_shot_zombie(sender: int, zombie_nid: int, damage: float, is_head: bool, weapon_id: String, dist: float)
signal rpc_pew(sender: int, x: float, y: float, z: float, hit_x: float, hit_y: float, hit_z: float, weapon_id: String)
signal rpc_emote(sender: int, emote_index: int)
signal rpc_crate_open(sender: int, crate_nid: int)
signal rpc_pickup_take(sender: int, pickup_nid: int)
signal rpc_revive_req(sender: int, target_player_num: int)
signal rpc_recruit_req(sender: int, cousin_id: String)
signal rpc_trade_req(sender: int, target_peer: int)
signal rpc_npc_trade(sender: int, cousin_id: String, my_weapon: String)
signal rpc_grandma_req(sender: int)
signal rpc_jelly_req(sender: int, jar_index: int)
signal rpc_chili_req(sender: int)
signal rpc_dead(sender: int)
signal rpc_leave(sender: int)
signal rpc_hi(sender: int, cousin: String, token: String)

# Client-side RPC relay signals -- client_sync receives these
signal rpc_remote_pew(from_peer: int, x: float, y: float, z: float, hit_x: float, hit_y: float, hit_z: float, weapon_id: String)
signal rpc_remote_emote(from_peer: int, emote_index: int)
signal rpc_remote_pose(from_peer: int, pose: Dictionary)
signal rpc_welcome(player_num: int, cousin: String, data: Dictionary)
signal rpc_join_denied(reason: String)
signal rpc_full()


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _exit_tree() -> void:
	leave_lobby()


# ---- code utilities ----

func norm_code(raw: String) -> String:
	var code := ""
	raw = raw.to_lower()
	for ch in raw:
		if ch in "abcdefghijklmnopqrstuvwxyz0123456789":
			code += ch
		if code.length() >= MAX_CODE_LEN:
			break
	return code


func is_public_code(code: String) -> bool:
	var n := norm_code(code)
	return n in PUBLIC_CODES


func default_code() -> String:
	if selected_cousin.is_empty():
		return PUBLIC_CODES[0]
	return selected_cousin.to_lower()


func code_port(code: String) -> int:
	var n := norm_code(code)
	if CODE_PORTS.has(n):
		return CODE_PORTS[n]
	var h := hash(n)
	return 9056 + absi(h) % (9999 - 9056 + 1)


# ---- hosting ----

func host_lobby(raw_code: String) -> void:
	var code := norm_code(raw_code)
	if code.is_empty():
		lobby_error.emit("Give the lobby a code first . .")
		return

	peer = ENetMultiplayerPeer.new()
	var port := code_port(code)
	var result := peer.create_server(port, NET_SLOTS)
	if result != OK:
		result = peer.create_server(port + 1, NET_SLOTS)
		if result != OK:
			lobby_error.emit("%s is already hosting . . pick another code" % code.to_upper())
			return

	multiplayer.multiplayer_peer = peer
	role = LobbyRole.HOST
	lobby_code = code
	player_num = 1
	connections = []

	lobby_hosted.emit(code, is_public_code(code))


# ---- joining ----

func join_lobby(raw_code: String, host_address: String = "127.0.0.1") -> void:
	var code := norm_code(raw_code)
	if code.is_empty():
		lobby_error.emit("Type a code to join . .")
		return

	peer = ENetMultiplayerPeer.new()
	var port := code_port(code)
	var result := peer.create_client(host_address, port)
	if result != OK:
		lobby_error.emit("Could not reach that lobby . .")
		return

	multiplayer.multiplayer_peer = peer
	role = LobbyRole.CLIENT
	lobby_code = code
	connections = []


# ---- scanning ----

func scan_public_lobbies() -> void:
	scan_started.emit()
	scan_message.emit("Scanning for lobbies . .")

	var found := 0
	var scanner_results: Array = []

	for pub_code in PUBLIC_CODES:
		var scanner := ENetMultiplayerPeer.new()
		var port := CODE_PORTS[pub_code]
		var result := scanner.create_client("127.0.0.1", port)
		if result != OK:
			continue

		await get_tree().create_timer(0.3).timeout

		if scanner.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			found += 1
			var peers: Array[int] = []
			for pid in scanner.get_peers():
				peers.append(pid)
			lobby_found.emit(pub_code, peers.size() + 1, peers)
			scanner_results.append({"code": pub_code, "slots": peers.size() + 1})
			scanner.close()
		else:
			scanner.close()

	if found == 0:
		scan_message.emit("No open lobbies . . host one!")
	else:
		scan_message.emit("Pick a lobby, or host your own . .")

	scan_complete.emit(found)


# ---- leaving ----

func leave_lobby() -> void:
	if role == LobbyRole.CLIENT and not connections.is_empty():
		rpc_id(1, "_notify_leave")

	if peer:
		peer.close()
		peer = null

	role = LobbyRole.NONE
	lobby_code = ""
	player_num = 0
	connections = []

	multiplayer.multiplayer_peer = null
	lobby_closed.emit()


# ---- peer connection handling ----

func _on_peer_connected(peer_id: int) -> void:
	if role == LobbyRole.HOST:
		if peer_id == 1:
			return
		connections.append(peer_id)
		player_connected.emit(peer_id)
	elif role == LobbyRole.CLIENT:
		if peer_id == 1:
			connections.append(peer_id)
			rpc_id(1, "_request_join", selected_cousin, generate_token())


func _on_peer_disconnected(peer_id: int) -> void:
	if role == LobbyRole.HOST:
		connections.erase(peer_id)
		player_disconnected.emit(peer_id)
	elif role == LobbyRole.CLIENT:
		if peer_id == 1:
			lobby_error.emit("Host closed the lobby . .")
			leave_lobby()


func generate_token() -> String:
	return str(abs(hash(str(Time.get_unix_time_from_system()) + str(randi()))))


## ---- ALL NETWORK RPC METHODS ----
## These all live here because rpc_id() targets the same node path on the remote peer.
## All peers have LobbyManager as an autoload, so rpc_id(1, "_rpc_X") correctly
## reaches the host's LobbyManager which then emits a signal for the host's HostSync.

# ---- Lobby join flow ----

@rpc("any_peer", "reliable")
func _request_join(cousin: String, token: String) -> void:
	rpc_hi.emit(multiplayer.get_remote_sender_id(), cousin, token)


@rpc("authority", "reliable")
func _rpc_join_denied(reason: String) -> void:
	rpc_join_denied.emit(reason)


@rpc("authority", "reliable")
func _rpc_welcome(player_num_val: int, cousin: String, data: Dictionary) -> void:
	player_num = player_num_val
	lobby_code = norm_code(lobby_code)
	rpc_welcome.emit(player_num_val, cousin, data)
	lobby_joined.emit(lobby_code, player_num_val)


@rpc("authority", "reliable")
func _rpc_full() -> void:
	rpc_full.emit()
	lobby_error.emit("That lobby is full . .")


# ---- Host snapshot ----

@rpc("authority", "reliable")
func _rpc_snapshot(snap: Dictionary) -> void:
	snapshot_received.emit(snap)


# ---- Client pose to host + relay to others ----

@rpc("any_peer", "reliable")
func _rpc_client_pose(pose: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	client_pose_received.emit(sender, pose)

	# Relay to all other clients
	for pid in multiplayer.get_peers():
		if pid != sender and pid != 1:
			rpc_id(pid, "_rpc_remote_pose", sender, pose)


@rpc("authority", "reliable")
func _rpc_remote_pose(from_peer: int, pose: Dictionary) -> void:
	rpc_remote_pose.emit(from_peer, pose)


# ---- Client shot ----

@rpc("any_peer", "reliable")
func _rpc_shot_zombie(zombie_nid: int, damage: float, is_head: bool, weapon_id: String, dist: float) -> void:
	rpc_shot_zombie.emit(multiplayer.get_remote_sender_id(), zombie_nid, damage, is_head, weapon_id, dist)


# ---- Client pew (muzzle flash / tracer for others) ----

@rpc("any_peer", "reliable")
func _rpc_client_pew(x: float, y: float, z: float, hit_x: float, hit_y: float, hit_z: float, weapon_id: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	rpc_pew.emit(sender, x, y, z, hit_x, hit_y, hit_z, weapon_id)

	# Relay to all other clients
	for pid in multiplayer.get_peers():
		if pid != sender and pid != 1:
			rpc_id(pid, "_rpc_remote_pew", sender, x, y, z, hit_x, hit_y, hit_z, weapon_id)


@rpc("authority", "reliable")
func _rpc_remote_pew(from_peer: int, x: float, y: float, z: float, hit_x: float, hit_y: float, hit_z: float, weapon_id: String) -> void:
	rpc_remote_pew.emit(from_peer, x, y, z, hit_x, hit_y, hit_z, weapon_id)


# ---- Emote ----

@rpc("any_peer", "reliable")
func _rpc_emote(emote_index: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	rpc_emote.emit(sender, emote_index)

	for pid in multiplayer.get_peers():
		if pid != sender and pid != 1:
			rpc_id(pid, "_rpc_remote_emote", sender, emote_index)


@rpc("authority", "reliable")
func _rpc_remote_emote(from_peer: int, emote_index: int) -> void:
	rpc_remote_emote.emit(from_peer, emote_index)


# ---- Crate open ----

@rpc("any_peer", "reliable")
func _rpc_crate_open(crate_nid: int) -> void:
	rpc_crate_open.emit(multiplayer.get_remote_sender_id(), crate_nid)


# ---- Pickup take ----

@rpc("any_peer", "reliable")
func _rpc_pickup_take(pickup_nid: int) -> void:
	rpc_pickup_take.emit(multiplayer.get_remote_sender_id(), pickup_nid)


# ---- Revive ----

@rpc("any_peer", "reliable")
func _rpc_revive_req(target_player_num: int) -> void:
	rpc_revive_req.emit(multiplayer.get_remote_sender_id(), target_player_num)


# ---- Recruit ----

@rpc("any_peer", "reliable")
func _rpc_recruit_req(cousin_id: String) -> void:
	rpc_recruit_req.emit(multiplayer.get_remote_sender_id(), cousin_id)


# ---- Trade ----

@rpc("any_peer", "reliable")
func _rpc_trade_req(target_peer: int) -> void:
	rpc_trade_req.emit(multiplayer.get_remote_sender_id(), target_peer)


@rpc("any_peer", "reliable")
func _rpc_npc_trade(cousin_id: String, my_weapon: String) -> void:
	rpc_npc_trade.emit(multiplayer.get_remote_sender_id(), cousin_id, my_weapon)


# ---- Grandma (Jelly House finale) ----

@rpc("any_peer", "reliable")
func _rpc_grandma_req() -> void:
	rpc_grandma_req.emit(multiplayer.get_remote_sender_id())


# ---- Jelly jar ----

@rpc("any_peer", "reliable")
func _rpc_jelly_req(jar_index: int) -> void:
	rpc_jelly_req.emit(multiplayer.get_remote_sender_id(), jar_index)


# ---- Chili bowl ----

@rpc("any_peer", "reliable")
func _rpc_chili_req() -> void:
	rpc_chili_req.emit(multiplayer.get_remote_sender_id())


# ---- Player dead / leave ----

@rpc("any_peer", "reliable")
func _rpc_dead() -> void:
	rpc_dead.emit(multiplayer.get_remote_sender_id())


@rpc("any_peer", "reliable")
func _notify_leave() -> void:
	rpc_leave.emit(multiplayer.get_remote_sender_id())


# ---- Convenience methods for other nodes to send RPCs ----

func send_to_host(method: String, args: Array = []) -> void:
	if role == LobbyRole.CLIENT:
		args.insert(0, method)
		# Use callv on the RPC
		match method:
			"_rpc_client_pose":
				rpc_id(1, method, args[1] if args.size() > 1 else {})
			"_rpc_shot_zombie":
				if args.size() >= 6:
					rpc_id(1, method, args[1], args[2], args[3], args[4], args[5])
			"_rpc_client_pew":
				if args.size() >= 8:
					rpc_id(1, method, args[1], args[2], args[3], args[4], args[5], args[6], args[7])
			"_rpc_emote":
				if args.size() >= 2:
					rpc_id(1, method, args[1])
			"_rpc_crate_open":
				if args.size() >= 2:
					rpc_id(1, method, args[1])
			"_rpc_pickup_take":
				if args.size() >= 2:
					rpc_id(1, method, args[1])
			"_rpc_revive_req":
				if args.size() >= 2:
					rpc_id(1, method, args[1])
			"_rpc_recruit_req":
				if args.size() >= 2:
					rpc_id(1, method, args[1])
			"_rpc_trade_req":
				if args.size() >= 2:
					rpc_id(1, method, args[1])
			"_rpc_npc_trade":
				if args.size() >= 3:
					rpc_id(1, method, args[1], args[2])
			"_rpc_grandma_req":
				rpc_id(1, method)
			"_rpc_jelly_req":
				if args.size() >= 2:
					rpc_id(1, method, args[1])
			"_rpc_chili_req":
				rpc_id(1, method)
			"_rpc_dead":
				rpc_id(1, method)
			"_notify_leave":
				rpc_id(1, method)


func broadcast_to_clients(method: String, args: Array = []) -> void:
	if role != LobbyRole.HOST:
		return
	for pid in multiplayer.get_peers():
		match args.size():
			0: rpc_id(pid, method)
			1: rpc_id(pid, method, args[0])
			2: rpc_id(pid, method, args[0], args[1])
			3: rpc_id(pid, method, args[0], args[1], args[2])
			4: rpc_id(pid, method, args[0], args[1], args[2], args[3])
			5: rpc_id(pid, method, args[0], args[1], args[2], args[3], args[4])
			6: rpc_id(pid, method, args[0], args[1], args[2], args[3], args[4], args[5])
			7: rpc_id(pid, method, args[0], args[1], args[2], args[3], args[4], args[5], args[6])
