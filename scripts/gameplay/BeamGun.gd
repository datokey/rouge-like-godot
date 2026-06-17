extends "res://scripts/gameplay/weapons/WeaponBase.gd"
class_name BeamGun

@export var laser_color := Color(0.35, 0.9, 1.0, 0.9)

@onready var raycast: RayCast2D = $RayCast2D
@onready var laser_line: Line2D = $Line2D

var cooldown_timer := 0.0
var beam_remaining := 0.0
var damage_tick_timer := 0.0
var current_target: Node2D
var beam_direction := Vector2.RIGHT


func _ready() -> void:
	laser_line.visible = false
	laser_line.default_color = laser_color
	raycast.enabled = true
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true


func _on_weapon_setup() -> void:
	cooldown_timer = 0.0
	beam_remaining = 0.0
	damage_tick_timer = 0.0
	_update_laser_visual(Vector2.ZERO)

	var owner_node := get_owner_node()
	if owner_node is CollisionObject2D:
		raycast.add_exception(owner_node)


func _physics_process(delta: float) -> void:
	var owner_node := get_owner_node()
	if owner_node == null:
		return

	global_position = owner_node.global_position

	if beam_remaining > 0.0:
		_update_active_beam(delta)
		return

	laser_line.visible = false
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	if cooldown_timer > 0.0:
		return

	var target := _get_target()
	if target == null:
		return

	_start_beam(target)


func _start_beam(target: Node2D) -> void:
	current_target = target
	beam_remaining = weapon_instance.get_beam_duration()
	damage_tick_timer = 0.0
	laser_line.visible = true
	laser_line.width = weapon_instance.get_beam_width()
	_update_beam_direction()
	_damage_current_raycast_target()


func _update_active_beam(delta: float) -> void:
	beam_remaining = maxf(beam_remaining - delta, 0.0)
	_update_beam_direction()

	damage_tick_timer -= delta
	while damage_tick_timer <= 0.0 and beam_remaining > 0.0:
		_damage_current_raycast_target()
		damage_tick_timer += weapon_instance.get_beam_tick_interval()

	if beam_remaining <= 0.0:
		laser_line.visible = false
		cooldown_timer = get_cooldown()


func _get_target() -> Node2D:
	return get_nearest_enemy()


func _update_beam_direction() -> void:
	if current_target == null or not is_instance_valid(current_target):
		current_target = _get_target()

	if current_target != null:
		beam_direction = global_position.direction_to(current_target.global_position)

	if beam_direction.length_squared() <= 0.0:
		beam_direction = Vector2.RIGHT

	var end_point: Vector2 = beam_direction.normalized() * get_range()
	_update_laser_visual(end_point)
	raycast.target_position = end_point
	raycast.force_raycast_update()


func _update_laser_visual(end_point: Vector2) -> void:
	laser_line.clear_points()
	laser_line.add_point(Vector2.ZERO)
	laser_line.add_point(end_point)


func _damage_current_raycast_target() -> void:
	raycast.force_raycast_update()
	if not raycast.is_colliding():
		return

	var collider := raycast.get_collider()
	var enemy := _resolve_enemy_from_collider(collider)
	if enemy == null or not enemy.has_method("take_damage"):
		return

	enemy.call("take_damage", get_damage(), beam_direction, raycast.get_collision_point())


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
