extends RefCounted
class_name SkillManager

const SkillInstanceScript = preload("res://scripts/gameplay/SkillInstance.gd")

var max_skill_slots := 0
var skills: Array[RefCounted] = []
var skill_nodes := {}
var owner_node: Node2D
var skill_holder: Node


func setup(new_owner_node: Node2D, new_skill_holder: Node) -> void:
	owner_node = new_owner_node
	skill_holder = new_skill_holder


func add_skill(skill_definition: Resource) -> bool:
	if skill_definition == null:
		return false

	var skill_id := str(skill_definition.get("id"))
	if skill_id.is_empty():
		return false

	if has_skill(skill_id):
		return upgrade_skill(skill_id)
	if not can_add_skill():
		return false

	var skill_instance := SkillInstanceScript.new()
	skill_instance.setup(skill_definition, owner_node)
	if not _spawn_skill_node(skill_instance):
		return false

	skills.append(skill_instance)
	return true


func remove_skill(skill_id: String) -> bool:
	var skill_instance := get_skill_instance(skill_id)
	if skill_instance == null:
		return false

	skills.erase(skill_instance)
	var skill_node: Node = skill_nodes.get(skill_id)
	if skill_node != null and is_instance_valid(skill_node):
		skill_node.queue_free()
	skill_nodes.erase(skill_id)
	return true


func has_skill(skill_id: String) -> bool:
	return get_skill_instance(skill_id) != null


func upgrade_skill(skill_id: String) -> bool:
	var skill_instance := get_skill_instance(skill_id)
	if skill_instance == null:
		return false

	var upgraded: bool = skill_instance.upgrade()
	if upgraded:
		var skill_node: Node = skill_nodes.get(skill_id)
		if skill_node != null and is_instance_valid(skill_node) and skill_node.has_method("on_skill_upgraded"):
			skill_node.call("on_skill_upgraded")

	return upgraded


func can_add_skill() -> bool:
	return max_skill_slots > 0 and skills.size() < max_skill_slots


func can_offer_skill(skill_definition: Resource) -> bool:
	if skill_definition == null:
		return false

	var skill_id := str(skill_definition.get("id"))
	if skill_id.is_empty():
		return false

	var skill_instance := get_skill_instance(skill_id)
	if skill_instance != null:
		return skill_instance.can_upgrade()

	return can_add_skill()


func get_skill_instance(skill_id: String) -> RefCounted:
	for skill_instance in skills:
		if skill_instance.get_skill_id() == skill_id:
			return skill_instance

	return null


func get_offer_context() -> Dictionary:
	var owned_skill_ids: Array[String] = []
	var owned_levels := {}
	var owned_max_levels := {}
	for skill_instance in skills:
		var skill_id: String = skill_instance.get_skill_id()
		owned_skill_ids.append(skill_id)
		owned_levels[skill_id] = skill_instance.level
		owned_max_levels[skill_id] = int(skill_instance.definition.get("max_level"))

	return {
		"skill_manager_active": true,
		"can_add_skill": can_add_skill(),
		"owned_skill_ids": owned_skill_ids,
		"owned_skill_levels": owned_levels,
		"owned_skill_max_levels": owned_max_levels,
		"max_skill_slots": max_skill_slots,
		"used_skill_slots": skills.size(),
		"available_skill_slots": maxi(0, max_skill_slots - skills.size()),
	}


func _spawn_skill_node(skill_instance: RefCounted) -> bool:
	if skill_instance.definition == null or skill_holder == null:
		return false

	var skill_scene: PackedScene = skill_instance.definition.get("skill_scene")
	if skill_scene == null:
		return false

	var skill_node := skill_scene.instantiate()
	if skill_node == null:
		return false

	skill_holder.add_child(skill_node)
	skill_nodes[skill_instance.get_skill_id()] = skill_node

	if skill_node.has_method("setup"):
		skill_node.call("setup", skill_instance)

	return true
