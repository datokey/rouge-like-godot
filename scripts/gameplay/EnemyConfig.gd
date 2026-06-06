extends Resource
class_name EnemyConfig

# Data balancing enemy. Scene enemy membaca resource ini saat spawn.
@export var max_hp := 30
@export var move_speed := 90.0
@export var contact_damage := 1
@export var contact_cooldown := 0.7
@export var detour_path_enabled := true
@export var detour_obstacle_collision_mask := 1
@export var detour_refresh_interval := 0.2
@export var detour_waypoint_margin := 36.0
@export var detour_waypoint_reached_distance := 20.0
@export var obstacle_avoidance_enabled := true
@export var obstacle_avoidance_duration := 0.35
@export var obstacle_avoidance_weight := 0.9
@export var obstacle_stuck_time := 0.18
@export var obstacle_stuck_min_distance := 0.2
@export var xp_drop_values: Array[int] = [1, 2, 3, 4, 5]
@export var xp_drop_weights: Array[int] = [60, 23, 12, 4, 1]
@export var hp_drop_values: Array[int] = [5, 10, 15, 20, 25]
@export var hp_drop_weights: Array[int] = [60, 23, 12, 4, 1]
@export var health_drop_chance := 0.12
@export var magnet_drop_chance := 0.03
