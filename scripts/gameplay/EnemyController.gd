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
var hp_multiplier := 1.0
var contact_damage_multiplier := 1.0
var move_speed_multiplier := 1.0
var slow_multiplier := 1.0
var slow_timer := 0.0
var knockback_remaining := 0.0
var knockback_velocity := Vector2.ZERO
var hit_flash_remaining := 0.0
var hit_stop_remaining := 0.0
var base_visual_color := Color.WHITE
var avoidance_direction := Vector2.ZERO
var avoidance_remaining := 0.0
var avoidance_side := 1.0
var stuck_timer := 0.0
var has_detour_waypoint := false
var detour_waypoint := Vector2.ZERO
var detour_refresh_timer := 0.0


func _ready() -> void:
	current_hp = get_max_hp()
	target = get_tree().get_first_node_in_group("player") as Node2D
	base_visual_color = visual.color
	avoidance_side = 1.0 if get_instance_id() % 2 == 0 else -1.0
	if config.detour_refresh_interval > 0.0:
		detour_refresh_timer = float(get_instance_id() % 100) / 100.0 * config.detour_refresh_interval


func _physics_process(delta: float) -> void:
	_update_hit_flash(delta)

	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_multiplier = 1.0

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

	var chase_direction := global_position.direction_to(target.global_position)
	var move_direction := _get_move_direction(chase_direction, delta)
	var position_before_move := global_position
	velocity = move_direction * get_move_speed()
	move_and_slide()
	_update_obstacle_avoidance(chase_direction, position_before_move.distance_to(global_position), delta)
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

	var xp_drop_count := _roll_xp_drop_count()
	for index in range(xp_drop_count):
		var xp_amount := _roll_xp_drop_amount()
		if xp_amount > 0 and xp_pickup_config != null:
			var xp_config: PickupConfig = xp_pickup_config.duplicate() as PickupConfig
			xp_config.amount = xp_amount
			call_deferred("_drop_pickup", _get_xp_drop_position(drop_position, index, xp_drop_count), xp_config)

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


func apply_difficulty_scaling(
	new_hp_multiplier: float,
	new_damage_multiplier: float,
	new_move_speed_multiplier: float
) -> void:
	hp_multiplier = maxf(0.0, new_hp_multiplier)
	contact_damage_multiplier = maxf(0.0, new_damage_multiplier)
	move_speed_multiplier = maxf(0.0, new_move_speed_multiplier)


func get_max_hp() -> int:
	return maxi(1, roundi(float(config.max_hp) * hp_multiplier))


func get_move_speed() -> float:
	return maxf(0.0, config.move_speed * move_speed_multiplier * slow_multiplier)


func apply_slow(percent: float, duration: float) -> void:
	var mult = 1.0 - percent
	if slow_timer <= 0.0 or mult < slow_multiplier:
		slow_multiplier = mult
	slow_timer = maxf(slow_timer, duration)


func get_contact_damage() -> int:
	var base_damage := config.contact_damage + contact_damage_bonus
	return maxi(0, roundi(float(base_damage) * contact_damage_multiplier))


func _get_move_direction(chase_direction: Vector2, delta: float) -> Vector2:
	var base_direction := _get_detour_direction(chase_direction, delta)

	if not config.obstacle_avoidance_enabled:
		return base_direction

	if avoidance_remaining <= 0.0 or avoidance_direction == Vector2.ZERO:
		return base_direction

	avoidance_remaining = maxf(avoidance_remaining - delta, 0.0)
	var mixed_direction := base_direction + avoidance_direction * config.obstacle_avoidance_weight
	if mixed_direction == Vector2.ZERO:
		return base_direction

	return mixed_direction.normalized()


func _get_detour_direction(chase_direction: Vector2, delta: float) -> Vector2:
	if not config.detour_path_enabled:
		return chase_direction

	_update_detour_waypoint(delta)

	if not has_detour_waypoint:
		return chase_direction

	if global_position.distance_to(detour_waypoint) <= config.detour_waypoint_reached_distance:
		has_detour_waypoint = false
		return chase_direction

	return global_position.direction_to(detour_waypoint)


func _update_detour_waypoint(delta: float) -> void:
	if target == null:
		has_detour_waypoint = false
		return

	detour_refresh_timer = maxf(detour_refresh_timer - delta, 0.0)
	if detour_refresh_timer > 0.0 and has_detour_waypoint:
		return

	detour_refresh_timer = maxf(config.detour_refresh_interval, 0.01)
	var obstacle_hit := _raycast_static_obstacle(global_position, target.global_position)
	if obstacle_hit.is_empty():
		has_detour_waypoint = false
		return

	var obstacle := obstacle_hit.get("collider") as StaticBody2D
	if obstacle == null:
		has_detour_waypoint = false
		return

	var waypoint := _pick_detour_waypoint(obstacle, target.global_position)
	if waypoint == Vector2.INF:
		has_detour_waypoint = false
		return

	detour_waypoint = waypoint
	has_detour_waypoint = true


func _pick_detour_waypoint(obstacle: StaticBody2D, target_position: Vector2) -> Vector2:
	var obstacle_bounds := _get_static_body_bounds(obstacle)
	if obstacle_bounds.size == Vector2.ZERO:
		return Vector2.INF

	obstacle_bounds = obstacle_bounds.grow(config.detour_waypoint_margin)
	var candidates: Array[Vector2] = [
		obstacle_bounds.position,
		obstacle_bounds.position + Vector2(obstacle_bounds.size.x, 0.0),
		obstacle_bounds.position + obstacle_bounds.size,
		obstacle_bounds.position + Vector2(0.0, obstacle_bounds.size.y),
	]

	var best_waypoint := Vector2.INF
	var best_score := INF
	for candidate in candidates:
		if not _raycast_static_obstacle(global_position, candidate).is_empty():
			continue

		var target_visibility_penalty := 0.0
		if not _raycast_static_obstacle(candidate, target_position).is_empty():
			target_visibility_penalty = 300.0

		var score := global_position.distance_to(candidate) + candidate.distance_to(target_position)
		score += target_visibility_penalty
		if score < best_score:
			best_score = score
			best_waypoint = candidate

	return best_waypoint


func _raycast_static_obstacle(from_position: Vector2, to_position: Vector2) -> Dictionary:
	var space_state := get_world_2d().direct_space_state
	var excluded_rids: Array[RID] = [get_rid()]
	var target_collision := target as CollisionObject2D
	if target_collision != null:
		excluded_rids.append(target_collision.get_rid())

	for _index in range(8):
		var query := PhysicsRayQueryParameters2D.create(from_position, to_position)
		query.collision_mask = config.detour_obstacle_collision_mask
		query.collide_with_areas = false
		query.exclude = excluded_rids
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			return {}

		var collider: Object = hit.get("collider")
		if collider is StaticBody2D:
			return hit

		if collider is CollisionObject2D:
			excluded_rids.append(collider.get_rid())
			continue

		return {}

	return {}


func _get_static_body_bounds(body: StaticBody2D) -> Rect2:
	var has_bounds := false
	var bounds := Rect2()

	for child in body.get_children():
		var collision_shape := child as CollisionShape2D
		if collision_shape == null or collision_shape.disabled or collision_shape.shape == null:
			continue

		var shape_bounds := _get_collision_shape_bounds(collision_shape)
		if not has_bounds:
			bounds = shape_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(shape_bounds)

	if has_bounds:
		return bounds

	return Rect2(body.global_position - Vector2(32.0, 32.0), Vector2(64.0, 64.0))


func _get_collision_shape_bounds(collision_shape: CollisionShape2D) -> Rect2:
	if collision_shape.shape is RectangleShape2D:
		var rectangle := collision_shape.shape as RectangleShape2D
		var half_size := rectangle.size * 0.5
		var local_points: Array[Vector2] = [
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		]
		return _get_bounds_from_local_points(collision_shape, local_points)

	return Rect2(collision_shape.global_position - Vector2(32.0, 32.0), Vector2(64.0, 64.0))


func _get_bounds_from_local_points(node: Node2D, local_points: Array[Vector2]) -> Rect2:
	var first_point := node.global_transform * local_points[0]
	var min_position := first_point
	var max_position := first_point

	for index in range(1, local_points.size()):
		var point := node.global_transform * local_points[index]
		min_position.x = minf(min_position.x, point.x)
		min_position.y = minf(min_position.y, point.y)
		max_position.x = maxf(max_position.x, point.x)
		max_position.y = maxf(max_position.y, point.y)

	return Rect2(min_position, max_position - min_position)


func _update_obstacle_avoidance(chase_direction: Vector2, moved_distance: float, delta: float) -> void:
	if not config.obstacle_avoidance_enabled or chase_direction == Vector2.ZERO:
		return

	var obstacle_normal := _get_obstacle_collision_normal()
	if obstacle_normal != Vector2.ZERO:
		stuck_timer = 0.0
		_start_obstacle_avoidance(chase_direction, obstacle_normal)
		return

	if moved_distance <= config.obstacle_stuck_min_distance:
		stuck_timer += delta
		if stuck_timer >= config.obstacle_stuck_time:
			stuck_timer = 0.0
			avoidance_side *= -1.0
			_start_obstacle_avoidance(chase_direction, Vector2.ZERO)
	else:
		stuck_timer = maxf(stuck_timer - delta * 2.0, 0.0)


func _get_obstacle_collision_normal() -> Vector2:
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		var collider: Object = collision.get_collider()
		if collider is StaticBody2D:
			return collision.get_normal()

	return Vector2.ZERO


func _start_obstacle_avoidance(chase_direction: Vector2, obstacle_normal: Vector2) -> void:
	var tangent := Vector2.ZERO
	if obstacle_normal != Vector2.ZERO:
		tangent = Vector2(-obstacle_normal.y, obstacle_normal.x)
		var opposite_tangent := -tangent
		if opposite_tangent.dot(chase_direction) > tangent.dot(chase_direction):
			tangent = opposite_tangent
		elif absf(tangent.dot(chase_direction)) < 0.05:
			tangent *= avoidance_side
	else:
		tangent = Vector2(-chase_direction.y, chase_direction.x) * avoidance_side

	if tangent == Vector2.ZERO:
		return

	avoidance_direction = tangent.normalized()
	avoidance_remaining = config.obstacle_avoidance_duration


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


func _roll_xp_drop_count() -> int:
	var min_rolls := maxi(0, config.xp_drop_rolls_min)
	var max_rolls := maxi(min_rolls, config.xp_drop_rolls_max)
	return Rng.range_i(min_rolls, max_rolls)


func _get_xp_drop_position(drop_position: Vector2, drop_index: int, drop_count: int) -> Vector2:
	if drop_count <= 1:
		return drop_position

	var angle := TAU * float(drop_index) / float(drop_count)
	return drop_position + Vector2.RIGHT.rotated(angle) * 14.0


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
