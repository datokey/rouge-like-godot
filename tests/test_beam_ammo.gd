extends SceneTree

const BEAM_DEFINITION := preload("res://resources/weapons/BeamGun.tres")

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
	var damage_events := 0

	func _init() -> void:
		add_to_group("enemy")
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 8.0
		collision.shape = shape
		add_child(collision)

	func take_damage(
		_amount: int,
		_direction: Vector2,
		_hit_position: Vector2,
		_is_critical: bool = false,
		_source_type: StringName = &"unknown"
	) -> void:
		damage_events += 1


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

	var definition := BEAM_DEFINITION.duplicate(true) as BeamWeaponDefinition
	definition.base_damage = 10.0
	definition.damage_per_level = 0.0
	definition.base_range = 150.0
	definition.beam_duration = 10.0
	definition.beam_tick_interval = 0.2
	definition.minimum_beam_tick_interval = 0.02
	definition.base_ammo_capacity = 2
	definition.max_ammo_capacity = 5
	definition.reload_duration = 1.0
	definition.minimum_reload_duration = 0.1
	definition.max_level = 10

	var manager := WeaponManager.new()
	manager.setup(player, holder, null)
	_assert(manager.add_weapon(definition), "BeamGun gagal dibuat")
	var instance := manager.get_weapon_instance("beam_gun")
	var beam := manager.weapon_nodes.get("beam_gun") as BeamGun
	beam.set_physics_process(false)
	var enemy := TestEnemy.new()
	enemy.position = Vector2(60.0, 0.0)
	scene_root.add_child(enemy)
	await physics_frame
	await physics_frame

	beam._physics_process(0.0)
	_assert(enemy.damage_events == 1, "tick pertama tidak memberi damage")
	_assert(beam.current_ammo == 1, "tick sukses tidak mengurangi satu ammo")
	_assert(not beam.is_reloading, "reload dimulai sebelum ammo habis")

	beam._update_active_beam(0.2)
	_assert(enemy.damage_events == 2, "tick kedua tidak memberi damage")
	_assert(beam.current_ammo == 0, "ammo tidak habis setelah dua tick sukses")
	_assert(beam.is_reloading and not beam.is_beam_active, "Beam tidak berhenti dan reload saat ammo habis")
	_assert(is_equal_approx(beam.reload_duration_snapshot, 1.0), "durasi reload awal tidak di-snapshot")

	var reload_upgrade := _find_upgrade(definition, WeaponUpgradeDefinition.StatType.RELOAD_DURATION)
	var ammo_upgrade := _find_upgrade(definition, WeaponUpgradeDefinition.StatType.AMMO_CAPACITY)
	var speed_upgrade := _find_upgrade(definition, WeaponUpgradeDefinition.StatType.FIRE_RATE)
	_assert(instance.apply_stat_upgrade(reload_upgrade, -0.5), "upgrade reload duration gagal")
	_assert(instance.apply_stat_upgrade(ammo_upgrade, 1.0), "upgrade ammo capacity gagal")
	_assert(is_equal_approx(instance.get_beam_reload_duration(), 0.5), "reload stat runtime tidak berubah")
	_assert(is_equal_approx(beam.reload_duration_snapshot, 1.0), "upgrade mengubah snapshot reload aktif")

	enemy.queue_free()
	await process_frame
	beam._physics_process(0.5)
	_assert(beam.is_reloading, "reload berhenti ketika target hilang")
	_assert(is_equal_approx(beam.reload_elapsed, 0.5), "progress reload tidak berjalan tanpa target")

	paused = true
	beam._physics_process(0.5)
	paused = false
	_assert(is_equal_approx(beam.reload_elapsed, 0.5), "reload berjalan saat game pause")

	beam._physics_process(0.49)
	_assert(beam.is_reloading, "reload selesai memakai durasi upgrade, bukan snapshot")
	beam._physics_process(0.02)
	_assert(not beam.is_reloading, "reload snapshot tidak selesai")
	_assert(beam.current_ammo == 3, "ammo tidak terisi penuh memakai capacity runtime")

	var ammo_before_empty_tick := beam.current_ammo
	_assert(not beam._damage_current_raycast_targets(), "tick kosong dilaporkan sebagai hit")
	_assert(beam.current_ammo == ammo_before_empty_tick, "tick tanpa damage mengurangi ammo")

	_assert(instance.apply_stat_upgrade(speed_upgrade, -0.5), "upgrade attack speed Beam gagal")
	_assert(is_equal_approx(instance.get_beam_tick_interval(), 0.1), "attack speed tidak mengubah tick_interval")
	_assert(
		is_equal_approx(instance.get_beam_activation_cooldown(), definition.base_cooldown),
		"attack speed ikut mengubah cooldown aktivasi Beam"
	)

	if _failed:
		quit(1)
	else:
		print("Beam ammo regression tests: PASS")
		quit(0)


func _find_upgrade(
	definition: Resource,
	stat_type: WeaponUpgradeDefinition.StatType
) -> WeaponUpgradeDefinition:
	for resource in definition.upgrade_options:
		var upgrade := resource as WeaponUpgradeDefinition
		if upgrade != null and upgrade.stat_type == stat_type:
			return upgrade
	return null


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
