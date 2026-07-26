extends Node

# GameState autoload — global game state, singleton accessible from anywhere
# Mirrors the 'game' object from the original JavaScript BLINGO

enum GameStateEnum { MENU, PLAYING, PAUSED, DEAD }

var state: GameStateEnum = GameStateEnum.MENU
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

# Prestige (persisted across runs)
var blocks_secured: Dictionary = {}
var best_streak: int = 0
var best_time: float = 0.0
var best_hero: String = ""
var best_hero_color: Color = Color("#ff8c42")
var campaign: int = 0
var session_campaign: int = 0

# Day/night cycle
func update_clock(dt: float) -> void:
	clock = fmod(clock + dt * 0.02, 24.0)

func is_night() -> bool:
	return clock < 6 or clock > 20

func get_best_streak() -> int:
	return best_streak

func get_best_time() -> float:
	return best_time

func get_best_hero_color() -> Color:
	return best_hero_color

func record_prestige(hero_index: int, run_time: float, hero_color: Color) -> void:
	blocks_secured[hero_index] = blocks_secured.get(hero_index, 0) + 1
	if best_time == 0.0 or run_time < best_time:
		best_time = run_time
		best_hero_color = hero_color
		best_hero = str(hero_index)
	session_campaign += 1
	best_streak = maxi(best_streak, session_campaign)

func reset_session() -> void:
	session_campaign = 0
