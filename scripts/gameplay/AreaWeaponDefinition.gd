extends WeaponDefinition
class_name AreaWeaponDefinition

@export_group("Area")
@export var area_scene: PackedScene
@export var area_radius := 64.0
@export var area_duration := 1.0
@export var area_tick_interval := 0.25
@export var spawn_at_enemy := true
