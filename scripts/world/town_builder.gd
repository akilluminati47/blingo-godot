class_name TownBuilder
extends Node
## Static town generation.  Places buildings, roads, fountain, plaza, and the
## Blingo statue at the world origin.  Persistent — built once at startup, never
## streamed in/out.

@export var terrain_generator: TerrainGenerator


func _ready() -> void:
	if not terrain_generator:
		push_error("TownBuilder: terrain_generator not assigned.")
		return

	var scene_root := get_tree().root.get_node("Main") if get_tree().root.has_node("Main") else get_tree().root
	call_deferred("_build", scene_root)


func _build(parent: Node) -> void:
	var town_root := Node3D.new()
	town_root.name = "Town"
	parent.add_child(town_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = 9001

	## Low-res ground apron under town footprint so buildings don't float
	_place_terrain_plane(town_root, 208.0, 208.0, 52, 52, 47.0, 2.0,
		_make_mat(Color(0.29, 0.36, 0.24)), -0.15)
	_place_terrain_plane(town_root, 12.8, 208.0, 5, 52, -20.0, 2.0,
		_make_mat(Color(0.173, 0.180, 0.200)), -0.06)
	_place_terrain_plane(town_root, 12.8, 208.0, 5, 52, 100.0, 2.0,
		_make_mat(Color(0.173, 0.180, 0.200)), -0.06)
	_place_terrain_plane(town_root, 208.0, 12.8, 52, 5, 47.0, -17.0,
		_make_mat(Color(0.173, 0.180, 0.200)), -0.06)

	var wall_mat := _make_mat(Color(0.48, 0.39, 0.33))
	var glass_mat := _make_mat(Color(0.07, 0.07, 0.10))
	var curb_mat := _make_mat(Color(0.73, 0.72, 0.69))
	var step_mat := _make_mat(Color(0.73, 0.71, 0.65))
	var roof_mat := _make_mat(Color(0.43, 0.22, 0.17))
	var awning_mat := _make_mat(Color(0.54, 0.18, 0.18))
	var door_mat := _make_mat(Color(0.20, 0.15, 0.10))
	var road_mat := _make_mat(Color(0.173, 0.180, 0.200))
	var lot_mat := _make_mat(Color(0.208, 0.216, 0.239))
	var dark_mat := _make_mat(Color(0.20, 0.16, 0.11))
	var fountain_mat := _make_mat(Color(0.60, 0.58, 0.55))
	var column_mat := _make_mat(Color(0.85, 0.82, 0.77))
	var hall_mat := _make_mat(Color(0.54, 0.50, 0.42))
	var court_mat := _make_mat(Color(0.60, 0.60, 0.64))
	var bank_mat := _make_mat(Color(0.49, 0.54, 0.59))

	## ---------- Main street shops ----------
	var north_names := ["DINER", "BAKERY", "BOOKS", "TOOLS", "PIZZA"]
	var south_names := ["MART", "LIQUOR", "BARBER", "TAILOR", "RADIO"]
	for i in range(5):
		_build_shop(town_root, 12.0 + i * 13.0, -5.9, 9.5, 7.0, 3.6, -1,
			wall_mat, glass_mat, curb_mat, awning_mat, door_mat)
		_build_shop(town_root, 12.0 + i * 13.0, -28.1, 9.5, 7.0, 3.6, 1,
			wall_mat, glass_mat, curb_mat, awning_mat, door_mat)

	## ---------- Civic buildings ----------
	_build_grand(town_root, 85.0, -2.0, 19.5, 13.0, 7.0, -1, hall_mat, column_mat, curb_mat, step_mat, door_mat)
	_build_grand(town_root, 85.0, -34.0, 18.0, 12.0, 6.5, 1, court_mat, column_mat, curb_mat, step_mat, door_mat)
	_build_grand(town_root, 0.0, -50.2, 24.0, 16.0, 8.6, 1, bank_mat, column_mat, curb_mat, step_mat, door_mat)

	## ---------- Fountain ----------
	_build_fountain(town_root, fountain_mat)

	## ---------- Plaza shops ----------
	var plaza_shops := [["SUPER MART", 20.0], ["PHARMACY", 12.0], ["GYM", 10.0], ["CAFE", 10.0]]
	var px: float = 18.0
	for entry in plaza_shops:
		var w2: float = entry[1]
		_build_shop(town_root, px + w2 / 2.0, 58.0, w2, 9.0, 4.6, -1,
			wall_mat, glass_mat, curb_mat, awning_mat, door_mat)
		px += w2 + 1.5

	_build_parking_lot(town_root, 42.0, 36.0, 58.0, 26.0, 3, lot_mat)
	_place_terrain_plane(town_root, 23.2, 6.4, 12, 4, 82.6, 36.0, road_mat, 0.04)
	_place_terrain_plane(town_root, 23.2, 6.4, 12, 4, -2.6, 22.0, road_mat, 0.04)

	## ---------- Church ----------
	_build_church(town_root, 25.0, 81.0, wall_mat, roof_mat, door_mat)

	## ---------- Jelly Park statue ----------
	_build_park(town_root, 129.0, -42.0, curb_mat, step_mat, dark_mat)

	print("[TownBuilder] Town built.")


## ---------- Shop ----------
func _build_shop(parent: Node, x: float, z: float, w: float, d: float, h: float,
		face_dir: int, wall_mat: Material, glass_mat: Material, curb_mat: Material,
		awning_mat: Material, door_mat: Material) -> void:
	var y0 := terrain_generator.ground_height(x, z)
	var fz := z + face_dir * (d / 2.0 + 0.03)

	_add_box(parent, x, y0 + h / 2.0, z, w, h, d, wall_mat)
	_add_box(parent, x, y0 + h + 0.2, z, w + 0.2, 0.4, d + 0.2, curb_mat)
	_add_box(parent, x - w * 0.12, y0 + h * 0.38, fz, w * 0.55, h * 0.42, 0.04, glass_mat)
	_add_box(parent, x + w * 0.32, y0 + 0.9, fz, 0.9, 1.8, 0.08, door_mat)

	var awn_root := Node3D.new()
	awn_root.position = Vector3(x, y0 + h * 0.62, z + face_dir * (d / 2.0 + 0.6))
	awn_root.rotation_degrees.x = face_dir * 14.0
	parent.add_child(awn_root)
	_add_box(awn_root, 0.0, 0.0, 0.0, w * 0.9, 0.08, 1.3, awning_mat)


## ---------- Grand civic building ----------
func _build_grand(parent: Node, x: float, z: float, w: float, d: float, h: float,
		face_dir: int, wall_mat: Material, col_mat: Material, curb_mat: Material,
		step_mat: Material, door_mat: Material) -> void:
	var y0 := terrain_generator.ground_height(x, z)
	var fz := z + face_dir * d / 2.0

	_add_box(parent, x, y0 + h / 2.0, z, w, h, d, wall_mat)

	for i in range(4):
		var colx := x - w / 4.0 + i * (w / 6.0)
		_add_cylinder(parent, colx, y0 + h / 2.0, fz + face_dir * 1.0, 0.28, 0.32, h, col_mat)

	_add_box(parent, x, y0 + h + 0.15, z + face_dir * 0.8, w + 1.0, 0.3, d + 2.6, curb_mat)

	for sd in [[1.1, 0.11, 1.85], [0.55, 0.33, 1.575]]:
		_add_box(parent, x, y0 + sd[1], fz + face_dir * sd[2], w * 0.55, 0.22, sd[0], step_mat)

	var dw := min(w * 0.22, 3.4); var dh := min(h * 0.6, 4.6)
	_add_box(parent, x, y0 + (dh + 0.4) / 2.0 - 0.2, fz + face_dir * 0.02, dw + 0.5, dh + 0.4, 0.08, curb_mat)
	_add_box(parent, x, y0 + dh / 2.0, fz + face_dir * 0.06, dw, dh, 0.16, door_mat)


## ---------- Fountain ----------
func _build_fountain(parent: Node, stone_mat: Material) -> void:
	const FZ: float = -28.2
	var y0 := terrain_generator.ground_height(0.0, FZ)
	const BASIN_H: float = 0.85

	_add_cylinder(parent, 0.0, y0 + BASIN_H / 2.0, FZ, 2.8, 3.0, BASIN_H, stone_mat)

	var water_mat := _make_mat(Color(0.25, 0.50, 0.68))
	_add_cylinder(parent, 0.0, y0 + BASIN_H + 0.06, FZ, 2.45, 2.45, 0.02, water_mat)

	_add_cylinder(parent, 0.0, y0 + BASIN_H + 0.75, FZ, 0.42, 0.62, 1.5, stone_mat)
	_add_cylinder(parent, 0.0, y0 + BASIN_H + 1.55, FZ, 1.05, 0.22, 0.45, stone_mat)

	var spout_mat := StandardMaterial3D.new()
	spout_mat.albedo_color = Color(0.50, 0.72, 0.85)
	spout_mat.emission_enabled = true
	spout_mat.emission = Color(0.16, 0.35, 0.47)
	spout_mat.emission_energy_multiplier = 0.6
	var spout := MeshInstance3D.new()
	spout.mesh = SphereMesh.new()
	spout.mesh.radius = 0.26; spout.mesh.height = 0.52
	spout.material_override = spout_mat
	spout.position = Vector3(0.0, y0 + BASIN_H + 1.85, FZ)
	spout.name = "FountainSpout"
	parent.add_child(spout)


## ---------- Church ----------
func _build_church(parent: Node, x: float, z: float,
		wall_mat: Material, roof_mat: Material, door_mat: Material) -> void:
	const W: float = 11.0; const D: float = 16.0; const H: float = 5.2
	var y0 := terrain_generator.ground_height(x, z)

	_add_box(parent, x, y0 + H / 2.0, z, W, H, D, wall_mat)
	_add_cylinder(parent, x, y0 + H + 1.3, z + D / 2.0 - 1.5, 0.55, 0.8, 2.6, wall_mat)
	_add_box(parent, x, y0 + H + 0.15, z, W + 0.6, 0.3, D + 0.6, roof_mat)
	_add_box(parent, x, y0 + 1.2, z - D / 2.0 + 0.04, 1.5, 2.4, 0.12, door_mat)


## ---------- Park & Blingo statue ----------
func _build_park(parent: Node, cx: float, cz: float,
		curb_mat: Material, step_mat: Material, dark_mat: Material) -> void:
	var y0 := terrain_generator.ground_height(cx, cz)

	_add_cylinder(parent, cx, y0 + 0.03, cz, 6.4, 6.4, 0.05, curb_mat)
	_add_box(parent, cx, y0 + 0.25, cz, 6.2, 0.5, 6.2, step_mat)

	var plinth_h: float = 0.86; var plinth_base := y0 + 0.5
	_add_box(parent, cx, plinth_base + plinth_h / 2.0, cz, 4.6, plinth_h, 4.6, dark_mat)

	var statue_base := plinth_base + plinth_h + 0.22
	_add_box(parent, cx, statue_base + 2.0, cz, 1.2, 4.0, 1.2, curb_mat)

	_add_sphere(parent, cx, statue_base + 4.2, cz, 0.55, curb_mat)


## ---------- Parking lot ----------
func _build_parking_lot(parent: Node, x: float, z: float,
		w: float, d: float, rows: int, lot_mat: Material) -> void:
	_place_terrain_plane(parent, w, d, 16, 10, x, z, lot_mat, 0.05)

	var line_mat := _make_mat(Color(0.85, 0.85, 0.82))
	for r in range(rows):
		var rz := z - d / 2.0 + (r + 0.5) * (d / float(rows))
		var n_lines := int(w / 3.2) - 1
		for i in range(n_lines):
			var lx := x - w / 2.0 + 2.4 + i * 3.2
			_add_box(parent, lx, terrain_generator.ground_height(lx, rz) + 0.09, rz, 0.14, 0.02, 2.6, line_mat)


## ---------- Helpers ----------
func _add_box(parent: Node, px: float, py: float, pz: float, w: float, h: float, d: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.mesh.size = Vector3(w, h, d)
	mi.material_override = mat
	mi.position = Vector3(px, py, pz)
	parent.add_child(mi)


func _add_cylinder(parent: Node, px: float, py: float, pz: float,
		top_r: float, bottom_r: float, h: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = CylinderMesh.new()
	mi.mesh.top_radius = top_r; mi.mesh.bottom_radius = bottom_r; mi.mesh.height = h
	mi.material_override = mat
	mi.position = Vector3(px, py, pz)
	parent.add_child(mi)


func _add_sphere(parent: Node, px: float, py: float, pz: float, r: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	mi.mesh.radius = r; mi.mesh.height = r * 2.0
	mi.material_override = mat
	mi.position = Vector3(px, py, pz)
	parent.add_child(mi)


func _place_terrain_plane(parent: Node, w: float, d: float,
		seg_w: int, seg_d: int, cx: float, cz: float, mat: Material, lift: float = 0.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var nx := seg_w + 1; var nz := seg_d + 1
	for iz in range(nz):
		for ix in range(nx):
			var lx := (float(ix) / float(seg_w) - 0.5) * w
			var lz := (float(iz) / float(seg_d) - 0.5) * d
			var h := terrain_generator.ground_height(cx + lx, cz + lz) + lift
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(lx, h, lz))

	for iz in range(seg_d):
		for ix in range(seg_w):
			var a := iz * nx + ix; var b := a + 1; var c := a + nx; var d2 := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d2); st.add_index(c)

	st.generate_normals()

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = Vector3(cx, 0.0, cz)
	parent.add_child(mi)


func _make_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
