class_name TerrainGenerator
extends Node
## Procedural terrain generation matching the original BLINGO ground height system.
## Uses FastNoiseLite (Simplex) for multi-octave height, road flattening,
## town rect flattening, and building-pad blending.

const WORLD_SEED: int = 1337
const CHUNK_SIZE: float = 40.0
const VERTEX_DENSITY: int = 64        ## vertices per chunk edge (64x64 grid = 65x65 verts)
const NOISE_SCALE_1: float = 57.0
const NOISE_SCALE_2: float = 23.0
const NOISE_SCALE_3: float = 131.0
const ROAD_SPACING: float = 120.0
const ROAD_Z_OFFSET: float = -17.0   ## horizontal roads (east-west)
const ROAD_X_OFFSET: float = -20.0   ## vertical roads (north-south)
const ROAD_HALF_WIDTH: float = 6.4

## Town footprint rectangles [x0, z0, x1, z1] — terrain is graded flat inside these.
const TOWN_RECTS: Array = [
	[-16, -60, 110, 6],     ## main street
	[8, 12, 78, 64],        ## shopping plaza
	[69, 32, 96, 40],       ## east connector
	[-15, 18, 10, 26],      ## west connector
	[16, 68, 62, 94],       ## church + graveyard
	[112, -56, 146, -28],   ## jelly park
	[108, 48, 128, 66],     ## Red's Chili
	[103, -140, 141, -104], ## Blob Lounge
	[105, 160, 143, 196],   ## Jelly House
]

var _noise1: FastNoiseLite
var _noise2: FastNoiseLite
var _noise3: FastNoiseLite
var _flat_pads: Array[FlatPad] = []
var _grass_material: StandardMaterial3D
var _road_material: StandardMaterial3D


class FlatPad:
	var x: float
	var z: float
	var hw: float
	var hd: float
	var apron: float
	var y: float

	func _init(px: float, pz: float, phw: float, phd: float, papron: float, py: float) -> void:
		x = px; z = pz; hw = phw; hd = phd; apron = papron; y = py


func _init() -> void:
	_noise1 = FastNoiseLite.new()
	_noise1.seed = WORLD_SEED
	_noise1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise1.frequency = 1.0 / NOISE_SCALE_1

	_noise2 = FastNoiseLite.new()
	_noise2.seed = WORLD_SEED + 1
	_noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise2.frequency = 1.0 / NOISE_SCALE_2

	_noise3 = FastNoiseLite.new()
	_noise3.seed = WORLD_SEED + 2
	_noise3.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise3.frequency = 1.0 / NOISE_SCALE_3

	_grass_material = StandardMaterial3D.new()
	_grass_material.albedo_color = Color(0.29, 0.36, 0.24)

	_road_material = StandardMaterial3D.new()
	_road_material.albedo_color = Color(0.173, 0.180, 0.200)


func add_flat_pad(x: float, z: float, hw: float, hd: float, apron: float) -> FlatPad:
	var y: float = ground_height(x, z)
	var pad := FlatPad.new(x, z, hw, hd, apron, y)
	_flat_pads.append(pad)
	return pad


func remove_flat_pad(pad: FlatPad) -> void:
	var idx := _flat_pads.find(pad)
	if idx >= 0:
		_flat_pads.remove_at(idx)


func clear_flat_pads() -> void:
	_flat_pads.clear()


## Compute terrain height at world position (x, z).
## Matches the original's groundHeight: three noise octaves,
## road grading, town-rect flattening, and building-pad blending.
func ground_height(x: float, z: float) -> float:
	var n1: float = (_noise1.get_noise_2d(x, z) - 0.5) * 3.4
	var n2: float = (_noise2.get_noise_2d(x, z) - 0.5) * 1.1
	var n3: float = (_noise3.get_noise_2d(x, z) - 0.5) * 2.2
	var base: float = n1 + n2 + n3

	var dr: float = min(road_axis_dist_x(x), road_axis_dist(z))
	var f: float = _smoothstep(clampf((dr - 6.7) / 10.0, 0.0, 1.0))

	var td: float = INF
	for r in TOWN_RECTS:
		td = min(td, _rect_dist(x, z, r))
	f = min(f, _smoothstep(clampf((td - 1.0) / 12.0, 0.0, 1.0)))

	var g: float = base * (0.12 + 0.88 * f)

	var pad_hold: float = _smoothstep(clampf((dr - 6.7) / 3.0, 0.0, 1.0))
	if pad_hold > 0.0:
		for p in _flat_pads:
			var d_out: float = max(abs(x - p.x) - p.hw, abs(z - p.z) - p.hd)
			if d_out >= p.apron:
				continue
			var k: float = 0.0 if d_out <= 0.0 else _smoothstep(d_out / p.apron)
			g = lerpf(p.y, g, max(k, 1.0 - pad_hold))

	return g


## Distance from a world-z coordinate to the nearest horizontal road centreline.
func road_axis_dist(v: float) -> float:
	var m: float = fposmod(v + ROAD_Z_OFFSET, ROAD_SPACING)
	return min(m, ROAD_SPACING - m)


## Distance from a world-x coordinate to the nearest vertical road centreline.
func road_axis_dist_x(v: float) -> float:
	var m: float = fposmod(v + ROAD_X_OFFSET, ROAD_SPACING)
	return min(m, ROAD_SPACING - m)


## Test if a world point lies on a road (within margin).
func on_road(x: float, z: float, margin: float = 0.0) -> bool:
	return road_axis_dist(x) < ROAD_HALF_WIDTH + margin or road_axis_dist_x(x) < ROAD_HALF_WIDTH + margin


## Test if a world point falls inside any town rectangle (within margin).
func in_town(x: float, z: float, margin: float = 0.0) -> bool:
	for r in TOWN_RECTS:
		if _rect_dist(x, z, r) <= margin:
			return true
	return false


## Check whether a chunk column has a vertical road running through it.
func chunk_has_vroad(cx: int) -> bool:
	return ((cx % 3) + 3) % 3 == 0


## Check whether a chunk row has a horizontal road running through it.
func chunk_has_hroad(cz: int) -> bool:
	return ((cz % 3) + 3) % 3 == 0


## Build a terrain ArrayMesh for one chunk at chunk coordinates (cx, cz).
## Returns a MeshInstance3D ready to add to the scene tree.
func build_chunk_terrain(cx: int, cz: int) -> Node3D:
	var ox: float = cx * CHUNK_SIZE
	var oz: float = cz * CHUNK_SIZE

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var verts_per_edge: int = VERTEX_DENSITY + 1
	var step: float = CHUNK_SIZE / float(VERTEX_DENSITY)

	for iz in range(verts_per_edge):
		for ix in range(verts_per_edge):
			var lx: float = ix * step
			var lz: float = iz * step
			var wx: float = ox + lx
			var wz: float = oz + lz
			var h: float = ground_height(wx, wz)

			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(lx / CHUNK_SIZE, lz / CHUNK_SIZE))
			st.add_vertex(Vector3(lx, h, lz))

	for iz in range(VERTEX_DENSITY):
		for ix in range(VERTEX_DENSITY):
			var a: int = iz * verts_per_edge + ix
			var b: int = a + 1
			var c: int = a + verts_per_edge
			var d: int = c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)

	st.generate_normals()

	var parent := Node3D.new()
	parent.name = "Chunk_%d_%d" % [cx, cz]
	parent.position = Vector3(ox, 0.0, oz)

	var terrain_mi := MeshInstance3D.new()
	terrain_mi.mesh = st.commit()
	terrain_mi.material_override = _grass_material
	terrain_mi.name = "Terrain"
	parent.add_child(terrain_mi)

	return parent


## Build a road plane for one chunk.  axis = "z" for vertical (north-south) roads,
## axis = "x" for horizontal (east-west) roads.
func build_chunk_road(cx: int, cz: int, axis: String) -> MeshInstance3D:
	var ox: float = cx * CHUNK_SIZE
	var oz: float = cz * CHUNK_SIZE

	var w: float
	var d: float
	var world_x: float
	var world_z: float

	if axis == "z":
		w = ROAD_HALF_WIDTH * 2.0
		d = CHUNK_SIZE
		world_x = ox + ROAD_X_OFFSET
		world_z = oz
	else:
		w = CHUNK_SIZE
		d = ROAD_HALF_WIDTH * 2.0
		world_x = ox
		world_z = oz + ROAD_Z_OFFSET

	var seg_w: int = max(1, int(w / 2.5))
	var seg_d: int = max(1, int(d / 2.5))
	const lift: float = 0.04

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var nx: int = seg_w + 1
	var nz: int = seg_d + 1

	for iz in range(nz):
		for ix in range(nx):
			var lx: float = (float(ix) / float(seg_w) - 0.5) * w
			var lz: float = (float(iz) / float(seg_d) - 0.5) * d
			var h: float = ground_height(world_x + lx, world_z + lz) + lift
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(lx, h, lz))

	for iz in range(seg_d):
		for ix in range(seg_w):
			var a: int = iz * nx + ix
			var b: int = a + 1
			var c: int = a + nx
			var d2: int = c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d2); st.add_index(c)

	st.generate_normals()

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _road_material
	mi.position = Vector3(world_x, 0.0, world_z)
	mi.name = "Road_%s_%d_%d" % [axis, cx, cz]
	return mi


func _smoothstep(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _rect_dist(x: float, z: float, r: Array) -> float:
	var dx: float = max(r[0] - x, 0.0, x - r[2])
	var dz: float = max(r[1] - z, 0.0, z - r[3])
	return sqrt(dx * dx + dz * dz)
