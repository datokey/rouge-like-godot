extends Resource
class_name AbilityDefinition

const EFFECT_DAMAGE_PERCENT := "damage_percent"
const EFFECT_ATTACK_SPEED_PERCENT := "attack_speed_percent"
const EFFECT_MAX_HP_FLAT := "max_hp_flat"
const EFFECT_PROJECTILE_COUNT_FLAT := "projectile_count_flat"
const EFFECT_MOVE_SPEED_PERCENT := "move_speed_percent"

@export var id := ""
@export var name := "Ability"
@export_enum("Safe", "Offense", "Defense", "Mobility") var category := "Safe"
@export var effect_type := ""
@export var value := -1.0
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity := "Common"
@export var stackable := true

# Field di bawah ini dipertahankan sebagai fallback agar resource lama tetap bisa dibaca.
@export var display_name := "Ability"
@export_multiline var description := ""
@export_enum(
	"Damage Percent",
	"Attack Speed Percent",
	"Max HP Flat",
	"Projectile Count Flat",
	"Move Speed Percent"
) var modifier_type: int = AbilityModifierConfig.ModifierType.DAMAGE_PERCENT
@export var base_value := -1.0


func get_upgrade_data() -> Dictionary:
	return {
		"id": id,
		"name": get_display_name(),
		"category": category,
		"effect_type": get_effect_type(),
		"value": get_data_value(),
		"rarity": rarity,
		"stackable": stackable,
	}


func get_display_name() -> String:
	if name.strip_edges() != "":
		return name

	return display_name


func get_effect_type() -> String:
	if effect_type.strip_edges() != "":
		return effect_type

	match modifier_type:
		AbilityModifierConfig.ModifierType.DAMAGE_PERCENT:
			return EFFECT_DAMAGE_PERCENT
		AbilityModifierConfig.ModifierType.ATTACK_SPEED_PERCENT:
			return EFFECT_ATTACK_SPEED_PERCENT
		AbilityModifierConfig.ModifierType.MAX_HP_FLAT:
			return EFFECT_MAX_HP_FLAT
		AbilityModifierConfig.ModifierType.PROJECTILE_COUNT_FLAT:
			return EFFECT_PROJECTILE_COUNT_FLAT
		AbilityModifierConfig.ModifierType.MOVE_SPEED_PERCENT:
			return EFFECT_MOVE_SPEED_PERCENT
		_:
			return EFFECT_DAMAGE_PERCENT


func get_modifier_type() -> int:
	match get_effect_type():
		EFFECT_DAMAGE_PERCENT:
			return AbilityModifierConfig.ModifierType.DAMAGE_PERCENT
		EFFECT_ATTACK_SPEED_PERCENT:
			return AbilityModifierConfig.ModifierType.ATTACK_SPEED_PERCENT
		EFFECT_MAX_HP_FLAT:
			return AbilityModifierConfig.ModifierType.MAX_HP_FLAT
		EFFECT_PROJECTILE_COUNT_FLAT:
			return AbilityModifierConfig.ModifierType.PROJECTILE_COUNT_FLAT
		EFFECT_MOVE_SPEED_PERCENT:
			return AbilityModifierConfig.ModifierType.MOVE_SPEED_PERCENT
		_:
			return modifier_type


func get_base_value() -> float:
	if value >= 0.0 and _is_percent_effect():
		return value * 0.01
	if value >= 0.0:
		return value
	if base_value >= 0.0:
		return base_value

	return 0.0


func get_data_value() -> float:
	if value >= 0.0:
		return value
	if base_value >= 0.0 and _is_percent_effect():
		return base_value * 100.0
	if base_value >= 0.0:
		return base_value

	return 0.0


func _is_percent_effect() -> bool:
	var resolved_effect_type := get_effect_type()
	return (
		resolved_effect_type == EFFECT_DAMAGE_PERCENT
		or resolved_effect_type == EFFECT_ATTACK_SPEED_PERCENT
		or resolved_effect_type == EFFECT_MOVE_SPEED_PERCENT
	)


func get_rarity_value() -> int:
	match rarity:
		"Uncommon":
			return AbilityModifierConfig.Rarity.UNCOMMON
		"Rare":
			return AbilityModifierConfig.Rarity.RARE
		"Epic":
			return AbilityModifierConfig.Rarity.EPIC
		"Legendary":
			return AbilityModifierConfig.Rarity.LEGENDARY
		_:
			return AbilityModifierConfig.Rarity.COMMON


func get_final_value(modifier_config: AbilityModifierConfig, rarity_override: int = -1) -> float:
	var rarity_value := get_rarity_value() if rarity_override < 0 else rarity_override
	var base := get_base_value()
	if modifier_config == null:
		return base

	return modifier_config.calculate_value(base, rarity_value)


func get_value_text(value: float) -> String:
	match get_modifier_type():
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


func get_offer_text(modifier_config: AbilityModifierConfig, rarity_override: int = -1) -> String:
	var rarity_value := get_rarity_value() if rarity_override < 0 else rarity_override
	var rarity_name := "Common"
	var rarity_multiplier := 1.0
	if modifier_config != null:
		rarity_name = modifier_config.get_rarity_name(rarity_value)
		rarity_multiplier = modifier_config.get_rarity_multiplier(rarity_value)

	var final_value := get_final_value(modifier_config, rarity_value)
	return "%s | %s\n%s %s\nBase %s x %.2f" % [
		rarity_name,
		category,
		get_display_name(),
		get_value_text(final_value),
		get_value_text(get_base_value()),
		rarity_multiplier,
	]


func apply_to_player(player: Node, modifier_config: AbilityModifierConfig, rarity_override: int = -1) -> float:
	if player == null or not player.has_method("apply_ability_modifier"):
		return 0.0

	var rarity_value := get_rarity_value() if rarity_override < 0 else rarity_override
	var applied_value = player.call(
		"apply_ability_modifier",
		get_modifier_type(),
		get_base_value(),
		rarity_value
	)
	if typeof(applied_value) == TYPE_INT or typeof(applied_value) == TYPE_FLOAT:
		return float(applied_value)

	return 0.0
