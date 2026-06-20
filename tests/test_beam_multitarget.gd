extends SceneTree

const BEAM_DEFINITION := preload("res://resources/weapons/BeamGun.tres")

var _failed := false


class TestModifierManager extends RefCounted:
	var critical_chance := 0.0
	var critical_damage := 0.0
	var life_steal := 0.0
	var critical_roll_requests := 0

	func get_critical_chance(_tags: Array) -> float:
		critical_roll_requests += 1
		return critical_chance

	func get_critical_damage(_tags: Array) -> float:
		return critical_damage

	func get_life_steal(_tags: Array) -> float:
		return life_steal

	func get_weapon_flat_modifier(_key: StringName, _tags: Array) -> float:
		return 0.0

	func get_weapon_talisman_percent_modifier(_key: StringName, _tags: Array) -> float:
		return 0.0

	func get_weapon_talisman_milestone_modifier(_key: StringName, _tags: Array) -> int:
		return 0


class TestPlayer extends Node2D:
	var current_hp := 50
	var max_hp := 100

	func get_nearest_enemy_in_range(attack_range: float) -> Node2D:
		var candidates: Array[Node2D] = []
		for node in get_tree().get_nodes_in_group("enemy"):
			var enemy := node as Node2D
			if enemy != null and global_position.distance_to(enemy.global_position) <= attack_range:
				candidates.append(enemy)
		candidates.sort_custom(func(left: Node2D, right: Node2D) -> bool:
			return global_position.distance_squared_to(left.global_position) \
				< global_position.distance_squared_to(right.global_position)
		)
		return candidates[0] if not candidates.is_empty() else null

	func heal(amount: int) -> void:
		current_hp = mini(max_hp, current_hp + amount)


class TestEnemy extends CharacterBody2D:
	var damage_amounts: Array[int] = []
	var critical_results: Array[bool] = []

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
		is_critical: bool = false,
		_source_type: StringName = &"unknown"
	) -> void:
		damage_amounts.append(amount)
		critical_results.append(is_critical)


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

	var modifiers := TestModifierManager.new()
	var definition := BEAM_DEFINITION.duplicate(true) as BeamWeaponDefinition
	definition.base_damage = 100.0
	definition.damage_per_level = 0.0
	definition.base_range = 200.0
	definition.base_beam_count = 1
	definition.max_beam_count = 3
	definition.beam_damage_falloff = 0.0

	var manager := WeaponManager.new()
	manager.setup(player, holder, modifiers)
	_assert(manager.add_weapon(definition), "BeamGun gagal dibuat")
	var instance := manager.get_weapon_instance("beam_gun")
	var beam := manager.weapon_nodes.get("beam_gun") as BeamGun
	beam.set_physics_process(false)

	var count_upgrade := _find_beam_count_upgrade(definition)
	_assert(count_upgrade != null, "upgrade BEAM_COUNT tidak ditemukan")
	_assert(manager.apply_stat_upgrade("beam_gun", count_upgrade, 1.0), "BEAM_COUNT pertama gagal")
	_assert(manager.apply_stat_upgrade("beam_gun", count_upgrade, 1.0), "BEAM_COUNT kedua gagal")
	_assert(instance.get_beam_count() == 3, "BEAM_COUNT lokal tidak menghasilkan tiga beam")
	_assert(
		float(instance.local_flat_modifiers.get(&"weapon.beam_count", 0.0)) == 2.0,
		"BEAM_COUNT tidak tersimpan di local modifier WeaponInstance"
	)
	_assert(int(BEAM_DEFINITION.base_beam_count) == 1, "resource BeamGun asli termutasi")

	var first := _spawn_enemy(scene_root, Vector2(80.0, 0.0))
	var second := _spawn_enemy(scene_root, Vector2(0.0, 90.0))
	var third := _spawn_enemy(scene_root, Vector2(-100.0, 0.0))
	var outside := _spawn_enemy(scene_root, Vector2(240.0, 0.0))
	await physics_frame
	await physics_frame

	beam._physics_process(0.0)
	_assert(_unique_target_count(beam.beam_targets) == 3, "beam tidak memilih tiga target unik")
	_assert(first.damage_amounts.size() == 1, "target pertama tidak menerima satu beam")
	_assert(second.damage_amounts.size() == 1, "target kedua tidak menerima satu beam")
	_assert(third.damage_amounts.size() == 1, "target ketiga tidak menerima satu beam")
	_assert(outside.damage_amounts.is_empty(), "target di luar attack range terkena beam")

	beam._finish_beam()
	second.queue_free()
	third.queue_free()
	outside.position = Vector2(400.0, 0.0)
	modifiers.critical_chance = 1.0
	modifiers.critical_damage = 1.0
	modifiers.life_steal = 0.5
	player.current_hp = 95
	var rolls_before := modifiers.critical_roll_requests
	await process_frame
	await physics_frame
	beam.cooldown_elapsed = INF
	beam._physics_process(0.0)
	_assert(beam.beam_targets.size() == 3, "jumlah target slot tidak mengikuti jumlah beam")
	_assert(_unique_target_count(beam.beam_targets) == 1, "satu enemy tidak dipakai ulang oleh semua beam")
	_assert(first.damage_amounts.size() == 4, "satu enemy tidak menerima damage dari ketiga beam")
	_assert(
		modifiers.critical_roll_requests - rolls_before == 3,
		"critical tidak dihitung sekali per beam"
	)
	_assert(first.critical_results.slice(1).all(func(value: bool) -> bool: return value), "hasil crit per beam salah")
	_assert(player.current_hp == player.max_hp, "lifesteal melewati atau gagal mencapai cap HP")

	beam._finish_beam()
	modifiers.critical_chance = 0.0
	modifiers.life_steal = 0.0
	definition.beam_damage_falloff = 0.25
	second = _spawn_enemy(scene_root, Vector2(140.0, 0.0))
	first.damage_amounts.clear()
	await physics_frame
	beam._damage_enemies_in_beam(
		0,
		beam.beam_rays[0],
		Vector2.RIGHT,
		{"amount": 100, "is_critical": false}
	)
	_assert(first.damage_amounts == [100], "damage target pertama tidak sesuai damage aktual")
	_assert(second.damage_amounts == [75], "damage falloff target kedua tidak sesuai")

	if _failed:
		quit(1)
	else:
		print("Beam multi-target regression tests: PASS")
		quit(0)


func _spawn_enemy(parent: Node, position: Vector2) -> TestEnemy:
	var enemy := TestEnemy.new()
	enemy.position = position
	parent.add_child(enemy)
	return enemy


func _find_beam_count_upgrade(definition: Resource) -> WeaponUpgradeDefinition:
	for resource in definition.upgrade_options:
		var upgrade := resource as WeaponUpgradeDefinition
		if upgrade != null and upgrade.stat_type == WeaponUpgradeDefinition.StatType.BEAM_COUNT:
			return upgrade
	return null


func _unique_target_count(targets: Array[Node2D]) -> int:
	var ids := {}
	for target in targets:
		ids[target.get_instance_id()] = true
	return ids.size()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
