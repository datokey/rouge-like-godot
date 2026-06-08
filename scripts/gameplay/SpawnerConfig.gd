extends Resource
class_name SpawnerConfig

# Config ini hanya mengatur area spawn. Scaling difficulty ada di DifficultyManager.
@export var playable_half_size := Vector2(600, 320)
@export var camera_half_size := Vector2(320, 180)
@export var spawn_margin := 80.0
