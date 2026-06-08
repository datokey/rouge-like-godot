extends Resource
class_name DifficultyPhaseConfig

# Satu phase difficulty. Phase aktif saat progress run sudah melewati start_progress.
@export_range(0.0, 1.0, 0.01) var start_progress := 0.0
@export var hp_multiplier := 1.0
@export var damage_multiplier := 1.0
@export var move_speed_multiplier := 1.0
@export var spawn_interval := 3.0
@export var spawn_count := 1
@export var maximum_alive_enemies := 25
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_scene_weights: Array[int] = []


func has_enemy_scene() -> bool:
	for scene in enemy_scenes:
		if scene != null:
			return true

	return false


func get_enemy_scene_weight(index: int) -> int:
	if index < enemy_scene_weights.size():
		return maxi(0, enemy_scene_weights[index])

	return 1
