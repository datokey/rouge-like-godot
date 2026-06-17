extends WeaponDefinition
class_name BeamWeaponDefinition

@export_group("Beam")
@export var beam_duration: float = 1.2
@export var beam_duration_per_level: float = 0.1
@export var beam_tick_interval: float = 0.2
@export var beam_tick_interval_reduction_per_level: float = 0.01
@export var beam_width: float = 5.0
@export var pierce_count: int = 1
