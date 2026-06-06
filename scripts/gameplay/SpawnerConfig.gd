extends Resource
class_name SpawnerConfig

# Data balancing spawn wave dan peningkatan tekanan musuh.
@export var initial_spawn_interval := 3.0
@export var spawn_interval_decrease_every := 30.0
@export var spawn_interval_decrease_amount := 0.25
@export var minimum_spawn_interval := 0.75
@export var initial_spawn_count := 1
@export var spawn_count_increase_every := 60.0
@export var spawn_count_increase_amount := 1
@export var maximum_spawn_count := 5
@export var maximum_alive_enemies := 50
@export var enemy_damage_increase_every := 20.0
@export var enemy_damage_increase_amount := 1
@export var enemy_damage_max_bonus := 20
@export var playable_half_size := Vector2(600, 320)
@export var camera_half_size := Vector2(320, 180)
@export var spawn_margin := 80.0
