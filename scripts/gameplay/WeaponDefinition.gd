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
@export var base_range: float = 300.0

@export var max_level: int = 5
@export var damage_per_level: float = 2.0
@export var cooldown_reduction_per_level: float = 0.03


func get_display_name() -> String:
	return display_name
