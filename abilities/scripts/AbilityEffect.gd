extends Resource
class_name AbilityEffect

enum Target {
	PLAYER,
	WEAPON,
}

enum EffectType {
	DAMAGE_PERCENT,
	ATTACK_SPEED_PERCENT,
	MAX_HP_FLAT,
	PROJECTILE_COUNT_FLAT,
	MOVE_SPEED_PERCENT,
}

enum StackMode {
	ADD,
}

@export_enum("Player", "Weapon") var target: int = Target.PLAYER
@export_enum(
	"Damage Percent",
	"Attack Speed Percent",
	"Max HP Flat",
	"Projectile Count Flat",
	"Move Speed Percent"
) var effect_type: int = EffectType.DAMAGE_PERCENT
@export var value := 0.0
@export_enum("Add") var stack_mode: int = StackMode.ADD


func get_modifier_type() -> int:
	match effect_type:
		EffectType.DAMAGE_PERCENT:
			return AbilityModifierConfig.ModifierType.DAMAGE_PERCENT
		EffectType.ATTACK_SPEED_PERCENT:
			return AbilityModifierConfig.ModifierType.ATTACK_SPEED_PERCENT
		EffectType.MAX_HP_FLAT:
			return AbilityModifierConfig.ModifierType.MAX_HP_FLAT
		EffectType.PROJECTILE_COUNT_FLAT:
			return AbilityModifierConfig.ModifierType.PROJECTILE_COUNT_FLAT
		EffectType.MOVE_SPEED_PERCENT:
			return AbilityModifierConfig.ModifierType.MOVE_SPEED_PERCENT
		_:
			return AbilityModifierConfig.ModifierType.DAMAGE_PERCENT


func get_base_value() -> float:
	if is_percent_effect():
		return value * 0.01

	return value


func get_data_value() -> float:
	return value


func get_final_value(modifier_config: AbilityModifierConfig, rarity: int) -> float:
	var base_value := get_base_value()
	if modifier_config == null:
		return base_value

	return modifier_config.calculate_value(base_value, rarity)


func is_flat_modifier() -> bool:
	return (
		effect_type == EffectType.MAX_HP_FLAT
		or effect_type == EffectType.PROJECTILE_COUNT_FLAT
	)


func is_percent_effect() -> bool:
	return (
		effect_type == EffectType.DAMAGE_PERCENT
		or effect_type == EffectType.ATTACK_SPEED_PERCENT
		or effect_type == EffectType.MOVE_SPEED_PERCENT
	)


func get_value_text(display_value: float) -> String:
	match effect_type:
		EffectType.DAMAGE_PERCENT:
			return "+%d%%" % roundi(display_value * 100.0)
		EffectType.ATTACK_SPEED_PERCENT:
			return "+%d%%" % roundi(display_value * 100.0)
		EffectType.MAX_HP_FLAT:
			return "+%d" % roundi(display_value)
		EffectType.PROJECTILE_COUNT_FLAT:
			return "+%d" % roundi(display_value)
		EffectType.MOVE_SPEED_PERCENT:
			return "+%d%%" % roundi(display_value * 100.0)
		_:
			return "+0"


func get_effect_label(final_value: float) -> String:
	return "%s %s" % [get_effect_display_name(), get_value_text(final_value)]


func get_target_name() -> String:
	match target:
		Target.WEAPON:
			return "Weapon"
		_:
			return "Player"


func get_effect_display_name() -> String:
	match effect_type:
		EffectType.DAMAGE_PERCENT:
			return "Damage"
		EffectType.ATTACK_SPEED_PERCENT:
			return "Attack Speed"
		EffectType.MAX_HP_FLAT:
			return "Max HP"
		EffectType.PROJECTILE_COUNT_FLAT:
			return "Projectile Count"
		EffectType.MOVE_SPEED_PERCENT:
			return "Move Speed"
		_:
			return "Effect"
