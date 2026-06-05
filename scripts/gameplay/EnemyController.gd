extends CharacterBody2D

# Config menyimpan stat enemy dan peluang drop agar balancing tidak hardcoded.
@export var config: EnemyConfig
@export var health_pickup_scene: PackedScene

var current_hp := 0
var contact_timer := 0.0
var target: Node2D
var is_dead := false


func _ready() -> void:
	current_hp = config.max_hp
	target = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if GameState.mode == GameState.GameMode.GAME_OVER:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	contact_timer = maxf(contact_timer - delta, 0.0)

	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	velocity = global_position.direction_to(target.global_position) * config.move_speed
	move_and_slide()
	_try_damage_player()


func take_damage(amount: int) -> void:
	if is_dead:
		return

	current_hp -= amount

	if current_hp <= 0:
		# Flag ini mencegah drop/free terpanggil dua kali oleh projectile yang hampir bersamaan.
		is_dead = true
		_die()


func _try_damage_player() -> void:
	if contact_timer > 0.0:
		return

	# Contact damage dibaca dari collision hasil move_and_slide().
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		var collider := collision.get_collider()

		if collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(config.contact_damage)
			contact_timer = config.contact_cooldown
			return


func _die() -> void:
	set_physics_process(false)

	if health_pickup_scene != null and Rng.chance(config.health_drop_chance):
		# Spawn pickup ditunda karena fungsi ini bisa dipanggil dari callback physics.
		call_deferred("_drop_health_pickup", global_position)

	# queue_free juga ditunda untuk menghindari error "flushing queries" Godot Physics.
	call_deferred("queue_free")


func _drop_health_pickup(drop_position: Vector2) -> void:
	if health_pickup_scene == null or get_parent() == null:
		return

	var pickup := health_pickup_scene.instantiate() as Node2D
	if pickup == null:
		return

	get_parent().add_child(pickup)
	pickup.global_position = drop_position
