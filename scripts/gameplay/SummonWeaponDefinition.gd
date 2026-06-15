extends WeaponDefinition
class_name SummonWeaponDefinition

# Field khusus weapon tipe SUMMON.
# Semua value di sini bisa diubah dari Inspector/resource tanpa edit script.

@export var minion_name := "Minion"
@export var minion_scene: PackedScene
@export var minion_projectile_scene: PackedScene

@export var minion_damage_multiplier := 0.7
@export var max_active_minions := 4
@export var summon_interval := 10.0
@export var minion_lifetime := 25.0
@export var minion_attack_cooldown := 1.5
@export var minion_attack_range := 400.0
@export var minion_projectile_speed := 400.0
@export var minion_orbit_radius := 60.0
