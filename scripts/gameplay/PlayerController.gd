extends CharacterBody2D

# Semua angka balancing player diambil dari resource agar mudah diubah dari editor.
@export var config: PlayerConfig
@export var weapon_config: WeaponConfig
@export var xp_config: XPConfig
@export var projectile_scene: PackedScene

@onready var pickup_area_collision: CollisionShape2D = $PickupArea/CollisionShape2D

var current_hp := 0
var current_xp := 0
var current_level := 1
var attack_timer := 0.0

# Modifier runtime disiapkan untuk upgrade tanpa mengubah base config.
var damage_modifier := 0
var attack_interval_modifier := 0.0
var move_speed_modifier := 0.0


func _ready() -> void:
	current_hp = config.max_hp
	current_xp = 0
	current_level = 1
	_apply_pickup_radius()
	GameState.mode = GameState.GameMode.RUNNING

	# GameState menyimpan nilai global, sedangkan EventBus memberi tahu UI.
	GameState.player_max_hp = config.max_hp
	GameState.player_hp = current_hp
	EventBus.player_health_changed.emit(current_hp, config.max_hp)
	_emit_xp_changed()


func _physics_process(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)

	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = input_direction * get_move_speed()
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
	projectile.call("setup", global_position, target.global_position, get_weapon_damage())
	attack_timer = get_attack_interval()


func _get_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D
	var nearest_distance := weapon_config.attack_range

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


func add_xp(amount: int) -> void:
	current_xp += amount

	while current_xp >= get_xp_required_for_next_level():
		current_xp -= get_xp_required_for_next_level()
		current_level += 1

	_emit_xp_changed()


func get_move_speed() -> float:
	return config.move_speed + move_speed_modifier


func get_weapon_damage() -> int:
	return maxi(0, weapon_config.damage + damage_modifier)


func get_attack_interval() -> float:
	return maxf(0.05, weapon_config.attack_interval + attack_interval_modifier)


func get_xp_required_for_next_level() -> int:
	var scaled_requirement := float(xp_config.required_per_level) * pow(xp_config.growth_multiplier, current_level - 1)
	return maxi(1, roundi(scaled_requirement))


func _emit_xp_changed() -> void:
	GameState.player_xp = current_xp
	GameState.player_required_xp = get_xp_required_for_next_level()
	GameState.player_level = current_level
	EventBus.player_xp_changed.emit(current_xp, get_xp_required_for_next_level(), current_level)


func _apply_pickup_radius() -> void:
	if pickup_area_collision == null:
		return

	var circle_shape := pickup_area_collision.shape as CircleShape2D
	if circle_shape != null:
		circle_shape.radius = config.pickup_radius
