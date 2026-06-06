extends Resource
class_name AbilityDefinition

@export var id := ""
@export var display_name := "Ability"
@export_multiline var description := ""
@export_enum(
	"Damage Percent",
	"Attack Speed Percent",
	"Max HP Flat",
	"Projectile Count Flat",
	"Move Speed Percent"
) var modifier_type: int = AbilityModifierConfig.ModifierType.DAMAGE_PERCENT
@export var base_value := 0.0


func get_final_value(modifier_config: AbilityModifierConfig, rarity: int) -> float:
	if modifier_config == null:
		return base_value

	return modifier_config.calculate_value(base_value, rarity)


func get_value_text(value: float) -> String:
	match modifier_type:
		AbilityModifierConfig.ModifierType.DAMAGE_PERCENT:
			return "+%d%%" % roundi(value * 100.0)
		AbilityModifierConfig.ModifierType.ATTACK_SPEED_PERCENT:
			return "+%d%%" % roundi(value * 100.0)
		AbilityModifierConfig.ModifierType.MAX_HP_FLAT:
			return "+%d" % roundi(value)
		AbilityModifierConfig.ModifierType.PROJECTILE_COUNT_FLAT:
			return "+%d" % roundi(value)
		AbilityModifierConfig.ModifierType.MOVE_SPEED_PERCENT:
			return "+%d%%" % roundi(value * 100.0)
		_:
			return "+0"


func get_offer_text(modifier_config: AbilityModifierConfig, rarity: int) -> String:
	var rarity_name := "Common"
	var rarity_multiplier := 1.0
	if modifier_config != null:
		rarity_name = modifier_config.get_rarity_name(rarity)
		rarity_multiplier = modifier_config.get_rarity_multiplier(rarity)

	var final_value := get_final_value(modifier_config, rarity)
	return "%s\n%s %s\nBase %s x %.2f" % [
		rarity_name,
		display_name,
		get_value_text(final_value),
		get_value_text(base_value),
		rarity_multiplier,
	]


func apply_to_player(player: Node, modifier_config: AbilityModifierConfig, rarity: int) -> float:
	if player == null or not player.has_method("apply_ability_modifier"):
		return 0.0

	var applied_value = player.call("apply_ability_modifier", modifier_type, base_value, rarity)
	if typeof(applied_value) == TYPE_INT or typeof(applied_value) == TYPE_FLOAT:
		return float(applied_value)

	return 0.0
