extends Node

@export var config: Resource = preload("res://resources/run/default_run_config.tres")

var run_seed := 0
var is_run_active := false


func start_run(seed_value: int = 0) -> int:
	run_seed = seed_value if seed_value != 0 else Rng.random_seed()
	Rng.set_seed(run_seed)
	GameState.start_new_game(get_survival_duration())
	is_run_active = true
	get_tree().paused = false
	EventBus.run_started.emit(run_seed)
	EventBus.run_time_changed.emit(GameState.run_elapsed_time, GameState.run_target_time)
	return run_seed


func _process(delta: float) -> void:
	if not is_run_active or GameState.mode != GameState.GameMode.RUNNING:
		return

	GameState.run_elapsed_time = minf(
		GameState.run_elapsed_time + delta,
		GameState.run_target_time
	)
	EventBus.run_time_changed.emit(GameState.run_elapsed_time, GameState.run_target_time)

	if GameState.run_elapsed_time >= GameState.run_target_time:
		win_run()


func get_survival_duration() -> float:
	if config == null:
		return 300.0

	var survival_duration = config.get("survival_duration")
	if typeof(survival_duration) == TYPE_INT or typeof(survival_duration) == TYPE_FLOAT:
		return float(survival_duration)

	return 300.0


func get_next_scene_path() -> String:
	if config == null:
		return ""

	var next_scene_path = config.get("next_scene_path")
	if typeof(next_scene_path) == TYPE_STRING:
		return next_scene_path

	return ""


func lose_run() -> void:
	if GameState.mode == GameState.GameMode.VICTORY:
		return

	is_run_active = false
	GameState.set_game_over()
	EventBus.run_lost.emit(GameState.run_elapsed_time, GameState.run_target_time)
	EventBus.player_died.emit()


func win_run() -> void:
	if GameState.mode != GameState.GameMode.RUNNING:
		return

	is_run_active = false
	GameState.set_victory()
	EventBus.run_won.emit(GameState.run_elapsed_time, GameState.run_target_time, get_next_scene_path())
	get_tree().paused = true


func go_to_next_scene() -> bool:
	var next_scene_path := get_next_scene_path()
	if next_scene_path.is_empty():
		return false

	get_tree().paused = false
	get_tree().change_scene_to_file(next_scene_path)
	return true


func advance_floor() -> void:
	GameState.current_floor += 1
	EventBus.floor_changed.emit(GameState.current_floor)
