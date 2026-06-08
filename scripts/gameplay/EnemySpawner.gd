extends Node2D

@export var enemy_scene: PackedScene
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_scene_weights: Array[int] = []
# Semua angka spawn dan scaling disimpan di resource SpawnerConfig.
@export var config: SpawnerConfig

var player: Node2D
var spawn_timer := 0.0
var spawn_interval_scaling_timer := 0.0
var damage_scaling_timer := 0.0
var current_spawn_interval := 0.0
var current_spawn_count := 0
var current_enemy_damage_bonus := 0


func _ready() -> void:
	if config == null:
		push_error("EnemySpawner membutuhkan SpawnerConfig di property config.")
		set_physics_process(false)
		return

	player = get_tree().get_first_node_in_group("player") as Node2D
	current_spawn_interval = maxf(config.initial_spawn_interval, config.minimum_spawn_interval)
	current_spawn_count = config.initial_spawn_count
	spawn_timer = current_spawn_interval
	spawn_interval_scaling_timer = maxf(config.spawn_interval_decrease_every, 0.0)
	damage_scaling_timer = config.enemy_damage_increase_every


func _physics_process(delta: float) -> void:
	if not _has_enemy_scene() or GameState.mode != GameState.GameMode.RUNNING:
		return

	spawn_timer -= delta
	damage_scaling_timer -= delta
	if config.spawn_interval_decrease_every > 0.0:
		spawn_interval_scaling_timer -= delta

	if spawn_timer <= 0.0:
		_spawn_wave()
		spawn_timer = current_spawn_interval

	while config.spawn_interval_decrease_every > 0.0 and spawn_interval_scaling_timer <= 0.0:
		_scale_spawn_interval()
		spawn_interval_scaling_timer += config.spawn_interval_decrease_every

	if damage_scaling_timer <= 0.0:
		_scale_enemy_damage()
		damage_scaling_timer = config.enemy_damage_increase_every


func _spawn_wave() -> void:
	current_spawn_count = _get_spawn_count_for_elapsed_time()
	var spawn_amount := mini(current_spawn_count, _get_available_enemy_slots())
	if spawn_amount <= 0:
		return

	for index in range(spawn_amount):
		var selected_enemy_scene := _pick_enemy_scene()
		if selected_enemy_scene == null:
			continue

		var enemy: Node2D = selected_enemy_scene.instantiate() as Node2D
		if enemy == null:
			continue

		get_parent().add_child(enemy)
		if enemy.has_method("set_contact_damage_bonus"):
			enemy.set_contact_damage_bonus(current_enemy_damage_bonus)
		enemy.global_position = _get_spawn_position(index)


func _get_spawn_position(index: int) -> Vector2:
	var spawn_center := Vector2.ZERO
	if player != null:
		spawn_center = player.global_position

	var side := Rng.range_i(0, 3)

	# Offset kecil mencegah enemy dalam wave yang sama spawn di posisi persis sama.
	var offset := float(index) * 32.0
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


func _scale_spawn_interval() -> void:
	# Interval spawn turun berdasarkan durasi run, sampai batas minimum.
	current_spawn_interval = maxf(
		current_spawn_interval - config.spawn_interval_decrease_amount,
		config.minimum_spawn_interval
	)
	spawn_timer = minf(spawn_timer, current_spawn_interval)


func _scale_enemy_damage() -> void:
	current_enemy_damage_bonus = mini(
		current_enemy_damage_bonus + config.enemy_damage_increase_amount,
		config.enemy_damage_max_bonus
	)


func _get_spawn_count_for_elapsed_time() -> int:
	var max_spawn_count := maxi(0, config.maximum_spawn_count)
	var spawn_count := maxi(0, config.initial_spawn_count)
	if config.spawn_count_increase_every > 0.0:
		var increase_steps := floori(GameState.run_elapsed_time / config.spawn_count_increase_every)
		spawn_count += increase_steps * maxi(0, config.spawn_count_increase_amount)

	return clampi(spawn_count, 0, max_spawn_count)


func _get_available_enemy_slots() -> int:
	var alive_count := get_tree().get_nodes_in_group("enemy").size()
	return maxi(0, config.maximum_alive_enemies - alive_count)


func _has_enemy_scene() -> bool:
	if enemy_scene != null:
		return true

	for scene in enemy_scenes:
		if scene != null:
			return true

	return false


func _pick_enemy_scene() -> PackedScene:
	if enemy_scenes.is_empty():
		return enemy_scene

	var scene_count := enemy_scenes.size()
	var total_weight := 0
	for index in range(scene_count):
		if enemy_scenes[index] == null:
			continue
		total_weight += _get_enemy_scene_weight(index)

	if total_weight <= 0:
		return enemy_scene

	var roll := Rng.range_i(1, total_weight)
	var accumulated_weight := 0
	for index in range(scene_count):
		var scene := enemy_scenes[index]
		if scene == null:
			continue

		accumulated_weight += _get_enemy_scene_weight(index)
		if roll <= accumulated_weight:
			return scene

	return enemy_scene


func _get_enemy_scene_weight(index: int) -> int:
	if index < enemy_scene_weights.size():
		return maxi(0, enemy_scene_weights[index])

	return 1


func _random_camera_x() -> int:
	return Rng.range_i(int(-config.camera_half_size.x), int(config.camera_half_size.x))


func _random_camera_y() -> int:
	return Rng.range_i(int(-config.camera_half_size.y), int(config.camera_half_size.y))
