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
var beam_targets: Array[Node2D] = []
var beam_lock_elapsed: Array[float] = []
var beam_out_of_range_elapsed: Array[float] = []
var beam_damage_remainders: Array[Dictionary] = []
var retarget_elapsed := 0.0
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
	retarget_elapsed = 0.0
	beam_targets.clear()
	beam_lock_elapsed.clear()
	beam_out_of_range_elapsed.clear()
	beam_damage_remainders.clear()
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

	if not beam_targets.is_empty():
		_update_target_lock_state(delta)
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
	var beam_count := weapon_instance.get_beam_count()
	_ensure_beam_channels(beam_count)
	_ensure_target_slots(beam_count)
	retarget_elapsed = 0.0
	_retarget_missing_slots()
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

	var beam_count := weapon_instance.get_beam_count()
	_ensure_beam_channels(beam_count)
	_ensure_target_slots(beam_count)
	_update_target_lock_state(delta)
	retarget_elapsed += delta
	if retarget_elapsed >= weapon_instance.get_beam_retarget_interval():
		retarget_elapsed = fmod(retarget_elapsed, weapon_instance.get_beam_retarget_interval())
		_retarget_missing_slots()
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
	beam_directions.clear()
	var beam_count := beam_rays.size()
	for index in range(beam_count):
		var direction := Vector2.ZERO
		if index < beam_targets.size() and _is_target_alive(beam_targets[index]):
			direction = global_position.direction_to(beam_targets[index].global_position)
		if direction.length_squared() <= 0.0:
			beam_directions.append(Vector2.ZERO)
			_update_laser_visual_for(beam_lines[index], Vector2.ZERO)
			beam_lines[index].visible = false
			continue
		if index == 0:
			beam_direction = direction
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
	for index in range(beam_rays.size()):
		if index >= beam_targets.size() or not _is_target_alive(beam_targets[index]):
			continue
		if index >= beam_directions.size() or beam_directions[index].is_zero_approx():
			continue
		# Selalu ambil ulang dari WeaponInstance pada setiap tick/beam. Jangan cache
		# nilai ini saat setup karena level dan Talisman dapat berubah saat beam aktif.
		var damage_result := weapon_instance.get_live_damage_result()
		_damage_enemies_in_beam(
			index,
			beam_rays[index],
			beam_directions[index],
			damage_result
		)


func _damage_enemies_in_beam(
	beam_index: int,
	beam_ray: RayCast2D,
	direction: Vector2,
	damage_result: Dictionary
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
		if global_position.distance_to(enemy.global_position) > beam_range:
			continue

		var enemy_id := enemy.get_instance_id()
		if candidate_ids.has(enemy_id):
			continue

		candidate_ids[enemy_id] = true
		candidate_enemies.append(enemy)

	candidate_enemies.sort_custom(func(left: Node2D, right: Node2D) -> bool:
		return global_position.distance_squared_to(left.global_position) \
			< global_position.distance_squared_to(right.global_position)
	)

	var max_targets := weapon_instance.get_beam_pierce_count()
	for target_index in range(candidate_enemies.size()):
		if max_targets > 0 and target_index >= max_targets:
			break

		var enemy := candidate_enemies[target_index]
		var raw_damage := (
			float(damage_result.get("raw_amount", damage_result.get("amount", 0)))
			* weapon_instance.get_beam_damage_multiplier(target_index)
		)
		var damage := _consume_fractional_damage(beam_index, target_index, raw_damage)
		weapon_instance.apply_damage(
			enemy,
			maxi(0, damage),
			direction,
			enemy.global_position,
			bool(damage_result.get("is_critical", false))
		)


func _ensure_target_slots(required_count: int) -> void:
	while beam_targets.size() < required_count:
		beam_targets.append(null)
		beam_lock_elapsed.append(0.0)
		beam_out_of_range_elapsed.append(0.0)
		beam_damage_remainders.append({})
	while beam_targets.size() > required_count:
		beam_targets.pop_back()
		beam_lock_elapsed.pop_back()
		beam_out_of_range_elapsed.pop_back()
		beam_damage_remainders.pop_back()


func _consume_fractional_damage(beam_index: int, target_index: int, raw_damage: float) -> int:
	if beam_index < 0 or beam_index >= beam_damage_remainders.size():
		return maxi(0, roundi(raw_damage))
	var remainders := beam_damage_remainders[beam_index]
	var accumulated := raw_damage + float(remainders.get(target_index, 0.0))
	var applied_damage := maxi(0, floori(accumulated + 0.00001))
	remainders[target_index] = maxf(0.0, accumulated - float(applied_damage))
	return applied_damage


func _update_target_lock_state(delta: float) -> void:
	var release_range := get_range() + weapon_instance.get_beam_lock_range_margin()
	for index in range(beam_targets.size()):
		var target := beam_targets[index]
		if not _is_target_alive(target):
			_release_target_slot(index)
			continue

		beam_lock_elapsed[index] += delta
		if global_position.distance_to(target.global_position) <= release_range:
			beam_out_of_range_elapsed[index] = 0.0
			continue

		beam_out_of_range_elapsed[index] += delta
		if beam_lock_elapsed[index] < weapon_instance.get_beam_minimum_lock_duration():
			continue
		if beam_out_of_range_elapsed[index] < weapon_instance.get_beam_out_of_range_grace_time():
			continue
		_release_target_slot(index)


func _retarget_missing_slots() -> void:
	for index in range(beam_targets.size()):
		if _is_target_alive(beam_targets[index]):
			continue
		var target := _find_target_for_slot(index, true)
		if target == null:
			target = _find_target_for_slot(index, false)
		if target != null:
			beam_targets[index] = target
			beam_lock_elapsed[index] = 0.0
			beam_out_of_range_elapsed[index] = 0.0

	current_target = beam_targets[0] if not beam_targets.is_empty() else null


func _find_target_for_slot(slot_index: int, require_unique: bool) -> Node2D:
	var nearest: Node2D
	var nearest_distance := get_range()
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if not _is_target_alive(enemy):
			continue
		if require_unique and _is_target_locked_by_other_slot(enemy, slot_index):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance > nearest_distance:
			continue
		nearest = enemy
		nearest_distance = distance
	return nearest


func _is_target_locked_by_other_slot(target: Node2D, slot_index: int) -> bool:
	for index in range(beam_targets.size()):
		if index != slot_index and beam_targets[index] == target:
			return true
	return false


func _release_target_slot(index: int) -> void:
	beam_targets[index] = null
	beam_lock_elapsed[index] = 0.0
	beam_out_of_range_elapsed[index] = 0.0


func _is_target_alive(target: Variant) -> bool:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	for property in target.get_property_list():
		if String(property.get("name", "")) == "is_dead":
			return not bool(target.get("is_dead"))
	return true


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
