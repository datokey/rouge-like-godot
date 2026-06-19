extends Node2D
class_name WeaponBase

var weapon_instance: WeaponInstance
var is_weapon_active := true


func setup(new_weapon_instance: WeaponInstance) -> void:
	weapon_instance = new_weapon_instance
	is_weapon_active = true
	_on_weapon_setup()


func deactivate() -> void:
	if not is_weapon_active:
		return
	is_weapon_active = false
	set_process(false)
	set_physics_process(false)
	_disable_active_nodes(self)


func _disable_active_nodes(node: Node) -> void:
	for child in node.get_children():
		if child is RayCast2D:
			child.enabled = false
		if child is Area2D:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)
		if child is CanvasItem:
			child.hide()
		_disable_active_nodes(child)


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


func get_damage_result() -> Dictionary:
	if weapon_instance == null:
		return {"amount": 0, "is_critical": false}

	return weapon_instance.get_damage_result()


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
