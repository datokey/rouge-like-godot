extends Node2D
class_name TrainingPulseSkill

var skill_instance: RefCounted
var _pulse_time := 0.0


func setup(new_skill_instance: RefCounted) -> void:
	skill_instance = new_skill_instance
	_pulse_time = 0.0
	queue_redraw()


func on_skill_upgraded() -> void:
	queue_redraw()


func _physics_process(delta: float) -> void:
	var owner_node := _get_owner_node()
	if owner_node == null:
		return

	global_position = owner_node.global_position
	_pulse_time = fmod(_pulse_time + delta, 1.0)
	queue_redraw()


func _draw() -> void:
	var radius := 24.0 + float(_get_level() - 1) * 5.0 + _pulse_time * 8.0
	var alpha := 0.35 * (1.0 - _pulse_time)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.2, 1.0, 0.65, alpha), 2.0)


func _get_owner_node() -> Node2D:
	if skill_instance == null:
		return null

	return skill_instance.owner_node


func _get_level() -> int:
	if skill_instance == null:
		return 1

	return int(skill_instance.level)
