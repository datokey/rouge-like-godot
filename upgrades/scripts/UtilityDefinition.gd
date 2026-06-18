extends Resource
class_name UtilityDefinition

enum EffectType {
	REROLL,
	PICKUP_RADIUS,
	REVIVE,
	EXTRA_OFFER,
	EXTRA_DASH,
	ELITE_KILL_HEAL,
	DAMAGE_TO_SHIELD,
	PERMANENT_MAX_HP,
}

@export var id := ""
@export var display_name := "Utility"
@export_multiline var description := ""
@export var effect_type: EffectType
@export var value := 1.0
# 0 berarti tidak memiliki batas level, cocok untuk fallback yang selalu aman.
@export_range(0, 100, 1) var max_level := 1
@export_range(0.0, 1000.0, 0.05) var weight := 1.0
@export var enabled := true
