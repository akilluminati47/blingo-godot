extends Node

var splash_screen: Control
var start_screen: Control


func _ready() -> void:
	print("BLINGO - Godot 4.7")
	_show_splash()


func _show_splash() -> void:
	splash_screen = load("res://scenes/splash.tscn").instantiate()
	add_child(splash_screen)
	SignalBus.splash_dismissed.connect(_on_splash_dismissed)


func _on_splash_dismissed() -> void:
	if splash_screen:
		splash_screen.queue_free()
		splash_screen = null
	_show_menu()


func _show_menu() -> void:
	start_screen = load("res://scenes/startscreen.tscn").instantiate()
	add_child(start_screen)
	SignalBus.single_player_pressed.connect(_on_start_game)
	SignalBus.multiplayer_pressed.connect(_on_start_game)


func _on_start_game() -> void:
	if start_screen:
		start_screen.queue_free()
		start_screen = null
	_start_gameplay()


func _start_gameplay() -> void:
	GameState.state = GameState.State.PLAYING
	print("Game started")
	
	# World
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.4, 0.8)
	sky_mat.sky_horizon_color = Color(0.6, 0.7, 0.9)
	sky.sky_material = sky_mat
	env.sky = sky
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 0.004
	world_env.environment = env
	add_child(world_env)
	
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.5, 0)
	sun.shadow_enabled = true
	add_child(sun)
	
	# Terrain
	var terrain_gen := TerrainGenerator.new()
	terrain_gen.name = "TerrainGenerator"
	add_child(terrain_gen)
	
	# Player
	var player := PlayerController.new()
	player.name = "Player"
	player.position = Vector3(0, 1, 0)
	add_child(player)
	
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 75.0
	cam.position = Vector3(0, 1.8, 7)
	player.add_child(cam)
	
	# Blob
	var blob := BlobBuilder.new()
	blob.name = "Blob"
	blob.body_color = Color.ORANGE
	player.add_child(blob)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameState.time = 0.0
	print("  World ready — WASD to move, mouse to look")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameState.state == GameState.State.PLAYING:
			GameState.state = GameState.State.PAUSED
		elif GameState.state == GameState.State.PAUSED:
			GameState.state = GameState.State.PLAYING
