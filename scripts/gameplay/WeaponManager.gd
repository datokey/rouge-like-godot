extends RefCounted
class_name WeaponManager

var max_weapon_slots := 4
var weapons: Array[WeaponInstance] = []
var weapon_nodes: Dictionary[String, WeaponBase] = {}
var owner_node: Node2D
var weapon_holder: Node
var modifier_manager
var is_active := true


func setup(new_owner_node: Node2D, new_weapon_holder: Node, new_modifier_manager) -> void:
	owner_node = new_owner_node
	weapon_holder = new_weapon_holder
	modifier_manager = new_modifier_manager
	is_active = true
	var scene_tree := Engine.get_main_loop() as SceneTree
	var event_bus := scene_tree.root.get_node_or_null("EventBus") if scene_tree != null else null
	if event_bus != null and not event_bus.player_died.is_connected(shutdown):
		event_bus.player_died.connect(shutdown)


func shutdown() -> void:
	if not is_active:
		return
	is_active = false
	for weapon_instance in weapons:
		weapon_instance.deactivate()
	for weapon_node in weapon_nodes.values():
		if is_instance_valid(weapon_node):
			weapon_node.deactivate()


func add_weapon(weapon_definition: Resource) -> bool:
	if not is_active or weapon_definition == null:
		return false

	var weapon_id := str(weapon_definition.get("id"))
	if weapon_id.is_empty():
		return false

	if has_weapon(weapon_id):
		return upgrade_weapon(weapon_id)
	if not can_add_weapon():
		return false

	var weapon_instance := WeaponInstance.new()
	weapon_instance.setup(weapon_definition, owner_node, modifier_manager)
	if not _spawn_weapon_node(weapon_instance):
		return false

	weapons.append(weapon_instance)
	return true


func has_weapon(weapon_id: String) -> bool:
	return get_weapon_instance(weapon_id) != null


func upgrade_weapon(weapon_id: String) -> bool:
	if not is_active:
		return false
	var weapon_instance := get_weapon_instance(weapon_id)
	if weapon_instance == null:
		return false

	return weapon_instance.upgrade()


func apply_stat_upgrade(
	weapon_id: String,
	upgrade: WeaponUpgradeDefinition,
	upgrade_value: float
) -> bool:
	if not is_active:
		return false
	var weapon_instance := get_weapon_instance(weapon_id)
	if weapon_instance == null:
		return false
	return weapon_instance.apply_stat_upgrade(upgrade, upgrade_value)


func can_add_weapon() -> bool:
	return is_active and weapons.size() < max_weapon_slots


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


func get_weapon_instance(weapon_id: String) -> WeaponInstance:
	for weapon_instance in weapons:
		if weapon_instance.get_weapon_id() == weapon_id:
			return weapon_instance

	return null


func get_offer_context() -> Dictionary:
	var owned_weapon_ids: Array[String] = []
	var owned_levels := {}
	var owned_max_levels := {}
	var owned_modifier_capabilities := {}
	var owned_weapon_definitions := {}
	var weapon_upgrade_stacks := {}
	var weapon_upgrade_availability := {}
	var owned_compatibility_tags: Array[StringName] = []
	for weapon_instance in weapons:
		var weapon_id: String = weapon_instance.get_weapon_id()
		owned_weapon_ids.append(weapon_id)
		owned_levels[weapon_id] = weapon_instance.level
		owned_max_levels[weapon_id] = int(weapon_instance.definition.get("max_level"))
		owned_modifier_capabilities[weapon_id] = weapon_instance.definition.get(
			"supported_modifier_keys"
		)
		owned_weapon_definitions[weapon_id] = weapon_instance.definition
		weapon_upgrade_stacks[weapon_id] = weapon_instance.get_upgrade_stacks()
		var upgrade_availability := {}
		for upgrade_resource in weapon_instance.definition.get("upgrade_options"):
			var upgrade := upgrade_resource as WeaponUpgradeDefinition
			if upgrade != null:
				upgrade_availability[upgrade.id] = weapon_instance.can_apply_stat_upgrade(upgrade)
		weapon_upgrade_availability[weapon_id] = upgrade_availability
		var weapon_tags: Array = weapon_instance.definition.get("compatibility_tags")
		for tag in weapon_tags:
			if not owned_compatibility_tags.has(tag):
				owned_compatibility_tags.append(tag)

	return {
		"can_add_weapon": can_add_weapon(),
		"owned_weapon_ids": owned_weapon_ids,
		"owned_weapon_levels": owned_levels,
		"owned_weapon_max_levels": owned_max_levels,
		"owned_weapon_modifier_capabilities": owned_modifier_capabilities,
		"owned_weapon_definitions": owned_weapon_definitions,
		"weapon_upgrade_stacks": weapon_upgrade_stacks,
		"weapon_upgrade_availability": weapon_upgrade_availability,
		"owned_compatibility_tags": owned_compatibility_tags,
		"max_weapon_slots": max_weapon_slots,
		"used_weapon_slots": weapons.size(),
		"available_weapon_slots": maxi(0, max_weapon_slots - weapons.size()),
	}


func _spawn_weapon_node(weapon_instance: WeaponInstance) -> bool:
	if weapon_instance.definition == null or weapon_holder == null:
		return false

	var weapon_scene: PackedScene = weapon_instance.definition.get("weapon_scene")
	if weapon_scene == null:
		return false

	var instantiated_node := weapon_scene.instantiate()
	var weapon_node := instantiated_node as WeaponBase
	if weapon_node == null:
		instantiated_node.free()
		return false

	weapon_holder.add_child(weapon_node)
	weapon_nodes[weapon_instance.get_weapon_id()] = weapon_node
	weapon_node.setup(weapon_instance)

	return true
