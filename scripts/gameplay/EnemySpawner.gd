extends Node2D

# Config spawn area dipisah dari config difficulty agar balancing lebih rapi.
@export var config: SpawnerConfig
@export var difficulty_manager: Resource

const SPAWN_SIDE_MIN := 0
const SPAWN_SIDE_MAX := 3
const WAVE_SPAWN_OFFSET := 32.0

var player: Node2D
var spawn_timer := 0.0


func _ready() -> void:
	if config == null:
		push_error("EnemySpawner membutuhkan SpawnerConfig di property config.")
		set_physics_process(false)
		return

	if difficulty_manager == null:
		push_error("EnemySpawner membutuhkan DifficultyManager di property difficulty_manager.")
		set_physics_process(false)
		return

	player = get_tree().get_first_node_in_group("player") as Node2D
	spawn_timer = _get_difficulty_float("get_spawn_interval", _get_run_progress())


func _physics_process(delta: float) -> void:
	var progress := _get_run_progress()
	if not _get_difficulty_bool("has_enemy_scene", progress) or GameState.mode != GameState.GameMode.RUNNING:
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_wave(progress)
		spawn_timer = _get_difficulty_float("get_spawn_interval", progress)


func _spawn_wave(progress: float) -> void:
	var spawn_amount := mini(_get_difficulty_int("get_spawn_count", progress), _get_available_enemy_slots(progress))
	if spawn_amount <= 0:
		return

	for index in range(spawn_amount):
		var selected_enemy_scene: PackedScene = difficulty_manager.call("pick_enemy_scene", progress)
		if selected_enemy_scene == null:
			continue

		var enemy: Node2D = selected_enemy_scene.instantiate() as Node2D
		if enemy == null:
			continue

		if enemy.has_method("apply_difficulty_scaling"):
			enemy.call(
				"apply_difficulty_scaling",
				_get_difficulty_float("get_hp_multiplier", progress),
				_get_difficulty_float("get_damage_multiplier", progress),
				_get_difficulty_float("get_move_speed_multiplier", progress)
			)

		get_parent().add_child(enemy)
		enemy.global_position = _get_spawn_position(index)


func _get_spawn_position(index: int) -> Vector2:
	var spawn_center := Vector2.ZERO
	if player != null:
		spawn_center = player.global_position

	var side := Rng.range_i(SPAWN_SIDE_MIN, SPAWN_SIDE_MAX)

	# Offset kecil mencegah enemy dalam wave yang sama spawn di posisi persis sama.
	var offset := float(index) * WAVE_SPAWN_OFFSET
	var position := Vector2.ZERO

	match side:
		0:
			position = Vector2(
				spawn_center.x + _random_camera_x(),
				spawn_center.y - config.camera_half_size.y - config.spawn_margin - offset
			)
		1:
			position = Vector2(
				spawn_center.x + config.camera_half_size.x + config.spawn_margin + offset,
				spawn_center.y + _random_camera_y()
			)
		2:
			position = Vector2(
				spawn_center.x + _random_camera_x(),
				spawn_center.y + config.camera_half_size.y + config.spawn_margin + offset
			)
		_:
			position = Vector2(
				spawn_center.x - config.camera_half_size.x - config.spawn_margin - offset,
				spawn_center.y + _random_camera_y()
			)

	# Enemy dibuat di luar kamera player, tetapi tetap dikunci di area playable arena.
	position.x = clampf(position.x, -config.playable_half_size.x, config.playable_half_size.x)
	position.y = clampf(position.y, -config.playable_half_size.y, config.playable_half_size.y)
	return position


func _get_available_enemy_slots(progress: float) -> int:
	var alive_count := get_tree().get_nodes_in_group("enemy").size()
	return maxi(0, _get_difficulty_int("get_maximum_alive_enemies", progress) - alive_count)


func _get_run_progress() -> float:
	if difficulty_manager == null:
		return 0.0

	var value = difficulty_manager.call(
		"get_progress",
		GameState.run_elapsed_time,
		GameState.run_target_time
	)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)

	return 0.0


func _get_difficulty_float(method_name: String, progress: float) -> float:
	var value = difficulty_manager.call(method_name, progress)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)

	return 0.0


func _get_difficulty_int(method_name: String, progress: float) -> int:
	var value = difficulty_manager.call(method_name, progress)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return roundi(float(value))

	return 0


func _get_difficulty_bool(method_name: String, progress: float) -> bool:
	var value = difficulty_manager.call(method_name, progress)
	if typeof(value) == TYPE_BOOL:
		return value

	return false


func _random_camera_x() -> int:
	return Rng.range_i(int(-config.camera_half_size.x), int(config.camera_half_size.x))


func _random_camera_y() -> int:
	return Rng.range_i(int(-config.camera_half_size.y), int(config.camera_half_size.y))
