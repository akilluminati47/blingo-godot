extends Node

# Main game coordinator — chains splash → menu → gameplay
# All major systems are wired here

var splash_screen: Control
var start_screen: Control
var player: PlayerController
var terrain_gen: TerrainGenerator
var town_builder: TownBuilder
var chunk_manager: ChunkManager
var zombie_spawner: ZombieSpawner
var weapon_system: WeaponSystem


func _ready() -> void:
	print("BLINGO - Godot 4.7")
	_show_splash()


func _show_splash() -> void:
	splash_screen = load("res://scenes/splash.tscn").instantiate()
	add_child(splash_screen)
	SignalBus.splash_dismissed.connect(_on_splash_dismissed)


func _on_splash_dismissed() -> void:
	splash_screen.queue_free()
	_show_menu()


func _show_menu() -> void:
	start_screen = load("res://scenes/startscreen.tscn").instantiate()
	add_child(start_screen)
	SignalBus.single_player_pressed.connect(_on_start_game)
	SignalBus.multiplayer_pressed.connect(_on_start_game)


func _on_start_game() -> void:
	if start_screen:
		start_screen.queue_free()
	start_game()


func start_game() -> void:
	GameState.state = GameState.GameState.PLAYING
	print("Game started")
	
	# Terrain
	terrain_gen = TerrainGenerator.new()
	terrain_gen.name = "TerrainGenerator"
	add_child(terrain_gen)
	
	town_builder = TownBuilder.new()
	town_builder.name = "TownBuilder"
	town_builder.terrain_generator = terrain_gen
	add_child(town_builder)
	
	chunk_manager = ChunkManager.new()
	chunk_manager.name = "ChunkManager"
	chunk_manager.terrain_generator = terrain_gen
	add_child(chunk_manager)
	
	# Player
	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	
	# Camera as child of player for third-person
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 75.0
	cam.position = Vector3(0, 1.8, 7)
	player.add_child(cam)

	# Player blob
	var blob := BlobBuilder.new()
	blob.name = "Blob"
	blob.body_color = Color.ORANGE
	player.add_child(blob)
	
	# Weapon system
	weapon_system = WeaponSystem.new()
	weapon_system.name = "WeaponSystem"
	weapon_system.camera = cam
	player.add_child(weapon_system)
	
	# Zombie spawner
	zombie_spawner = ZombieSpawner.new()
	zombie_spawner.name = "ZombieSpawner"
	zombie_spawner.player_ref = player
	add_child(zombie_spawner)
	
	# Chunk manager follows player
	chunk_manager.set_target(player)
	
	# World environment
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.4, 0.8)
	sky_mat.sky_horizon_color = Color(0.6, 0.7, 0.9)
	sky_mat.ground_horizon_color = Color(0.3, 0.25, 0.2)
	sky_mat.ground_bottom_color = Color(0.15, 0.12, 0.1)
	env.sky = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.15, 0.18, 0.22)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_DEPTH
	env.fog_density = 0.004
	env.fog_light_color = Color(0.9, 0.85, 0.8)
	world_env.environment = env
	add_child(world_env)
	
	# Directional light (sun)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation = Vector3(-0.7, 0.5, 0)
	sun.shadow_enabled = true
	add_child(sun)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameState.time = 0.0
	print("  World ready — ", PlayerController.PlayerController, " player, terrain streaming, zombies spawning")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameState.state == GameState.GameState.PLAYING:
			GameState.state = GameState.GameState.PAUSED
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif GameState.state == GameState.GameState.PAUSED:
			GameState.state = GameState.GameState.PLAYING
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
