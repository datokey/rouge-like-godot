extends Resource
class_name HitFeedbackConfig

# Knockback terkontrol: force dikonversi ke jarak lalu dibatasi max_knockback_distance.
@export var hit_knockback_force := 1.5
@export var hit_knockback_duration := 0.08
@export var max_knockback_distance := 0.3
@export var knockback_unit_size := 32.0

@export var hit_flash_duration := 0.08
@export var hit_flash_color := Color(1.0, 1.0, 1.0, 1.0)

@export var impact_vfx_scene: PackedScene
@export var impact_vfx_scale := 0.6

# Prototype hit stop lokal di enemy. Nilai 0 menonaktifkan.
@export var hit_stop_duration := 0.02
