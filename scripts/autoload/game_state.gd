extends Node

# GameState autoload — global game state, singleton accessible from anywhere
# Mirrors the 'game' object from the original JavaScript BLINGO

enum GameState { MENU, PLAYING, PAUSED, DEAD }

var state: GameState = GameState.MENU
var time: float = 0.0
var kills: int = 0
var crates_opened: int = 0
var clock: float = 12.0       # in-game hour (0-24)
var weather: String = "sunny" # sunny, cloudy, rain
var cycle: int = 0
var cleanup: bool = false
var clear_target: int = 0
var celebrate_t: float = 0.0
var selected_cousin: int = 0

# Day/night cycle
func update_clock(dt: float) -> void:
	clock = fmod(clock + dt * 0.02, 24.0)

func is_night() -> bool:
	return clock < 6 or clock > 20
