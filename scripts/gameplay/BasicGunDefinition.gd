extends ProjectileWeaponDefinition
class_name BasicGunDefinition

@export_group("Attack Speed")
@export_range(0.01, 60.0, 0.01) var base_attack_speed := 1.0
@export_range(0.0, 10.0, 0.01) var attack_speed_reduction_per_level := 0.05
@export_range(0.01, 10.0, 0.01) var minimum_attack_speed := 0.01

@export_group("Magazine")
@export_range(1, 999, 1) var base_magazine_capacity := 6
@export_range(0, 100, 1) var magazine_capacity_per_level := 1
@export_range(1, 999, 1) var max_magazine_capacity := 30
@export_range(0.05, 60.0, 0.05) var base_reload_time := 2.0
@export_range(0.0, 10.0, 0.01) var reload_time_reduction_per_level := 0.05
@export_range(0.05, 60.0, 0.05) var minimum_reload_time := 0.5
@export_group("")
