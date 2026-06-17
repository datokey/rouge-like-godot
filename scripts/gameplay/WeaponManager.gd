extends RefCounted
class_name WeaponManager

const WeaponInstanceScript = preload("res://scripts/gameplay/WeaponInstance.gd")

var max_weapon_slots := 4
var weapons: Array[RefCounted] = []
var weapon_nodes := {}
var owner_node: Node2D
var weapon_holder: Node
var ability_manager


func setup(new_owner_node: Node2D, new_weapon_holder: Node, new_ability_manager) -> void:
	owner_node = new_owner_node
	weapon_holder = new_weapon_holder
	ability_manager = new_ability_manager


func add_weapon(weapon_definition: Resource) -> bool:
	if weapon_definition == null:
		return false

	var weapon_id := str(weapon_definition.get("id"))
	if weapon_id.is_empty():
		return false

	if has_weapon(weapon_id):
		return upgrade_weapon(weapon_id)
	if not can_add_weapon():
		return false

	var weapon_instance := WeaponInstanceScript.new()
	weapon_instance.setup(weapon_definition, owner_node, ability_manager)
	if not _spawn_weapon_node(weapon_instance):
		return false

	weapons.append(weapon_instance)
	return true


func has_weapon(weapon_id: String) -> bool:
	return get_weapon_instance(weapon_id) != null


func upgrade_weapon(weapon_id: String) -> bool:
	var weapon_instance := get_weapon_instance(weapon_id)
	if weapon_instance == null:
		return false

	return weapon_instance.upgrade()


func can_add_weapon() -> bool:
	return weapons.size() < max_weapon_slots


func can_offer_weapon(weapon_definition: Resource) -> bool:
	if weapon_definition == null:
		return false

	var weapon_id := str(weapon_definition.get("id"))
	if weapon_id.is_empty():
		return false

	var weapon_instance := get_weapon_instance(weapon_id)
	if weapon_instance != null:
		return weapon_instance.can_upgrade()

	return can_add_weapon()


func get_weapon_instance(weapon_id: String) -> RefCounted:
	for weapon_instance in weapons:
		if weapon_instance.get_weapon_id() == weapon_id:
			return weapon_instance

	return null


func get_offer_context() -> Dictionary:
	var owned_weapon_ids: Array[String] = []
	var owned_levels := {}
	var owned_max_levels := {}
	var owned_modifier_capabilities := {}
	for weapon_instance in weapons:
		var weapon_id: String = weapon_instance.get_weapon_id()
		owned_weapon_ids.append(weapon_id)
		owned_levels[weapon_id] = weapon_instance.level
		owned_max_levels[weapon_id] = int(weapon_instance.definition.get("max_level"))
		owned_modifier_capabilities[weapon_id] = weapon_instance.definition.get(
			"supported_modifier_keys"
		)

	return {
		"can_add_weapon": can_add_weapon(),
		"owned_weapon_ids": owned_weapon_ids,
		"owned_weapon_levels": owned_levels,
		"owned_weapon_max_levels": owned_max_levels,
		"owned_weapon_modifier_capabilities": owned_modifier_capabilities,
		"max_weapon_slots": max_weapon_slots,
		"used_weapon_slots": weapons.size(),
		"available_weapon_slots": maxi(0, max_weapon_slots - weapons.size()),
	}


func _spawn_weapon_node(weapon_instance: RefCounted) -> bool:
	if weapon_instance.definition == null or weapon_holder == null:
		return false

	var weapon_scene: PackedScene = weapon_instance.definition.get("weapon_scene")
	if weapon_scene == null:
		return false

	var weapon_node := weapon_scene.instantiate()
	if weapon_node == null:
		return false

	weapon_holder.add_child(weapon_node)
	weapon_nodes[weapon_instance.get_weapon_id()] = weapon_node

	if weapon_node.has_method("setup"):
		weapon_node.call("setup", weapon_instance)

	return true
