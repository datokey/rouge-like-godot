extends Node

# State global ringan untuk status run. Data balancing tetap disimpan di resource.
enum GameMode {
	MENU,
	RUNNING,
	PAUSED,
	GAME_OVER,
	VICTORY,
}

var mode: GameMode = GameMode.MENU
var current_floor := 1
var player_max_hp := 100
var player_hp := player_max_hp
var player_xp := 0
var player_required_xp := 1
var player_level := 1
var run_elapsed_time := 0.0
var run_target_time := 300.0


func start_new_game(target_time: float = 300.0) -> void:
	mode = GameMode.RUNNING
	current_floor = 1
	player_hp = player_max_hp
	player_xp = 0
	player_required_xp = 1
	player_level = 1
	run_elapsed_time = 0.0
	run_target_time = maxf(target_time, 1.0)


func set_game_over() -> void:
	if mode == GameMode.VICTORY:
		return

	mode = GameMode.GAME_OVER


func set_victory() -> void:
	mode = GameMode.VICTORY
