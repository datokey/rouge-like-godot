extends ModifierDefinition
class_name TalismanDefinition

@export_range(1, 100, 1) var max_level := 5
@export var compatibility_tags: Array[StringName] = []


func is_compatible(owned_tags: Array) -> bool:
	if compatibility_tags.is_empty():
		return true

	for required_tag in compatibility_tags:
		if owned_tags.has(required_tag):
			return true

	return false

