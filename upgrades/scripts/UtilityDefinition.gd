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

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

@export var id := ""
@export var display_name := "Utility"
@export_multiline var description := ""
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
@export var effect_type: EffectType
@export var value := 1.0
# 0 berarti utility dapat dikoleksi tanpa batas stack.
@export_range(0, 100, 1) var max_stack := 1
@export_range(0.0, 1000.0, 0.05) var weight := 1.0
@export var enabled := true
