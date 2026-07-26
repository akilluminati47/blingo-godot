extends Node

@onready var player: PlayerController = $Player


func _ready() -> void:
	print("BLINGO - Godot 4.7")
	start_game()


func start_game() -> void:
	GameState.state = GameState.GameState.PLAYING
	print("Game started")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameState.state == GameState.GameState.PLAYING:
			GameState.state = GameState.GameState.PAUSED
		elif GameState.state == GameState.GameState.PAUSED:
			GameState.state = GameState.GameState.PLAYING
		player._on_pause_toggled()
