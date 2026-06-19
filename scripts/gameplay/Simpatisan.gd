extends Node2D
class_name Simpatisan

# Simpatisan adalah minion yang dipanggil oleh weapon Koalisi Dadakan.
# Script ini sepenuhnya data-driven — semua value datang dari definisi weapon.

@export var projectile_scene: PackedScene
@export var spread_angle_degrees := 5.0

var lifetime := 25.0
var orbit_index := 0
var orbit_speed := 1.2
var weapon_instance: WeaponInstance

var _attack_elapsed := 0.0
var _lifetime_timer := 0.0
var _orbit_angle := 0.0


func setup(
	new_weapon_instance: WeaponInstance,
	new_lifetime: float,
	new_orbit_index: int
) -> void:
	weapon_instance = new_weapon_instance
	lifetime = new_lifetime
	orbit_index = new_orbit_index

	# Distribusikan orbit agar minion-minion tersebar merata mengelilingi player.
	_orbit_angle = (TAU / 4.0) * float(orbit_index)
	var rng := get_node_or_null("/root/Rng")
	_attack_elapsed = -float(rng.call(
		"range_f",
		0.0,
		weapon_instance.get_summon_attack_cooldown()
	)) if rng != null else 0.0
	_lifetime_timer = 0.0


func _physics_process(delta: float) -> void:
	var owner_player := _get_owner_player()
	if owner_player == null:
		call_deferred("queue_free")
		return

	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		call_deferred("queue_free")
		return

	_update_orbit(delta, owner_player)
	_update_attack(delta)


func _update_orbit(delta: float, owner_player: Node2D) -> void:
	# Minion mengorbit di sekitar player.
	_orbit_angle += orbit_speed * delta
	if _orbit_angle > TAU:
		_orbit_angle -= TAU

	var target_offset := Vector2(
		cos(_orbit_angle) * weapon_instance.get_summon_orbit_radius(),
		sin(_orbit_angle) * weapon_instance.get_summon_orbit_radius()
	)
	global_position = global_position.lerp(
		owner_player.global_position + target_offset,
		delta * 8.0
	)


func _update_attack(delta: float) -> void:
	_attack_elapsed += delta
	if _attack_elapsed < weapon_instance.get_summon_attack_cooldown():
		return
	if weapon_instance.get_summon_projectile_scene() == null:
		return

	var target := _find_nearest_enemy()
	if target == null:
		return

	_fire_projectile(target)
	_attack_elapsed = 0.0


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := weapon_instance.get_attack_range()

	var tree := get_tree()
	if tree == null:
		return null

	for enemy in tree.get_nodes_in_group("enemy"):
		if not enemy is Node2D:
			continue
		var dist := global_position.distance_to((enemy as Node2D).global_position)
		if dist < nearest_dist:
			nearest = enemy as Node2D
			nearest_dist = dist

	return nearest


func _fire_projectile(target: Node2D) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	var projectile_scene_live := weapon_instance.get_summon_projectile_scene()
	var projectile_count := weapon_instance.get_projectile_count()
	var target_direction := global_position.direction_to(target.global_position)
	var start_offset := -float(projectile_count - 1) * 0.5
	for index in range(projectile_count):
		var projectile := projectile_scene_live.instantiate()
		if projectile == null:
			continue

		scene_root.add_child(projectile)
		var damage_result := weapon_instance.get_summon_damage_result()
		var angle_offset := deg_to_rad(spread_angle_degrees) * (start_offset + float(index))
		var target_pos := global_position + target_direction.rotated(angle_offset) * 1000.0
		if projectile.has_method("setup"):
			projectile.call(
				"setup",
				global_position,
				target_pos,
				int(damage_result.get("amount", 0)),
				weapon_instance.get_summon_projectile_speed(),
				1.0,
				weapon_instance,
				bool(damage_result.get("is_critical", false))
			)


func _get_owner_player() -> Node2D:
	if weapon_instance == null:
		return null

	var owner_player := weapon_instance.owner_node
	if not is_instance_valid(owner_player):
		return null

	return owner_player
