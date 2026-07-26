extends MeshInstance3D
class_name BulletTracer

# Instant-hit bullet tracer — a thin glowing box that streaks from muzzle to impact
# and fades out over its lifetime. Not a projectile, purely visual.

var lifetime: float = 0.07
var _elapsed: float = 0.0
var _material: StandardMaterial3D


static func create(from: Vector3, to: Vector3, parent: Node = null) -> BulletTracer:
	var len = from.distance_to(to)
	if len < 0.1:
		return null

	var tracer := BulletTracer.new()
	tracer.name = "BulletTracer"

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.015, 0.015, len)
	tracer.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.88, 0.54, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.88, 0.54)
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tracer.material_override = mat

	tracer._material = mat

	tracer.position = from.lerp(to, 0.5)
	tracer.look_at(to, Vector3.UP)

	if parent:
		parent.add_child(tracer)
	else:
		var root = Engine.get_main_loop()
		if root is SceneTree:
			root.root.add_child(tracer)

	tracer._elapsed = 0.0
	tracer.lifetime = 0.07

	return tracer


func _process(delta: float) -> void:
	_elapsed += delta

	if _elapsed >= lifetime:
		queue_free()
		return

	var progress = _elapsed / lifetime
	_material.albedo_color.a = lerpf(0.85, 0.0, progress)
	# Stretch slightly over time for a speed-blur effect
	scale.z = lerpf(1.0, 1.3, progress)
