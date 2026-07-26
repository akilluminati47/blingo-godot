class_name ChunkManager
extends Node
## Chunk streaming manager.  Loads terrain chunks around a tracked target
## (usually the player), unloads distant ones.  Budgeted to at most
## BUILD_BUDGET new chunks per frame during gameplay.

const CHUNK_SIZE: float = 40.0   ## must match terrain_generator.gd
const VIEW_RINGS: int = 3        ## rings → (1 + 2*3)^2 = 49 chunks
const BUILD_BUDGET: int = 2      ## max new chunks per frame during gameplay

@export var terrain_generator: TerrainGenerator

## Target node the chunks follow (assign on player spawn).
var target: Node3D = null

## { "cx,cz": <Node3D> }
var _loaded: Dictionary = {}
var _pending: Array = []


func _ready() -> void:
	if not terrain_generator:
		push_error("ChunkManager: terrain_generator not assigned.")
	set_process(false)


## Call on player spawn / respawn to begin streaming.
func set_target(t: Node3D) -> void:
	target = t
	if target:
		set_process(true)
		_full_rebuild.call_deferred()


func _process(_delta: float) -> void:
	if not target or not is_instance_valid(target):
		return

	var px: float = target.global_position.x
	var pz: float = target.global_position.z
	var ccx: int = roundi(px / CHUNK_SIZE)
	var ccz: int = roundi(pz / CHUNK_SIZE)

	## Collect missing chunks, sorted nearest-first.
	var missing: Array = []
	for dx in range(-VIEW_RINGS, VIEW_RINGS + 1):
		for dz in range(-VIEW_RINGS, VIEW_RINGS + 1):
			var key := _key(ccx + dx, ccz + dz)
			if not _loaded.has(key):
				missing.append([key, ccx + dx, ccz + dz, dx * dx + dz * dz])

	if missing.size() > 0:
		missing.sort_custom(func(a, b): return a[3] < b[3])
		var budget: int = BUILD_BUDGET
		for i in range(min(budget, missing.size())):
			_build_chunk(missing[i][1], missing[i][2])

	## Unload distant chunks (one ring beyond alive).
	var to_unload: Array = []
	for key in _loaded:
		var node: Node3D = _loaded[key]
		var meta_cx: int = node.get_meta("chunk_cx", 0)
		var meta_cz: int = node.get_meta("chunk_cz", 0)
		if abs(meta_cx - ccx) > VIEW_RINGS + 1 or abs(meta_cz - ccz) > VIEW_RINGS + 1:
			to_unload.append(key)

	for key in to_unload:
		_unload_chunk(key)


func _build_chunk(cx: int, cz: int) -> void:
	var key := _key(cx, cz)
	if _loaded.has(key):
		return

	var chunk_node := terrain_generator.build_chunk_terrain(cx, cz)
	add_child(chunk_node)

	if terrain_generator.chunk_has_vroad(cx):
		var road := terrain_generator.build_chunk_road(cx, cz, "z")
		chunk_node.add_child(road)
	if terrain_generator.chunk_has_hroad(cz):
		var road := terrain_generator.build_chunk_road(cx, cz, "x")
		chunk_node.add_child(road)

	_loaded[key] = chunk_node


func _unload_chunk(key: String) -> void:
	var node: Node3D = _loaded.get(key)
	if node and is_instance_valid(node):
		node.queue_free()
	_loaded.erase(key)


func _full_rebuild() -> void:
	for key in _loaded.keys():
		_unload_chunk(key)
	_loaded.clear()

	if not target or not is_instance_valid(target):
		return

	var px: float = target.global_position.x
	var pz: float = target.global_position.z
	var ccx: int = roundi(px / CHUNK_SIZE)
	var ccz: int = roundi(pz / CHUNK_SIZE)

	for dx in range(-VIEW_RINGS, VIEW_RINGS + 1):
		for dz in range(-VIEW_RINGS, VIEW_RINGS + 1):
			_build_chunk(ccx + dx, ccz + dz)


func _key(cx: int, cz: int) -> String:
	return "%d,%d" % [cx, cz]


func get_loaded_count() -> int:
	return _loaded.size()


func clear_all() -> void:
	for key in _loaded.keys():
		_unload_chunk(key)
	_loaded.clear()
