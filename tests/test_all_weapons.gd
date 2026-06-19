extends SceneTree

const WEAPON_DEFINITIONS: Array[Resource] = [
	preload("res://resources/weapons/BasicGun.tres"),
	preload("res://resources/weapons/AuraWeapon.tres"),
	preload("res://resources/weapons/BeamGun.tres"),
	preload("res://resources/weapons/KoalisiDadakan.tres"),
]
const PROJECTILE_SCRIPT := preload("res://scripts/gameplay/Projectile.gd")

var _failed := false


class TestPlayer extends Node2D:
	func get_nearest_enemy_in_range(attack_range: float) -> Node2D:
		var nearest: Node2D
		var nearest_distance := attack_range
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if not enemy is Node2D:
				continue
			var distance := global_position.distance_to(enemy.global_position)
			if distance < nearest_distance:
				nearest = enemy
				nearest_distance = distance
		return nearest


class TestEnemy extends CharacterBody2D:
	var damage_events := 0
	var total_damage := 0
	var slow_events := 0

	func _init() -> void:
		add_to_group("enemy")
		var body_shape := CollisionShape2D.new()
		var body_circle := CircleShape2D.new()
		body_circle.radius = 10.0
		body_shape.shape = body_circle
		add_child(body_shape)

		var hurtbox := Area2D.new()
		var hurtbox_shape := CollisionShape2D.new()
		var hurtbox_circle := CircleShape2D.new()
		hurtbox_circle.radius = 10.0
		hurtbox_shape.shape = hurtbox_circle
		hurtbox.add_child(hurtbox_shape)
		add_child(hurtbox)

	func take_damage(
		amount: int,
		_direction: Vector2,
		_hit_position: Vector2,
		_is_critical: bool = false,
		_source_type: StringName = &"unknown"
	) -> void:
		damage_events += 1
		total_damage += amount

	func apply_slow(_percent: float, _duration: float) -> void:
		slow_events += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root

	var player := TestPlayer.new()
	player.name = "TestPlayer"
	scene_root.add_child(player)

	var weapon_holder := Node2D.new()
	weapon_holder.name = "WeaponHolder"
	player.add_child(weapon_holder)

	var enemy := TestEnemy.new()
	enemy.name = "TestEnemy"
	enemy.position = Vector2(40.0, 0.0)
	scene_root.add_child(enemy)

	var manager := WeaponManager.new()
	manager.max_weapon_slots = WEAPON_DEFINITIONS.size()
	manager.setup(player, weapon_holder, null)
	for definition in WEAPON_DEFINITIONS:
		_assert(manager.add_weapon(definition), "gagal menambahkan %s" % definition.id)

	_assert(weapon_holder.get_child_count() == WEAPON_DEFINITIONS.size(), "jumlah node weapon tidak sesuai")
	for definition in WEAPON_DEFINITIONS:
		var instance := manager.get_weapon_instance(definition.id)
		var weapon := manager.weapon_nodes.get(definition.id) as WeaponBase
		_assert(instance != null, "WeaponInstance %s tidak ditemukan" % definition.id)
		_assert(weapon != null, "node %s bukan WeaponBase" % definition.id)
		if weapon != null:
			weapon.set_physics_process(false)
			_assert(weapon.weapon_instance == instance, "setup WeaponInstance gagal untuk %s" % definition.id)

	await physics_frame
	await physics_frame

	var basic := manager.weapon_nodes.get("basic_gun") as BasicGun
	var basic_instance := manager.get_weapon_instance("basic_gun")
	var expected_projectile_size := basic_instance.get_projectile_size()
	var pierce_upgrade: WeaponUpgradeDefinition
	for upgrade_resource in basic_instance.definition.upgrade_options:
		var upgrade := upgrade_resource as WeaponUpgradeDefinition
		if upgrade != null and upgrade.stat_type == WeaponUpgradeDefinition.StatType.PIERCE:
			pierce_upgrade = upgrade
			break
	_assert(manager.apply_stat_upgrade("basic_gun", pierce_upgrade, 0.15), "upgrade Pierce gagal")
	basic._physics_process(0.0)
	_assert(_count_projectiles(scene_root) > 0, "BasicGun tidak membuat projectile")
	var sized_projectile := _get_projectiles(scene_root)[0]
	var projectile_visual := sized_projectile.get_node("Visual") as Node2D
	var projectile_hitbox := sized_projectile.get_node("Hitbox") as Area2D
	_assert(
		projectile_visual.scale.is_equal_approx(Vector2.ONE * expected_projectile_size),
		"visual projectile tidak mengikuti projectile size"
	)
	_assert(
		projectile_hitbox.scale.is_equal_approx(projectile_visual.scale),
		"scale collision projectile berbeda dari visual"
	)
	var second_enemy := TestEnemy.new()
	second_enemy.position = Vector2(80.0, 0.0)
	scene_root.add_child(second_enemy)
	var first_enemy_area := enemy.get_child(1) as Area2D
	var second_enemy_area := second_enemy.get_child(1) as Area2D
	sized_projectile._on_area_entered(first_enemy_area)
	_assert(not sized_projectile.has_hit, "projectile Pierce berhenti pada target pertama")
	sized_projectile._on_area_entered(second_enemy_area)
	_assert(sized_projectile.has_hit, "projectile tidak berhenti setelah pierce habis")
	_assert(enemy.damage_events > 0 and second_enemy.damage_events > 0, "projectile Pierce tidak merusak dua target")

	var aura := manager.weapon_nodes.get("weapon_aura") as AuraWeapon
	var damage_before_aura := enemy.damage_events
	aura._physics_process(0.0)
	_assert(enemy.damage_events > damage_before_aura, "AuraWeapon tidak memberi tick damage")
	_assert(enemy.slow_events > 0, "AuraWeapon tidak menerapkan slow")

	var beam := manager.weapon_nodes.get("beam_gun") as BeamGun
	var damage_before_beam := enemy.damage_events
	beam._physics_process(0.0)
	_assert(beam.is_beam_active, "BeamGun tidak memulai beam")
	_assert(beam.laser_line.visible, "visual BeamGun tidak aktif")
	_assert(enemy.damage_events > damage_before_beam, "BeamGun tidak mengenai target")

	var summon := manager.weapon_nodes.get("koalisi_dadakan") as KoalisiDadakan
	summon._physics_process(0.0)
	_assert(not summon._active_minions.is_empty(), "KoalisiDadakan tidak membuat minion")

	var active_projectiles := _get_projectiles(scene_root)
	var active_minions := summon._active_minions.duplicate()
	var damage_before_death := enemy.damage_events
	root.get_node("EventBus").emit_signal("player_died")
	_assert(not manager.is_active, "WeaponManager masih aktif setelah player mati")
	for definition in WEAPON_DEFINITIONS:
		var instance := manager.get_weapon_instance(definition.id)
		var weapon := manager.weapon_nodes.get(definition.id) as WeaponBase
		_assert(not instance.is_active, "WeaponInstance %s masih aktif" % definition.id)
		_assert(not weapon.is_weapon_active, "node %s masih aktif" % definition.id)
		_assert(not weapon.is_physics_processing(), "physics %s masih berjalan" % definition.id)
	_assert(not beam.laser_line.visible, "visual beam masih aktif setelah player mati")
	_assert(
		not manager.get_weapon_instance("beam_gun").apply_damage(
			enemy, 10, Vector2.RIGHT, enemy.global_position
		),
		"damage baru diterima setelah player mati"
	)
	await process_frame
	for projectile in active_projectiles:
		_assert(not is_instance_valid(projectile), "projectile tersisa setelah player mati")
	for minion in active_minions:
		_assert(not is_instance_valid(minion), "summon tersisa setelah player mati")
	_assert(enemy.damage_events == damage_before_death, "damage terjadi setelah player mati")

	if _failed:
		quit(1)
	else:
		print("All weapon regression tests: PASS")
		quit(0)


func _count_projectiles(scene_root: Node) -> int:
	return _get_projectiles(scene_root).size()


func _get_projectiles(scene_root: Node) -> Array[Node]:
	var projectiles: Array[Node] = []
	for child in scene_root.get_children():
		if child.get_script() == PROJECTILE_SCRIPT:
			projectiles.append(child)
	return projectiles


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
