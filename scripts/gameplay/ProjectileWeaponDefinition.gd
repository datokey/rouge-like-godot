extends WeaponDefinition
class_name ProjectileWeaponDefinition

@export_group("Projectile")
@export var base_projectile_count: int = 1
@export var projectile_count_per_level: int = 0
@export var base_projectile_speed: float = 300.0
@export var projectile_speed_per_level: float = 0.0
@export var spread_angle_degrees := 8.0
