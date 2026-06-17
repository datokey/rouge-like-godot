extends "res://scripts/gameplay/weapons/WeaponBase.gd"
class_name BasicGun

@export var projectile_scene: PackedScene

var attack_timer := 0.0


func _on_weapon_setup() -> void:
	attack_timer = 0.0


func _physics_process(delta: float) -> void:
	if get_owner_node() == null:
		return
	if projectile_scene == null:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	if attack_timer > 0.0:
		return

	var target := get_nearest_enemy()
	if target == null:
		return

	_shoot_projectiles(target)
	attack_timer = get_cooldown()


func _shoot_projectiles(target: Node2D) -> void:
	var owner_node := get_owner_node()
	if owner_node == null:
		return

	var projectile_count: int = weapon_instance.get_projectile_count()
	var base_direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var spread_step := deg_to_rad(_get_spread_angle_degrees())
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
			get_damage(),
			weapon_instance.get_projectile_speed()
		)


func _get_spread_angle_degrees() -> float:
	if weapon_instance == null or weapon_instance.definition == null:
		return 8.0

	var value: Variant = weapon_instance.definition.get("spread_angle_degrees")
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)

	return 8.0
