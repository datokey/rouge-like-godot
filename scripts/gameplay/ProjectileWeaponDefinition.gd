extends WeaponDefinition
class_name ProjectileWeaponDefinition

@export_group("Projectile")
@export var base_projectile_count: int = 1
@export var projectile_count_per_level: int = 0
@export var base_projectile_speed: float = 300.0
@export var projectile_speed_per_level: float = 0.0
@export_group("Projectile Size")
@export_range(0.01, 10.0, 0.01) var base_projectile_size := 1.0
@export_range(0.0, 5.0, 0.01) var projectile_size_per_level := 0.0
@export_range(0.01, 10.0, 0.01) var min_projectile_size := 0.1
@export_range(0.01, 20.0, 0.01) var max_projectile_size := 10.0
@export_group("")
@export var spread_angle_degrees := 8.0
