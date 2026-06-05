extends Resource
class_name SpawnerConfig

# Data balancing spawn wave dan peningkatan tekanan musuh.
@export var spawn_interval := 2.0
@export var spawn_interval_min := 0.8
@export var spawn_interval_decay := 0.08
@export var spawn_count := 1
@export var spawn_count_max := 8
@export var spawn_count_increase_every := 12.0
@export var playable_half_size := Vector2(600, 320)
@export var camera_half_size := Vector2(320, 180)
@export var spawn_margin := 80.0
