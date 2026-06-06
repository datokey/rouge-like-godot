extends Resource
class_name EnemyConfig

# Data balancing enemy. Scene enemy membaca resource ini saat spawn.
@export var max_hp := 30
@export var move_speed := 90.0
@export var contact_damage := 1
@export var contact_cooldown := 0.7
@export var xp_drop_values: Array[int] = [1, 2, 3, 4, 5]
@export var xp_drop_weights: Array[int] = [60, 23, 12, 4, 1]
@export var hp_drop_values: Array[int] = [5, 10, 15, 20, 25]
@export var hp_drop_weights: Array[int] = [60, 23, 12, 4, 1]
@export var health_drop_chance := 0.12
@export var magnet_drop_chance := 0.03
