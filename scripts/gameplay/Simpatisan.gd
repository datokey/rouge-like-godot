extends Node2D
class_name Simpatisan

# Simpatisan adalah minion yang dipanggil oleh weapon Koalisi Dadakan.
# Script ini sepenuhnya data-driven — semua value datang dari definisi weapon.

@export var projectile_scene: PackedScene
@export var spread_angle_degrees := 5.0

var attack_range := 400.0
var attack_cooldown := 1.5
var projectile_speed := 400.0
var damage := 0
var lifetime := 25.0
var orbit_index := 0
var orbit_radius := 60.0
var orbit_speed := 1.2
var owner_player: Node2D

var _attack_timer := 0.0
var _lifetime_timer := 0.0
var _orbit_angle := 0.0


func setup(
	new_owner_player: Node2D,
	new_damage: int,
	new_attack_range: float,
	new_attack_cooldown: float,
	new_projectile_speed: float,
	new_lifetime: float,
	new_orbit_index: int,
	new_orbit_radius: float,
	new_projectile_scene: PackedScene
) -> void:
	owner_player = new_owner_player
	damage = new_damage
	attack_range = new_attack_range
	attack_cooldown = new_attack_cooldown
	projectile_speed = new_projectile_speed
	lifetime = new_lifetime
	orbit_index = new_orbit_index
	orbit_radius = new_orbit_radius
	projectile_scene = new_projectile_scene

	# Distribusikan orbit agar minion-minion tersebar merata mengelilingi player.
	_orbit_angle = (TAU / 4.0) * float(orbit_index)
	_attack_timer = randf_range(0.0, attack_cooldown)
	_lifetime_timer = 0.0


func _physics_process(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		call_deferred("queue_free")
		return

	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		call_deferred("queue_free")
		return

	_update_orbit(delta)
	_update_attack(delta)


func _update_orbit(delta: float) -> void:
	# Minion mengorbit di sekitar player.
	_orbit_angle += orbit_speed * delta
	if _orbit_angle > TAU:
		_orbit_angle -= TAU

	var target_offset := Vector2(
		cos(_orbit_angle) * orbit_radius,
		sin(_orbit_angle) * orbit_radius
	)
	global_position = global_position.lerp(
		owner_player.global_position + target_offset,
		delta * 8.0
	)


func _update_attack(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if _attack_timer > 0.0:
		return
	if projectile_scene == null:
		return

	var target := _find_nearest_enemy()
	if target == null:
		return

	_fire_projectile(target)
	_attack_timer = attack_cooldown


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := attack_range

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
	var projectile := projectile_scene.instantiate()
	var scene_root := get_tree().current_scene
	if scene_root == null:
		projectile.queue_free()
		return

	scene_root.add_child(projectile)

	var target_pos := target.global_position
	if projectile.has_method("setup"):
		projectile.call(
			"setup",
			global_position,
			target_pos,
			damage,
			projectile_speed
		)
