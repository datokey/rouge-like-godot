extends SceneTree

const BEAM_DEFINITION := preload("res://resources/weapons/BeamGun.tres")
const DAMAGE_TALISMAN := preload("res://upgrades/talismans/damage.tres")

var _failed := false


class TestPlayer extends Node2D:
	func get_nearest_enemy_in_range(attack_range: float) -> Node2D:
		for node in get_tree().get_nodes_in_group("enemy"):
			var enemy := node as Node2D
			if enemy != null and global_position.distance_to(enemy.global_position) <= attack_range:
				return enemy
		return null

	func heal(_amount: int) -> void:
		pass


class TestEnemy extends CharacterBody2D:
	var damage_amounts: Array[int] = []

	func _init() -> void:
		add_to_group("enemy")
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 8.0
		collision.shape = shape
		add_child(collision)

	func take_damage(
		amount: int,
		_direction: Vector2,
		_hit_position: Vector2,
		_is_critical: bool = false,
		_source_type: StringName = &"unknown"
	) -> void:
		damage_amounts.append(amount)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root
	var player := TestPlayer.new()
	scene_root.add_child(player)
	var holder := Node2D.new()
	player.add_child(holder)

	var build := BuildManager.new()
	build.setup(player)
	var definition := BEAM_DEFINITION.duplicate(true) as BeamWeaponDefinition
	definition.base_damage = 100.0
	definition.damage_per_level = 0.0
	definition.base_range = 150.0
	# Hilangkan random crit dari test, tetapi pertahankan tag BEAM untuk Talisman.
	definition.compatibility_tags = [&"BEAM", &"USES_ATTACK_SPEED", &"CAN_LIFESTEAL"]

	var manager := WeaponManager.new()
	manager.setup(player, holder, build)
	_assert(manager.add_weapon(definition), "BeamGun gagal dibuat")
	var instance := manager.get_weapon_instance("beam_gun")
	var beam := manager.weapon_nodes.get("beam_gun") as BeamGun
	beam.set_physics_process(false)
	var original_beam_node_id := beam.get_instance_id()

	var enemy := TestEnemy.new()
	enemy.position = Vector2(60.0, 0.0)
	scene_root.add_child(enemy)
	await physics_frame
	await physics_frame

	beam._physics_process(0.0)
	_assert(enemy.damage_amounts.back() == 100, "base damage tick Beam salah")

	var damage_upgrade := _find_damage_upgrade(definition)
	_assert(damage_upgrade != null, "upgrade damage Beam tidak ditemukan")
	_assert(manager.apply_stat_upgrade("beam_gun", damage_upgrade, 0.20), "upgrade damage Beam gagal")
	beam._damage_current_raycast_targets()
	_assert(enemy.damage_amounts.back() == 120, "damage tick tidak membaca upgrade level secara live")

	_assert(build.add_talisman(DAMAGE_TALISMAN, 0.10), "Damage Talisman gagal diterapkan")
	beam._damage_current_raycast_targets()
	_assert(enemy.damage_amounts.back() == 130, "damage tick tidak membaca Talisman secara live")
	_assert(beam.get_instance_id() == original_beam_node_id, "node BeamGun dibuat ulang setelah modifier")
	_assert(instance.get_damage_preview() == 130, "hasil tick berbeda dari WeaponInstance")

	# Damage pecahan tidak boleh hilang sebelum take_damage(). Dengan base 4 dan
	# Talisman 10%, lima tick harus menghasilkan 22 total damage (5 x 4.4).
	definition.base_damage = 4.0
	instance.local_percent_modifiers[&"weapon.damage"] = 0.0
	beam.beam_damage_remainders[0].clear()
	enemy.damage_amounts.clear()
	for _tick in range(5):
		beam._damage_current_raycast_targets()
	var fractional_total := 0
	for amount in enemy.damage_amounts:
		fractional_total += amount
	_assert(is_equal_approx(instance.get_damage_value(), 4.4), "damage float live tidak menyimpan bonus pecahan")
	_assert(fractional_total == 22, "damage pecahan dibulatkan sebelum take_damage")

	if _failed:
		quit(1)
	else:
		print("Beam live-damage regression tests: PASS")
		quit(0)


func _find_damage_upgrade(definition: Resource) -> WeaponUpgradeDefinition:
	for resource in definition.upgrade_options:
		var upgrade := resource as WeaponUpgradeDefinition
		if upgrade != null and upgrade.stat_type == WeaponUpgradeDefinition.StatType.DAMAGE:
			return upgrade
	return null


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
