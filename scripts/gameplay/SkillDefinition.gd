extends Resource
class_name SkillDefinition

@export var id := ""
@export var display_name := "Skill"
@export_multiline var description := ""
@export var icon: Texture2D
@export var skill_scene: PackedScene

@export var max_level := 5


func get_display_name() -> String:
	return display_name
