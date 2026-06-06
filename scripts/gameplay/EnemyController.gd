extends CharacterBody2D

# Config menyimpan stat enemy dan peluang drop agar balancing tidak hardcoded.
@export var config: EnemyConfig
@export var pickup_item_scene: PackedScene
@export var health_pickup_config: PickupConfig
@export var xp_pickup_config: PickupConfig
@export var magnet_pickup_config: PickupConfig
@export var hit_feedback_config: Resource

@onready var drop_point: Node2D = $DropPoint
@onready var visual: Polygon2D = $Visual
@onready var hit_sound_player: AudioStreamPlayer2D = $HitSound

var current_hp := 0
var contact_timer := 0.0
var target: Node2D
var is_dead := false
var contact_damage_bonus := 0
var knockback_remaining := 0.0
var knockback_velocity := Vector2.ZERO
var hit_flash_remaining := 0.0
var hit_stop_remaining := 0.0
var base_visual_color := Color.WHITE


func _ready() -> void:
	current_hp = config.max_hp
	target = get_tree().get_first_node_in_group("player") as Node2D
	base_visual_color = visual.color


func _physics_process(delta: float) -> void:
	_update_hit_flash(delta)

	if GameState.mode != GameState.GameMode.RUNNING:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if hit_stop_remaining > 0.0:
		hit_stop_remaining = maxf(hit_stop_remaining - delta, 0.0)
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
	_apply_controlled_knockback(delta)
	_try_damage_player()


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO, hit_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	current_hp -= amount
	_apply_hit_feedback(hit_direction, hit_position)

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
			collider.take_damage(get_contact_damage())
			contact_timer = config.contact_cooldown
			return


func _die() -> void:
	set_physics_process(false)
	var drop_position := global_position
	if drop_point != null:
		drop_position = drop_point.global_position

	var xp_amount := _roll_xp_drop_amount()
	if xp_amount > 0 and xp_pickup_config != null:
		var xp_config: PickupConfig = xp_pickup_config.duplicate() as PickupConfig
		xp_config.amount = xp_amount
		call_deferred("_drop_pickup", drop_position, xp_config)

	if health_pickup_config != null and Rng.chance(config.health_drop_chance):
		var hp_amount := _roll_hp_drop_amount()
		if hp_amount > 0:
			var hp_config: PickupConfig = health_pickup_config.duplicate() as PickupConfig
			hp_config.amount = hp_amount
			call_deferred("_drop_pickup", drop_position, hp_config)

	if magnet_pickup_config != null and Rng.chance(config.magnet_drop_chance):
		call_deferred("_drop_pickup", drop_position, magnet_pickup_config)

	# queue_free juga ditunda untuk menghindari error "flushing queries" Godot Physics.
	call_deferred("queue_free")


func _drop_pickup(drop_position: Vector2, pickup_config: PickupConfig) -> void:
	if pickup_item_scene == null or pickup_config == null or get_parent() == null:
		return

	var pickup := pickup_item_scene.instantiate() as Node2D
	if pickup == null:
		return

	pickup.set("config", pickup_config)
	get_parent().add_child(pickup)
	if pickup.has_method("set_pickup_config"):
		pickup.call("set_pickup_config", pickup_config)
	pickup.global_position = drop_position


func set_contact_damage_bonus(value: int) -> void:
	contact_damage_bonus = value


func get_contact_damage() -> int:
	return maxi(0, config.contact_damage + contact_damage_bonus)


func _apply_hit_feedback(hit_direction: Vector2, hit_position: Vector2) -> void:
	_start_controlled_knockback(hit_direction)
	_start_hit_flash()
	_spawn_impact_vfx(hit_position)
	_play_hit_sound()
	hit_stop_remaining = maxf(hit_stop_remaining, _get_hit_float("hit_stop_duration", 0.02))


func _start_controlled_knockback(hit_direction: Vector2) -> void:
	if hit_direction == Vector2.ZERO:
		return

	var duration := _get_hit_float("hit_knockback_duration", 0.08)
	if duration <= 0.0:
		return

	var force := _get_hit_float("hit_knockback_force", 1.5)
	var unit_size := _get_hit_float("knockback_unit_size", 32.0)
	var max_distance := _get_hit_float("max_knockback_distance", 0.3) * unit_size
	var distance := minf(absf(force) * unit_size, max_distance)
	if distance <= 0.0:
		return

	knockback_remaining = duration
	knockback_velocity = hit_direction.normalized() * (distance / duration)


func _apply_controlled_knockback(delta: float) -> void:
	if knockback_remaining <= 0.0:
		return

	var step_time := minf(delta, knockback_remaining)
	knockback_remaining = maxf(knockback_remaining - delta, 0.0)
	move_and_collide(knockback_velocity * step_time)

	if knockback_remaining <= 0.0:
		knockback_velocity = Vector2.ZERO


func _start_hit_flash() -> void:
	hit_flash_remaining = maxf(hit_flash_remaining, _get_hit_float("hit_flash_duration", 0.08))
	visual.color = _get_hit_color("hit_flash_color", Color.WHITE)


func _update_hit_flash(delta: float) -> void:
	if hit_flash_remaining <= 0.0:
		return

	hit_flash_remaining = maxf(hit_flash_remaining - delta, 0.0)
	if hit_flash_remaining <= 0.0 and visual != null:
		visual.color = base_visual_color


func _spawn_impact_vfx(hit_position: Vector2) -> void:
	var impact_scene := _get_hit_scene("impact_vfx_scene")
	if impact_scene == null or get_parent() == null:
		return

	var impact := impact_scene.instantiate() as Node2D
	if impact == null:
		return

	get_parent().add_child(impact)
	impact.global_position = hit_position if hit_position != Vector2.ZERO else global_position
	if impact.has_method("setup"):
		impact.call("setup", _get_hit_float("impact_vfx_scale", 0.6))


func _play_hit_sound() -> void:
	if hit_sound_player == null or hit_sound_player.stream == null:
		return

	hit_sound_player.play()


func _get_hit_float(property_name: String, fallback: float) -> float:
	if hit_feedback_config == null:
		return fallback

	var value: Variant = hit_feedback_config.get(property_name)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)

	return fallback


func _get_hit_color(property_name: String, fallback: Color) -> Color:
	if hit_feedback_config == null:
		return fallback

	var value: Variant = hit_feedback_config.get(property_name)
	if typeof(value) == TYPE_COLOR:
		return value

	return fallback


func _get_hit_scene(property_name: String) -> PackedScene:
	if hit_feedback_config == null:
		return null

	var value: Variant = hit_feedback_config.get(property_name)
	if value is PackedScene:
		return value

	return null


func _roll_xp_drop_amount() -> int:
	return _roll_weighted_drop_amount(config.xp_drop_values, config.xp_drop_weights, 1, 5)


func _roll_hp_drop_amount() -> int:
	return _roll_weighted_drop_amount(config.hp_drop_values, config.hp_drop_weights, 1, 999)


func _roll_weighted_drop_amount(values: Array[int], weights: Array[int], min_value: int, max_value: int) -> int:
	var value_count := mini(values.size(), weights.size())
	if value_count <= 0:
		return 0

	var total_weight := 0
	for index in range(value_count):
		total_weight += maxi(0, weights[index])

	if total_weight <= 0:
		return 0

	var roll := Rng.range_i(1, total_weight)
	var accumulated_weight := 0

	for index in range(value_count):
		accumulated_weight += maxi(0, weights[index])
		if roll <= accumulated_weight:
			return clampi(values[index], min_value, max_value)

	return clampi(values[0], min_value, max_value)
