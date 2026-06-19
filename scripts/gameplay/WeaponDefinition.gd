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
@export_range(0.0, 1000.0, 0.05) var reward_weight := 1.0
@export var compatibility_tags: Array[StringName] = []
@export var upgrade_options: Array[Resource] = []
@export var supported_modifier_keys: Array[StringName] = [
	&"weapon.damage",
	&"weapon.cooldown",
	&"weapon.range",
]

@export var base_damage: float = 10.0
@export var base_cooldown: float = 1.0
@export var base_range: float = 300.0

@export_range(1, 99, 1) var max_level: int = 99
@export_range(0.01, 10.0, 0.01) var minimum_fire_interval := 0.05
@export_range(0.0, 5000.0, 1.0) var max_attack_range := 1200.0
@export_range(0.0, 10.0, 0.01) var max_pierce_percent := 1.0
@export var damage_per_level: float = 0.0
@export var cooldown_reduction_per_level: float = 0.0


func get_display_name() -> String:
	return display_name


func has_compatibility_tag(tag: StringName) -> bool:
	return compatibility_tags.has(tag)
