extends WeaponDefinition
class_name BeamWeaponDefinition

@export_group("Beam")
@export var beam_duration: float = 1.2
@export var beam_duration_per_level: float = 0.0
@export var beam_tick_interval: float = 0.2
@export var beam_tick_interval_reduction_per_level: float = 0.0
@export var beam_width: float = 5.0
# 0 berarti menembus semua target sampai batas panjang beam.
@export_range(0, 100, 1) var pierce_count: int = 0
@export_range(1, 1024, 1) var max_collision_results: int = 256
@export var base_projectile_count: int = 1
@export var projectile_count_per_level: int = 0
@export_range(1, 100, 1) var max_beam_count := 6
@export_range(1.0, 200.0, 0.5) var max_beam_width := 40.0
@export_range(0.0, 90.0, 0.5) var spread_angle_degrees := 8.0
@export_group("Beam Visual")
@export var beam_start_color := Color(0.2, 0.65, 1.0, 0.9)
@export var beam_end_color := Color(1.0, 0.15, 0.1, 0.9)
# 0 memakai max_level weapon.
@export_range(0, 100, 1) var beam_color_max_level := 0
