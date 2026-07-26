extends Node

# Global signal bus for UI events and game-wide communication

signal splash_dismissed
signal cousin_selected(index: int)
signal single_player_pressed
signal multiplayer_pressed
signal policies_pressed
signal start_game_requested
signal quit_to_menu

signal toast_show(message: String, important: bool)
signal boss_bar_show(show: bool)
signal boss_bar_label(text: String)
signal boss_bar_hp(ratio: float)
signal boss_bar_style(style: String)
signal quota_show(show: bool, current: int, target: int)
signal screen_shake(amplitude: float)
signal rumble(duration_ms: int, low: float, high: float)
signal boss_spawned(boss_index: int, x: float, z: float)
signal boss_defeated(boss_index: int)
signal cleanup_complete
signal bluga_cameo_started
signal bluga_final_started
signal bluga_defeated
signal jelly_house_beacon
