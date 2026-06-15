extends Node2D
class_name BasicGun

@export var projectile_scene: PackedScene
@export var spread_angle_degrees := 8.0

var weapon_instance: RefCounted
var attack_timer := 0.0


func setup(new_weapon_instance: RefCounted) -> void:
	weapon_instance = new_weapon_instance
	attack_timer = 0.0


func _physics_process(delta: float) -> void:
	if weapon_instance == null or weapon_instance.owner_node == null:
		return
	if projectile_scene == null:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	if attack_timer > 0.0:
		return

	var target := _get_target()
	if target == null:
		return

	_shoot_projectiles(target)
	attack_timer = weapon_instance.get_cooldown()


func _get_target() -> Node2D:
	var owner_node: Node2D = weapon_instance.owner_node
	if owner_node.has_method("get_nearest_enemy_in_range"):
		return owner_node.call("get_nearest_enemy_in_range", weapon_instance.get_attack_range()) as Node2D

	return null


func _shoot_projectiles(target: Node2D) -> void:
	var owner_node: Node2D = weapon_instance.owner_node
	var projectile_count: int = weapon_instance.get_projectile_count()
	var base_direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var spread_step := deg_to_rad(spread_angle_degrees)
	var start_offset := -float(projectile_count - 1) * 0.5

	for index in range(projectile_count):
		var projectile := projectile_scene.instantiate()
		owner_node.get_tree().current_scene.add_child(projectile)

		var spread_angle := (start_offset + float(index)) * spread_step
		var shot_direction: Vector2 = base_direction.rotated(spread_angle)
		var target_position: Vector2 = owner_node.global_position + shot_direction * 100.0
		projectile.call(
			"setup",
			owner_node.global_position,
			target_position,
			weapon_instance.get_damage(),
			weapon_instance.get_projectile_speed()
		)
