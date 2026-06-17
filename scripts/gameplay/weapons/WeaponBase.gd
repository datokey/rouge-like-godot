extends Node2D
class_name WeaponBase

var weapon_instance: RefCounted


func setup(new_weapon_instance: RefCounted) -> void:
	weapon_instance = new_weapon_instance
	_on_weapon_setup()


func _on_weapon_setup() -> void:
	pass


func get_owner_node() -> Node2D:
	if weapon_instance == null:
		return null

	return weapon_instance.owner_node


func get_damage() -> int:
	if weapon_instance == null:
		return 0

	return weapon_instance.get_damage()


func get_cooldown() -> float:
	if weapon_instance == null:
		return 1.0

	return weapon_instance.get_cooldown()


func get_range() -> float:
	if weapon_instance == null:
		return 0.0

	return weapon_instance.get_attack_range()


func get_nearest_enemy() -> Node2D:
	var owner_node := get_owner_node()
	if owner_node == null:
		return null
	if not owner_node.has_method("get_nearest_enemy_in_range"):
		return null

	return owner_node.call("get_nearest_enemy_in_range", get_range()) as Node2D
