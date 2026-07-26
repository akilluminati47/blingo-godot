extends Node3D
class_name PlayerController

@export var walk_speed: float = 7.0
@export var sprint_speed: float = 11.0
@export var jump_velocity: float = 12.0
@export var mouse_sensitivity: float = 0.002
@export var gravity: float = 28.0

var velocity: Vector3 = Vector3.ZERO
var grounded: bool = true
var sprinting: bool = false
var ground_y: float = 0.0
var cam_yaw: float = 0.0
var cam_pitch: float = -0.24
var yaw: float = 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	position.y = 1.0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and GameState.state == GameState.GameState.PLAYING:
		cam_yaw -= event.relative.x * mouse_sensitivity
		cam_pitch -= event.relative.y * mouse_sensitivity
		cam_pitch = clampf(cam_pitch, -PI / 2.2, PI / 3.0)


func _process(delta: float) -> void:
	if GameState.state != GameState.GameState.PLAYING:
		return
	
	GameState.update_clock(delta)
	GameState.time += delta
	
	# input
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)
	sprinting = Input.is_action_pressed("sprint")
	
	# movement direction relative to camera yaw
	var forward := Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var move_dir := (forward * input_dir.y + right * input_dir.x).normalized()
	
	# speed
	var speed := sprint_speed if sprinting else walk_speed
	var target_vel := move_dir * speed
	
	# smooth horizontal movement
	velocity.x = lerpf(velocity.x, target_vel.x, 1.0 - exp(-12.0 * delta))
	velocity.z = lerpf(velocity.z, target_vel.z, 1.0 - exp(-12.0 * delta))
	
	# gravity & jumping
	if grounded:
		velocity.y = 0
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
			grounded = false
	else:
		velocity.y -= gravity * delta
	
	# apply movement
	position += velocity * delta
	
	# ground clamp
	if position.y < 0.0:
		position.y = 0.0
		velocity.y = 0
		grounded = true
	
	# face movement direction
	if move_dir.length_squared() > 0.01:
		yaw = lerp_angle(yaw, atan2(move_dir.x, move_dir.z), 1.0 - exp(-12.0 * delta))
	rotation.y = yaw
	
	# camera
	camera.rotation = Vector3(cam_pitch, 0, 0)


func _on_pause_toggled() -> void:
	if GameState.state == GameState.GameState.PAUSED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif GameState.state == GameState.GameState.PLAYING:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
