extends RefCounted
class_name SkillInstance

var definition: Resource
var level := 1
var owner_node: Node2D


func setup(new_definition: Resource, new_owner_node: Node2D, start_level: int = 1) -> void:
	definition = new_definition
	owner_node = new_owner_node
	level = maxi(1, start_level)


func can_upgrade() -> bool:
	if definition == null:
		return false

	return level < int(definition.get("max_level"))


func upgrade() -> bool:
	if not can_upgrade():
		return false

	level += 1
	return true


func get_skill_id() -> String:
	if definition == null:
		return ""

	return str(definition.get("id"))
