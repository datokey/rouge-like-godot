extends SceneTree

const WEAPON_DEFINITION := preload("res://resources/weapons/KoalisiDadakan.tres")

var _failed := false


class TestAbilityManager extends RefCounted:
	var modifiers := {}

	func apply_modifiers(base_value: float, modifier_key: StringName) -> float:
		return base_value * (1.0 + float(modifiers.get(modifier_key, 0.0)))

	func get_flat_modifier(modifier_key: StringName) -> float:
		return float(modifiers.get(modifier_key, 0.0))


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root

	var player := Node2D.new()
	scene_root.add_child(player)
	var weapon_holder := Node2D.new()
	player.add_child(weapon_holder)

	var ability_manager := TestAbilityManager.new()
	var definition := WEAPON_DEFINITION.duplicate(true)
	definition.max_active_minions = 2
	definition.base_cooldown = 1.0
	definition.minion_lifetime = 25.0

	var manager := WeaponManager.new()
	manager.setup(player, weapon_holder, ability_manager)
	_assert(manager.add_weapon(definition), "weapon pertama gagal ditambahkan")
	_assert(manager.add_weapon(definition), "upgrade weapon gagal")
	_assert(weapon_holder.get_child_count() == 1, "upgrade membuat node weapon duplikat")

	var weapon: KoalisiDadakan = weapon_holder.get_child(0)
	weapon.set_physics_process(false)
	weapon._physics_process(0.0)
	weapon._physics_process(1.0)
	weapon._physics_process(10.0)
	_assert(weapon._active_minions.size() == 2, "jumlah summon melewati atau gagal mencapai batas")

	definition.max_active_minions = 3
	weapon._physics_process(0.1)
	_assert(weapon._active_minions.size() == 2, "kenaikan batas melewati cooldown normal")
	weapon._physics_process(0.9)
	_assert(weapon._active_minions.size() == 3, "kenaikan batas tidak membuka slot summon")

	definition.max_active_minions = 1
	weapon._physics_process(10.0)
	_assert(weapon._active_minions.size() == 3, "penurunan batas menghapus summon aktif")

	var removed_minion: Node = weapon._active_minions[0]
	removed_minion.queue_free()
	await process_frame
	definition.max_active_minions = 3
	weapon._physics_process(1.0)
	_assert(weapon._active_minions.size() == 3, "slot tidak kembali setelah summon hilang")

	var instance: WeaponInstance = manager.get_weapon_instance("koalisi_dadakan")
	var snapshot_minion: Simpatisan = weapon._active_minions[0]
	definition.minion_lifetime = 1.0
	_assert(is_equal_approx(snapshot_minion.lifetime, 25.0), "lifetime summon lama bukan snapshot")

	ability_manager.modifiers[&"weapon.damage"] = 1.0
	ability_manager.modifiers[&"weapon.cooldown"] = -0.5
	ability_manager.modifiers[&"weapon.range"] = 0.5
	ability_manager.modifiers[&"weapon.projectile_count"] = 2.0
	_assert(instance.get_summon_damage() == 18, "modifier damage tidak terbaca live")
	_assert(is_equal_approx(instance.get_summon_attack_cooldown(), 0.75), "attack speed tidak live")
	_assert(is_equal_approx(instance.get_attack_range(), 600.0), "range tidak live")
	_assert(instance.get_projectile_count() == 3, "projectile count tidak live")

	var minions_before_cleanup := weapon._active_minions.duplicate()
	weapon.queue_free()
	await process_frame
	for minion in minions_before_cleanup:
		_assert(not is_instance_valid(minion), "summon orphan setelah weapon dihapus")

	var second_holder := Node2D.new()
	player.add_child(second_holder)
	var second_manager := WeaponManager.new()
	second_manager.setup(player, second_holder, ability_manager)
	_assert(second_manager.add_weapon(definition), "weapon cleanup player mati gagal dibuat")
	var second_weapon: KoalisiDadakan = second_holder.get_child(0)
	second_weapon.set_physics_process(false)
	second_weapon._physics_process(0.0)
	var minion_before_death: Node = second_weapon._active_minions[0]
	root.get_node("EventBus").emit_signal("player_died")
	await process_frame
	_assert(not is_instance_valid(minion_before_death), "summon orphan setelah player mati")
	_assert(second_weapon._active_minions.is_empty(), "registry summon tidak bersih setelah player mati")
	second_weapon._physics_process(10.0)
	_assert(second_weapon._active_minions.is_empty(), "weapon summon lagi setelah player mati")

	if _failed:
		quit(1)
	else:
		print("KoalisiDadakan regression tests: PASS")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
