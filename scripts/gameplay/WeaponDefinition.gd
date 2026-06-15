extends Resource
class_name WeaponDefinition

enum WeaponType {
	PROJECTILE,
	AURA,
	AREA,
	SUMMON,
	BEAM,
	MELEE,
}

@export var id := ""
@export var display_name := "Weapon"
@export_multiline var description := ""
@export var icon: Texture2D

@export var weapon_type: WeaponType = WeaponType.PROJECTILE
@export var weapon_scene: PackedScene

@export var base_damage: float = 10.0
@export var base_cooldown: float = 1.0
@export var base_projectile_count: int = 1
@export var base_projectile_speed: float = 300.0
@export var base_range: float = 300.0

@export var max_level: int = 5
@export var damage_per_level: float = 2.0
@export var cooldown_reduction_per_level: float = 0.03
@export var projectile_count_per_level: int = 0
@export var projectile_speed_per_level: float = 0.0
@export_group("Beam")
@export var beam_duration: float = 1.2
@export var beam_duration_per_level: float = 0.1
@export var beam_tick_interval: float = 0.2
@export var beam_tick_interval_reduction_per_level: float = 0.01
@export var beam_width: float = 5.0


func get_display_name() -> String:
	return display_name
