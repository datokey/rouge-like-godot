extends Resource
class_name DifficultyManager

# Resource pusat untuk scaling difficulty berbasis progress waktu run.
@export var spawn_interval_min := 0.75
@export var spawn_interval_max := 3.0
@export var spawn_count_min := 1
@export var spawn_count_max := 5
@export var phases: Array[Resource] = []


func get_progress(elapsed_time: float, target_time: float) -> float:
	if target_time <= 0.0:
		return 0.0

	return clampf(elapsed_time / target_time, 0.0, 1.0)


func get_hp_multiplier(progress: float) -> float:
	return maxf(0.0, _sample_float(progress, "hp_multiplier", 1.0))


func get_damage_multiplier(progress: float) -> float:
	return maxf(0.0, _sample_float(progress, "damage_multiplier", 1.0))


func get_move_speed_multiplier(progress: float) -> float:
	return maxf(0.0, _sample_float(progress, "move_speed_multiplier", 1.0))


func get_spawn_interval(progress: float) -> float:
	var sampled_interval := _sample_float(progress, "spawn_interval", spawn_interval_max)
	return clampf(sampled_interval, spawn_interval_min, spawn_interval_max)


func get_spawn_count(progress: float) -> int:
	var sampled_count := roundi(_sample_float(progress, "spawn_count", float(spawn_count_min)))
	return clampi(sampled_count, spawn_count_min, spawn_count_max)


func get_maximum_alive_enemies(progress: float) -> int:
	var phase := get_current_phase(progress)
	if phase == null:
		return 0

	return maxi(0, roundi(_get_phase_float(phase, "maximum_alive_enemies", 0.0)))


func has_enemy_scene(progress: float) -> bool:
	var phase := get_current_phase(progress)
	if phase == null:
		return false

	var enemy_scenes: Array = _get_phase_array(phase, "enemy_scenes")
	for scene in enemy_scenes:
		if scene is PackedScene:
			return true

	return false


func pick_enemy_scene(progress: float) -> PackedScene:
	var phase := get_current_phase(progress)
	if phase == null:
		return null

	var enemy_scenes: Array = _get_phase_array(phase, "enemy_scenes")
	var total_weight := 0
	for index in range(enemy_scenes.size()):
		if not enemy_scenes[index] is PackedScene:
			continue
		total_weight += _get_enemy_scene_weight(phase, index)

	if total_weight <= 0:
		return null

	var roll := Rng.range_i(1, total_weight)
	var accumulated_weight := 0
	for index in range(enemy_scenes.size()):
		var scene := enemy_scenes[index] as PackedScene
		if scene == null:
			continue

		accumulated_weight += _get_enemy_scene_weight(phase, index)
		if roll <= accumulated_weight:
			return scene

	return null


func get_phase_count() -> int:
	return _get_valid_phases().size()


func get_current_phase(progress: float) -> Resource:
	var current_phase: Resource
	var current_start := -INF

	for phase in _get_valid_phases():
		var phase_start := _get_phase_float(phase, "start_progress", 0.0)
		if phase_start <= progress and phase_start >= current_start:
			current_phase = phase
			current_start = phase_start

	if current_phase != null:
		return current_phase

	return _get_first_phase()


func _sample_float(progress: float, property_name: String, fallback: float) -> float:
	var current_phase := get_current_phase(progress)
	if current_phase == null:
		return fallback

	var current_value := _get_phase_float(current_phase, property_name, fallback)
	var next_phase := _get_next_phase(current_phase)
	if next_phase == null:
		return current_value

	var current_start := _get_phase_float(current_phase, "start_progress", 0.0)
	var next_start := _get_phase_float(next_phase, "start_progress", current_start)
	var phase_span := next_start - current_start
	if phase_span <= 0.0:
		return current_value

	var blend := clampf((progress - current_start) / phase_span, 0.0, 1.0)
	var next_value := _get_phase_float(next_phase, property_name, current_value)
	return lerpf(current_value, next_value, blend)


func _get_phase_float(phase: Resource, property_name: String, fallback: float) -> float:
	var value: Variant = phase.get(property_name)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)

	return fallback


func _get_phase_array(phase: Resource, property_name: String) -> Array:
	var value: Variant = phase.get(property_name)
	if typeof(value) == TYPE_ARRAY:
		return value

	return []


func _get_enemy_scene_weight(phase: Resource, index: int) -> int:
	var weights := _get_phase_array(phase, "enemy_scene_weights")
	if index < weights.size() and typeof(weights[index]) == TYPE_INT:
		return maxi(0, weights[index])

	return 1


func _get_next_phase(current_phase: Resource) -> Resource:
	var next_phase: Resource
	var next_start := INF
	var current_start := _get_phase_float(current_phase, "start_progress", 0.0)

	for phase in _get_valid_phases():
		var phase_start := _get_phase_float(phase, "start_progress", 0.0)
		if phase_start <= current_start:
			continue
		if phase_start < next_start:
			next_phase = phase
			next_start = phase_start

	return next_phase


func _get_first_phase() -> Resource:
	var first_phase: Resource
	var first_start := INF

	for phase in _get_valid_phases():
		var phase_start := _get_phase_float(phase, "start_progress", 0.0)
		if phase_start < first_start:
			first_phase = phase
			first_start = phase_start

	return first_phase


func _get_valid_phases() -> Array[Resource]:
	var valid_phases: Array[Resource] = []
	for phase in phases:
		if phase is Resource:
			valid_phases.append(phase as Resource)

	return valid_phases
