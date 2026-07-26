extends Node3D
class_name BlobBuilder

# Procedural blob character — matches the original JavaScript buildBlob
# Builds a cousin/zombie from box and sphere primitives

@export var body_color: Color = Color.ORANGE
@export var scale: float = 1.0
@export var is_zombie: bool = false
@export var droopy_eyes: bool = false
@export var brain_exposed: bool = false
@export var blind: bool = false

var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var head: Node3D
var wob: Node3D
var gun_arm: int = 0
var off_arm: int = 1
var gun_socket: Node3D


func _ready() -> void:
	build_blob()


func build_blob() -> void:
	# Root scale
	scale = Vector3.ONE * scale
	
	# Wob container (for squash/stretch)
	wob = Node3D.new()
	wob.name = "Wob"
	add_child(wob)
	
	# Body
	var body := _box(1.1, 1.24, 1.0, body_color)
	body.position = Vector3(0, 0.62, 0)
	wob.add_child(body)
	
	# Head
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.28, 0)
	wob.add_child(head)
	
	var skull := _ball(0.84, body_color)
	skull.scale = Vector3(0.84, 0.8, 0.8)
	head.add_child(skull)
	
	# Eyes
	for s in [-1, 1]:
		var eye := _ball(0.26, Color.WHITE)
		eye.position = Vector3(0.16 * s, 0.05, 0.32)
		head.add_child(eye)
		
		var pupil := _ball(0.11, Color(0.1, 0.1, 0.1))
		pupil.position = Vector3(0.16 * s, 0.05, 0.415)
		head.add_child(pupil)
	
	# Mouth
	var mouth := _box(0.32, 0.1, 0.1, Color(0.48, 0.19, 0.13))
	mouth.position = Vector3(0, -0.16, 0.36)
	head.add_child(mouth)
	
	# Arms
	arms.clear()
	for s in [-1, 1]:
		var shoulder := Node3D.new()
		shoulder.name = "Arm" + str(arms.size())
		shoulder.position = Vector3(0.5 * s, 0.95, 0)
		wob.add_child(shoulder)
		
		var arm := _box(0.4, 0.8, 0.4, body_color)
		arm.position = Vector3(0, -0.26, 0)
		shoulder.add_child(arm)
		
		var hand := _box(0.56, 0.52, 0.56, Color(1.0, 0.84, 0.66))
		hand.position = Vector3(0, -0.56, 0)
		shoulder.add_child(hand)
		
		arms.append(shoulder)
	
	# Gun socket (on right arm/hand)
	gun_socket = Node3D.new()
	gun_socket.name = "GunSocket"
	gun_socket.position = Vector3(0, -0.36, 0.2)
	arms[gun_arm].add_child(gun_socket)
	
	# Legs
	legs.clear()
	for s in [-1, 1]:
		var hip := Node3D.new()
		hip.name = "Leg" + str(legs.size())
		hip.position = Vector3(0.2 * s, 0.42, 0)
		wob.add_child(hip)
		
		var leg := _box(0.4, 0.68, 0.4, Color(0.23, 0.29, 0.42))
		leg.position = Vector3(0, -0.2, 0)
		hip.add_child(leg)
		
		var foot := _box(0.44, 0.26, 0.68, Color(0.17, 0.17, 0.2))
		foot.position = Vector3(0, -0.42, 0.06)
		hip.add_child(foot)
		
		legs.append(hip)


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
