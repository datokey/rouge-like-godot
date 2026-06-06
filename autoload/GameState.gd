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
var player_xp := 0
var player_required_xp := 1
var player_level := 1


func start_new_game() -> void:
	mode = GameMode.RUNNING
	current_floor = 1
	player_hp = player_max_hp
	player_xp = 0
	player_required_xp = 1
	player_level = 1


func set_game_over() -> void:
	mode = GameMode.GAME_OVER
