extends Node3D
class_name BlobBuilder

# Procedural blob character — matches the original JavaScript buildBlob
# Builds a cousin/zombie from box and sphere primitives

@export var body_color: Color = Color.ORANGE
@export var scale_value: float = 1.0
@export var is_zombie: bool = false
@export var droopy_eyes: bool = false
@export var brain_exposed: bool = false
@export var blind: bool = false
@export var hand_color: Color = Color(1.0, 0.84, 0.66)
@export var knuckle_color: Color = Color(0.94, 0.78, 0.60)

var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var eyes: Array[Node3D] = []
var pupils: Array[Node3D] = []
var head: Node3D
var body_mesh: MeshInstance3D
var skull_mesh: MeshInstance3D
var brain_mesh: Node3D
var mouth_mesh: MeshInstance3D
var wob: Node3D
var gun_arm: int = 0
var off_arm: int = 1
var gun_socket: Node3D
var arm_gone: Array[bool] = [false, false]
var leg_gone: Array[bool] = [false, false]
var head_gone: bool = false
var body_gone: bool = false
var hang_eye: Node3D = null
var rot_heart: Node3D = null
var rot_heart_r: float = 0.0
var skin_list: Array = []
var stain_count: Dictionary = { "n": 0 }
var flash_t: float = 0.0


func _ready() -> void:
	build_blob()


func build_blob() -> void:
	# Clear existing children if rebuilding
	for c in get_children():
		c.queue_free()
	arms.clear()
	legs.clear()
	eyes.clear()
	pupils.clear()
	skin_list.clear()
	
	# Root scale
	scale = Vector3.ONE * scale_value
	
	# Wob container (for squash/stretch)
	wob = Node3D.new()
	wob.name = "Wob"
	add_child(wob)
	
	# Body
	body_mesh = _box(1.1, 1.24, 1.0, body_color)
	body_mesh.position = Vector3(0, 0.62, 0)
	wob.add_child(body_mesh)
	
	# Head
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.28, 0)
	wob.add_child(head)
	
	# Skull (intact)
	skull_mesh = _ball(0.84, body_color)
	skull_mesh.scale = Vector3(0.84, 0.8, 0.8)
	head.add_child(skull_mesh)
	
	# Exposed-brain mesh (hidden until cracked open)
	brain_mesh = _build_brain_mesh()
	brain_mesh.visible = brain_exposed
	head.add_child(brain_mesh)
	skull_mesh.visible = not brain_exposed
	
	# Eyes
	var eye_color := Color.WHITE
	var pupil_color := Color(0.1, 0.1, 0.1)
	if blind:
		eye_color = Color("e2e6e2")
		pupil_color = Color("bfc3c6")
	elif is_zombie:
		pupil_color = Color("7a1010")
	
	for s in [-1, 1]:
		var eye := _ball(0.26, eye_color)
		eye.position = Vector3(0.16 * s, -0.02 if droopy_eyes else 0.05, 0.32)
		head.add_child(eye)
		eyes.append(eye)
		
		var pupil := _ball(0.11, pupil_color)
		pupil.position = Vector3(0.16 * s, -0.06 if droopy_eyes else 0.05, 0.415)
		head.add_child(pupil)
		pupils.append(pupil)
		
		if droopy_eyes:
			var lid := _box(0.56, 0.26, 0.2, body_color)
			lid.position = Vector3(0.16 * s, 0.09, 0.37)
			lid.rotation.x = 0.32
			head.add_child(lid)
		elif is_zombie:
			var brow := _box(0.28, 0.08, 0.08, Color("2f4020"))
			brow.position = Vector3(0.16 * s, 0.17, 0.36)
			brow.rotation.z = 0.5 * s
			head.add_child(brow)
	
	# Mouth
	var mouth_color := Color("4a1414") if is_zombie else Color("7a3020")
	var mouth_width := 0.4 if is_zombie else 0.32
	var mouth_height := 0.2 if is_zombie else 0.1
	mouth_mesh = _box(mouth_width, mouth_height, 0.1, mouth_color)
	mouth_mesh.position = Vector3(0, -0.16, 0.36)
	head.add_child(mouth_mesh)
	
	# Arms
	for s in [-1, 1]:
		var idx := arms.size()
		var shoulder := Node3D.new()
		shoulder.name = "Arm" + str(idx)
		shoulder.position = Vector3(0.5 * s, 0.95, 0)
		wob.add_child(shoulder)
		
		var arm := _box(0.4, 0.8, 0.4, body_color)
		arm.position = Vector3(0, -0.26, 0)
		shoulder.add_child(arm)
		
		var hc := hand_color
		if hc.a == 0.0:
			hc = Color("8aa85a") if is_zombie else Color(1.0, 0.84, 0.66)
		var kc := knuckle_color
		if kc.a == 0.0 or kc == Color(0.94, 0.78, 0.60):
			if is_zombie:
				kc = Color("789748") if hc == Color("8aa85a") else hc.darkened(0.14)
		
		var hand := _box(0.56, 0.52, 0.56, hc)
		hand.position = Vector3(0, -0.56, 0)
		shoulder.add_child(hand)
		
		var knuck := _box(0.6, 0.18, 0.28, kc)
		knuck.position = Vector3(0, -0.52, 0.13)
		shoulder.add_child(knuck)
		
		arms.append(shoulder)
	
	# Gun socket (on right arm/hand)
	gun_socket = Node3D.new()
	gun_socket.name = "GunSocket"
	gun_socket.position = Vector3(0, -0.36, 0.2)
	arms[gun_arm].add_child(gun_socket)
	
	# Legs
	for s in [-1, 1]:
		var idx := legs.size()
		var hip := Node3D.new()
		hip.name = "Leg" + str(idx)
		hip.position = Vector3(0.2 * s, 0.42, 0)
		wob.add_child(hip)
		
		var leg_color := Color("39432a") if is_zombie else Color(0.23, 0.29, 0.42)
		var foot_color := Color("2c331f") if is_zombie else Color(0.17, 0.17, 0.2)
		
		var leg := _box(0.4, 0.68, 0.4, leg_color)
		leg.position = Vector3(0, -0.2, 0)
		hip.add_child(leg)
		
		var foot := _box(0.44, 0.26, 0.68, foot_color)
		foot.position = Vector3(0, -0.42, 0.06)
		hip.add_child(foot)
		
		legs.append(hip)
	
	# Collect skin meshes for damage flash
	_collect_skin_meshes()


func _build_brain_mesh() -> Node3D:
	var group := Node3D.new()
	group.name = "BrainMesh"
	
	# Open skull bowl
	var bowl_mesh := SphereMesh.new()
	bowl_mesh.radius = 0.84
	bowl_mesh.height = 0.84 * 2
	bowl_mesh.radial_segments = 16
	bowl_mesh.rings = 12
	
	var bowl_mat := StandardMaterial3D.new()
	bowl_mat.albedo_color = body_color
	bowl_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var bowl := MeshInstance3D.new()
	bowl.mesh = bowl_mesh
	bowl.set_surface_override_material(0, bowl_mat)
	bowl.scale = Vector3(0.84, 0.8, 0.8)
	group.add_child(bowl)
	
	# Pink brain dome
	var brain_dome := _ball(0.62, Color("d77a8e"))
	brain_dome.scale = Vector3(0.62, 0.48, 0.62)
	brain_dome.position = Vector3(0, 0.15, 0)
	group.add_child(brain_dome)
	
	# Brain lobes
	for i in range(5):
		var lobe := _ball(0.14 + randf() * 0.09, Color("c76b80"))
		var a := randf() * TAU
		var rr := 0.05 + randf() * 0.11
		lobe.position = Vector3(cos(a) * rr, 0.19 + randf() * 0.05, sin(a) * rr)
		group.add_child(lobe)
	
	return group


func _collect_skin_meshes() -> void:
	skin_list.clear()
	_collect_meshes_recursive(wob)


func _collect_meshes_recursive(node: Node) -> void:
	_add_to_skin_list(node, wob)
	for child in node.get_children():
		_collect_meshes_recursive(child)


func _add_to_skin_list(node: Node, root: Node3D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := mi.get_surface_override_material(0)
		if mat:
			skin_list.append({ "mesh": mi, "mat": mat })


func _box(w: float, h: float, d: float, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, h, d)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	return mi


func _ball(r: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2
	mesh.radial_segments = 16
	mesh.rings = 12
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	return mi


# ── Runtime modifications ──

func expose_brain() -> void:
	if brain_mesh:
		brain_mesh.visible = true
	if skull_mesh:
		skull_mesh.visible = false


func hide_head() -> void:
	head_gone = true
	if head:
		head.visible = false


func hide_arm(idx: int) -> void:
	if idx >= 0 and idx < arms.size():
		arms[idx].visible = false
		arm_gone[idx] = true


func hide_leg(idx: int) -> void:
	if idx >= 0 and idx < legs.size():
		legs[idx].visible = false
		leg_gone[idx] = true


func flash_red(duration: float = 0.08) -> void:
	flash_t = duration


func flash_green(duration: float = 0.08) -> void:
	flash_t = duration
	# Override to flash green instead in derived usage
	for item in skin_list:
		var mat: StandardMaterial3D = item.mat
		mat.albedo_color = Color.GREEN
