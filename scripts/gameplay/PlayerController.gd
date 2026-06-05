extends CharacterBody2D

# Semua angka balancing player diambil dari resource agar mudah diubah dari editor.
@export var config: PlayerConfig
@export var projectile_scene: PackedScene

var current_hp := 0
var attack_timer := 0.0


func _ready() -> void:
	current_hp = config.max_hp
	GameState.mode = GameState.GameMode.RUNNING

	# GameState menyimpan nilai global, sedangkan EventBus memberi tahu UI.
	GameState.player_max_hp = config.max_hp
	GameState.player_hp = current_hp
	EventBus.player_health_changed.emit(current_hp, config.max_hp)


func _physics_process(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)

	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = input_direction * config.move_speed
	move_and_slide()

	# Auto-shoot berjalan setiap frame, tetapi tetap dibatasi attack_timer.
	_try_auto_attack()


func _try_auto_attack() -> void:
	if attack_timer > 0.0 or projectile_scene == null:
		return

	var target := _get_nearest_enemy()
	if target == null:
		return

	var projectile := projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.call("setup", global_position, target.global_position, config.projectile_damage)
	attack_timer = config.attack_cooldown


func _get_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D
	var nearest_distance := config.attack_range

	# Enemy dicari lewat group agar spawner bebas membuat enemy baru kapan saja.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D:
			continue

		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_enemy = enemy
			nearest_distance = distance

	return nearest_enemy


func take_damage(amount: int) -> void:
	current_hp = maxi(current_hp - amount, 0)
	GameState.player_hp = current_hp
	EventBus.player_health_changed.emit(current_hp, config.max_hp)

	if current_hp <= 0:
		# Player dimatikan lewat mode global dan signal agar UI/gameplay tidak saling tergantung.
		GameState.set_game_over()
		EventBus.player_died.emit()
		set_physics_process(false)
		modulate = Color(0.45, 0.45, 0.45, 1.0)


func heal(amount: int) -> void:
	if current_hp <= 0:
		return

	current_hp = mini(current_hp + amount, config.max_hp)
	GameState.player_hp = current_hp
	EventBus.player_health_changed.emit(current_hp, config.max_hp)
