extends SceneTree

const BASIC := preload("res://resources/weapons/BasicGun.tres")
const PROJECTILE_SCRIPT := preload("res://scripts/gameplay/Projectile.gd")

var _failed := false
var _ammo_events: Array[Dictionary] = []
var _reload_events: Array[Dictionary] = []


class TestPlayer extends Node2D:
	func get_nearest_enemy_in_range(attack_range: float) -> Node2D:
		var nearest: Node2D
		var nearest_distance := attack_range
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy is Node2D:
				var distance := global_position.distance_to(enemy.global_position)
				if distance < nearest_distance:
					nearest = enemy
					nearest_distance = distance
		return nearest


class TestEnemy extends Node2D:
	func _init() -> void:
		add_to_group("enemy")


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
	var enemy := TestEnemy.new()
	enemy.position = Vector2(40.0, 0.0)
	scene_root.add_child(enemy)

	var definition := BASIC.duplicate(true) as BasicGunDefinition
	definition.base_magazine_capacity = 2
	definition.magazine_capacity_per_level = 1
	definition.max_magazine_capacity = 10
	definition.base_reload_time = 1.0
	definition.reload_time_reduction_per_level = 0.2
	definition.minimum_reload_time = 0.1
	definition.base_projectile_count = 3

	var event_bus := root.get_node("EventBus")
	event_bus.weapon_ammo_changed.connect(_on_ammo_changed)
	event_bus.weapon_reload_changed.connect(_on_reload_changed)
	var manager := WeaponManager.new()
	manager.setup(player, holder, null)
	_assert(manager.add_weapon(definition), "BasicGun ammo gagal dibuat")
	var basic := manager.weapon_nodes.get("basic_gun") as BasicGun
	var instance := manager.get_weapon_instance("basic_gun")

	var projectiles_before := _count_projectiles(scene_root)
	basic._physics_process(0.0)
	_assert(_count_projectiles(scene_root) - projectiles_before == 3, "satu serangan tidak membuat tiga projectile")
	_assert(basic.current_ammo == 1, "multi-projectile menghabiskan lebih dari satu ammo")

	basic._physics_process(instance.get_cooldown())
	_assert(basic.current_ammo == 0, "serangan kedua tidak menghabiskan ammo terakhir")
	_assert(basic.state == BasicGun.State.RELOADING, "ammo nol tidak memulai auto-reload")
	_assert(is_equal_approx(basic.reload_duration_snapshot, 1.0), "durasi reload awal tidak di-snapshot")

	scene_root.remove_child(enemy)
	enemy.free()
	basic._physics_process(0.25)
	_assert(is_equal_approx(basic.state_timer, 0.75), "reload berhenti ketika target hilang")

	var damage_upgrade := _find_damage_upgrade(definition)
	_assert(instance.apply_stat_upgrade(damage_upgrade, 0.02), "setup upgrade saat reload gagal")
	_assert(instance.get_magazine_capacity() == 3, "kapasitas magazine tidak naik bersama level")
	_assert(is_equal_approx(instance.get_reload_time(), 0.8), "reload time tidak berkurang bersama level")
	_assert(is_equal_approx(basic.reload_duration_snapshot, 1.0), "upgrade mengubah snapshot reload aktif")

	basic._physics_process(0.74)
	_assert(basic.state == BasicGun.State.RELOADING, "reload selesai memakai durasi upgrade baru")
	basic._physics_process(0.02)
	_assert(basic.state == BasicGun.State.READY, "reload tidak kembali ke READY")
	_assert(basic.current_ammo == 3, "reload tidak mengisi kapasitas magazine terbaru")

	basic.current_ammo = 0
	basic._start_reload()
	var paused_remaining := basic.state_timer
	paused = true
	_assert(not basic.can_process(), "BasicGun masih diproses oleh engine saat pause")
	_assert(is_equal_approx(basic.state_timer, paused_remaining), "reload berjalan saat game pause")
	paused = false
	_assert(basic.can_process(), "BasicGun tidak aktif kembali setelah unpause")
	basic._physics_process(0.1)
	_assert(basic.state_timer < paused_remaining, "reload tidak dilanjutkan setelah unpause")

	_assert(not _ammo_events.is_empty(), "signal ammo tidak diteruskan ke EventBus")
	_assert(not _reload_events.is_empty(), "signal reload tidak diteruskan ke EventBus")

	holder.remove_child(basic)
	var detached_timer := basic.state_timer
	basic._physics_process(10.0)
	_assert(is_equal_approx(basic.state_timer, detached_timer), "BasicGun tetap memproses saat keluar tree")
	basic.free()

	if _failed:
		quit(1)
	else:
		print("BasicGun ammo regression tests: PASS")
		quit(0)


func _find_damage_upgrade(definition: WeaponDefinition) -> WeaponUpgradeDefinition:
	for resource in definition.upgrade_options:
		var upgrade := resource as WeaponUpgradeDefinition
		if upgrade != null and upgrade.stat_type == WeaponUpgradeDefinition.StatType.DAMAGE:
			return upgrade
	return null


func _count_projectiles(scene_root: Node) -> int:
	var count := 0
	for child in scene_root.get_children():
		if child.get_script() == PROJECTILE_SCRIPT:
			count += 1
	return count


func _on_ammo_changed(weapon_id: String, current_ammo: int, capacity: int) -> void:
	_ammo_events.append({"id": weapon_id, "current": current_ammo, "capacity": capacity})


func _on_reload_changed(
	weapon_id: String,
	is_reloading: bool,
	remaining_time: float,
	duration: float
) -> void:
	_reload_events.append({
		"id": weapon_id,
		"is_reloading": is_reloading,
		"remaining": remaining_time,
		"duration": duration,
	})


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
