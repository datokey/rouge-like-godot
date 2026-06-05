extends Node

var run_seed := 0


func start_run(seed_value: int = 0) -> int:
	run_seed = seed_value if seed_value != 0 else Rng.random_seed()
	Rng.set_seed(run_seed)
	GameState.start_new_game()
	EventBus.run_started.emit(run_seed)
	return run_seed


func advance_floor() -> void:
	GameState.current_floor += 1
	EventBus.floor_changed.emit(GameState.current_floor)
