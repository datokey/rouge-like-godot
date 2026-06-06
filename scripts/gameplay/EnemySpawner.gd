extends Node2D

@export var enemy_scene: PackedScene
# Semua angka spawn dan scaling disimpan di resource SpawnerConfig.
@export var config: SpawnerConfig

var player: Node2D
var spawn_timer := 0.0
var scaling_timer := 0.0
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
	current_spawn_interval = config.spawn_interval
	current_spawn_count = config.spawn_count
	spawn_timer = current_spawn_interval
	scaling_timer = config.spawn_count_increase_every
	damage_scaling_timer = config.enemy_damage_increase_every


func _physics_process(delta: float) -> void:
	if enemy_scene == null or GameState.mode == GameState.GameMode.GAME_OVER:
		return

	spawn_timer -= delta
	scaling_timer -= delta
	damage_scaling_timer -= delta

	if spawn_timer <= 0.0:
		_spawn_wave()
		spawn_timer = current_spawn_interval

	if scaling_timer <= 0.0:
		_scale_spawn_pressure()
		scaling_timer = config.spawn_count_increase_every

	if damage_scaling_timer <= 0.0:
		_scale_enemy_damage()
		damage_scaling_timer = config.enemy_damage_increase_every


func _spawn_wave() -> void:
	for index in range(current_spawn_count):
		var enemy: Node2D = enemy_scene.instantiate() as Node2D
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


func _scale_spawn_pressure() -> void:
	# Tekanan spawn naik pelan-pelan: jumlah enemy naik, interval spawn turun.
	current_spawn_count = mini(current_spawn_count + 1, config.spawn_count_max)
	current_spawn_interval = maxf(current_spawn_interval - config.spawn_interval_decay, config.spawn_interval_min)


func _scale_enemy_damage() -> void:
	current_enemy_damage_bonus = mini(
		current_enemy_damage_bonus + config.enemy_damage_increase_amount,
		config.enemy_damage_max_bonus
	)


func _random_camera_x() -> int:
	return Rng.range_i(int(-config.camera_half_size.x), int(config.camera_half_size.x))


func _random_camera_y() -> int:
	return Rng.range_i(int(-config.camera_half_size.y), int(config.camera_half_size.y))
