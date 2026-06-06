extends Resource
class_name EnemyConfig

# Data balancing enemy. Scene enemy membaca resource ini saat spawn.
@export var max_hp := 3
@export var move_speed := 90.0
@export var contact_damage := 1
@export var contact_cooldown := 0.7
@export var xp_drop := 1
@export var health_drop_chance := 0.35
