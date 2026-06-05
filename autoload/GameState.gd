extends Node

# State global ringan untuk status run. Data balancing tetap disimpan di resource.
enum GameMode {
	MENU,
	RUNNING,
	PAUSED,
	GAME_OVER,
}

var mode: GameMode = GameMode.MENU
var current_floor := 1
var player_max_hp := 100
var player_hp := player_max_hp


func start_new_game() -> void:
	mode = GameMode.RUNNING
	current_floor = 1
	player_hp = player_max_hp


func set_game_over() -> void:
	mode = GameMode.GAME_OVER
