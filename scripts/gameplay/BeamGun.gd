extends WeaponBase
class_name BeamGun

@export var laser_color := Color(0.35, 0.9, 1.0, 0.9)

@onready var raycast: RayCast2D = $RayCast2D
@onready var laser_line: Line2D = $Line2D

var cooldown_elapsed := INF
var beam_elapsed := 0.0
var damage_tick_timer := 0.0
var is_beam_active := false
var current_target: Node2D
var beam_direction := Vector2.RIGHT
var beam_rays: Array[RayCast2D] = []
var beam_lines: Array[Line2D] = []
var beam_directions: Array[Vector2] = []


func _ready() -> void:
	laser_line.visible = false
	laser_line.default_color = laser_color
	raycast.enabled = true
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true
	beam_rays = [raycast]
	beam_lines = [laser_line]


func _on_weapon_setup() -> void:
	cooldown_elapsed = INF
	beam_elapsed = 0.0
	damage_tick_timer = 0.0
	is_beam_active = false
	_update_laser_visual(Vector2.ZERO)

	var owner_node := get_owner_node()
	if owner_node is CollisionObject2D:
		raycast.add_exception(owner_node)


func _physics_process(delta: float) -> void:
	var owner_node := get_owner_node()
	if owner_node == null:
		return

	global_position = owner_node.global_position

	if is_beam_active:
		_update_active_beam(delta)
		return

	_set_beams_visible(false)
	cooldown_elapsed += delta
	if cooldown_elapsed < get_cooldown():
		return

	var target := get_nearest_enemy()
	if target == null:
		return

	_start_beam(target)


func _start_beam(target: Node2D) -> void:
	current_target = target
	_ensure_beam_channels(weapon_instance.get_beam_count())
	beam_elapsed = 0.0
	damage_tick_timer = 0.0
	is_beam_active = true
	_sync_beam_visuals()
	_update_beam_direction()
	_damage_current_raycast_targets()


func _update_active_beam(delta: float) -> void:
	beam_elapsed += delta
	if beam_elapsed >= weapon_instance.get_beam_duration():
		_finish_beam()
		return

	_ensure_beam_channels(weapon_instance.get_beam_count())
	_sync_beam_visuals()
	_update_beam_direction()

	damage_tick_timer -= delta
	while damage_tick_timer <= 0.0 and is_beam_active:
		_damage_current_raycast_targets()
		damage_tick_timer += weapon_instance.get_beam_tick_interval()


func _finish_beam() -> void:
	is_beam_active = false
	_set_beams_visible(false)
	cooldown_elapsed = 0.0


func _update_beam_direction() -> void:
	if current_target == null or not is_instance_valid(current_target):
		current_target = get_nearest_enemy()

	if current_target != null:
		beam_direction = global_position.direction_to(current_target.global_position)

	if beam_direction.length_squared() <= 0.0:
		beam_direction = Vector2.RIGHT

	beam_directions.clear()
	var beam_count := beam_rays.size()
	var spread_angle := deg_to_rad(weapon_instance.get_spread_angle_degrees())
	var start_offset := -float(beam_count - 1) * 0.5
	for index in range(beam_count):
		var direction := beam_direction.normalized().rotated(
			(start_offset + float(index)) * spread_angle
		)
		var end_point := direction * get_range()
		beam_directions.append(direction)
		_update_laser_visual_for(beam_lines[index], end_point)
		beam_rays[index].target_position = end_point
		beam_rays[index].force_raycast_update()


func _update_laser_visual(end_point: Vector2) -> void:
	_update_laser_visual_for(laser_line, end_point)


func _update_laser_visual_for(line: Line2D, end_point: Vector2) -> void:
	line.clear_points()
	line.add_point(Vector2.ZERO)
	line.add_point(end_point)


func _damage_current_raycast_targets() -> void:
	var damaged_enemy_ids := {}
	for index in range(beam_rays.size()):
		_damage_enemies_in_beam(
			beam_rays[index],
			beam_directions[index],
			damaged_enemy_ids
		)


func _damage_enemies_in_beam(
	beam_ray: RayCast2D,
	direction: Vector2,
	damaged_enemy_ids: Dictionary
) -> void:
	var beam_range := get_range()
	var query_shape := RectangleShape2D.new()
	query_shape.size = Vector2(beam_range, weapon_instance.get_beam_width())

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(
		direction.angle(),
		global_position + direction * beam_range * 0.5
	)
	query.collision_mask = beam_ray.collision_mask
	query.collide_with_areas = beam_ray.collide_with_areas
	query.collide_with_bodies = beam_ray.collide_with_bodies
	query.exclude = _get_owner_collision_rids()

	var max_results := weapon_instance.get_beam_max_collision_results()
	var hits := get_world_2d().direct_space_state.intersect_shape(query, max_results)
	var candidate_enemies: Array[Node2D] = []
	var candidate_ids := {}
	for hit in hits:
		var enemy := _resolve_enemy_from_collider(hit.get("collider")) as Node2D
		if enemy == null:
			continue

		var enemy_id := enemy.get_instance_id()
		if candidate_ids.has(enemy_id) or damaged_enemy_ids.has(enemy_id):
			continue

		candidate_ids[enemy_id] = true
		candidate_enemies.append(enemy)

	candidate_enemies.sort_custom(func(left: Node2D, right: Node2D) -> bool:
		return global_position.distance_squared_to(left.global_position) \
			< global_position.distance_squared_to(right.global_position)
	)

	var max_targets := weapon_instance.get_beam_pierce_count()
	for enemy in candidate_enemies:
		if max_targets > 0 and damaged_enemy_ids.size() >= max_targets:
			break

		var enemy_id := enemy.get_instance_id()
		damaged_enemy_ids[enemy_id] = true
		var damage_result := get_damage_result()
		weapon_instance.apply_damage(
			enemy,
			int(damage_result.get("amount", 0)),
			direction,
			enemy.global_position,
			bool(damage_result.get("is_critical", false))
		)


func _get_owner_collision_rids() -> Array[RID]:
	var excluded_rids: Array[RID] = []
	var owner_node := get_owner_node()
	if owner_node == null:
		return excluded_rids

	if owner_node is CollisionObject2D:
		excluded_rids.append((owner_node as CollisionObject2D).get_rid())
	for child in owner_node.get_children():
		if child is CollisionObject2D:
			excluded_rids.append((child as CollisionObject2D).get_rid())

	return excluded_rids


func _sync_beam_visuals() -> void:
	var current_color := weapon_instance.get_beam_color()
	var current_width := weapon_instance.get_beam_width()
	for line in beam_lines:
		line.visible = true
		line.width = current_width
		line.default_color = current_color


func _ensure_beam_channels(required_count: int) -> void:
	while beam_rays.size() < required_count:
		var new_ray := raycast.duplicate() as RayCast2D
		var new_line := laser_line.duplicate() as Line2D
		add_child(new_ray)
		add_child(new_line)
		beam_rays.append(new_ray)
		beam_lines.append(new_line)

		var owner_node := get_owner_node()
		if owner_node is CollisionObject2D:
			new_ray.add_exception(owner_node)

	while beam_rays.size() > required_count:
		beam_rays.pop_back().queue_free()
		beam_lines.pop_back().queue_free()


func _set_beams_visible(is_visible: bool) -> void:
	for line in beam_lines:
		line.visible = is_visible


func _resolve_enemy_from_collider(collider: Object) -> Node:
	var node := collider as Node
	if node == null:
		return null
	if node.is_in_group("enemy"):
		return node

	var parent := node.get_parent()
	if parent != null and parent.is_in_group("enemy"):
		return parent

	return null
