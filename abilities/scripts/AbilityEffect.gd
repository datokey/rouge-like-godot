extends Resource
class_name AbilityEffect

enum ValueType {
	FLAT,
	PERCENT,
}

enum StackMode {
	ADD,
	MULTIPLY,
	OVERRIDE,
}

const LEGACY_DAMAGE_PERCENT := 0
const LEGACY_ATTACK_SPEED_PERCENT := 1
const LEGACY_MAX_HP_FLAT := 2
const LEGACY_PROJECTILE_COUNT_FLAT := 3
const LEGACY_MOVE_SPEED_PERCENT := 4

@export var modifier_key: StringName = &""
@export var value := 0.0
@export var value_type: ValueType = ValueType.FLAT
@export var stack_mode: StackMode = StackMode.ADD

@export_storage var target := 0
@export_storage var effect_type := LEGACY_DAMAGE_PERCENT


func get_final_value(modifier_config: AbilityModifierConfig, rarity: int) -> float:
	var base_value := value
	if String(modifier_key).is_empty() and _get_legacy_value_type() == ValueType.PERCENT:
		base_value *= 0.01

	if modifier_config == null:
		return base_value

	return modifier_config.calculate_value(base_value, rarity)


func get_data_value() -> float:
	if String(modifier_key).is_empty() and _get_legacy_value_type() == ValueType.PERCENT:
		return value * 0.01

	return value


func is_percent_effect() -> bool:
	return value_type == ValueType.PERCENT


func is_flat_modifier() -> bool:
	return value_type == ValueType.FLAT


func get_modifier_key() -> StringName:
	if not String(modifier_key).is_empty():
		return modifier_key

	return _get_legacy_modifier_key()


func get_value_type() -> int:
	if not String(modifier_key).is_empty():
		return value_type

	return _get_legacy_value_type()


func get_stack_mode() -> int:
	return stack_mode


func get_modifier_type() -> int:
	match get_modifier_key():
		&"weapon.damage":
			return AbilityModifierConfig.ModifierType.DAMAGE_PERCENT
		&"weapon.cooldown":
			return AbilityModifierConfig.ModifierType.ATTACK_SPEED_PERCENT
		&"weapon.projectile_count":
			return AbilityModifierConfig.ModifierType.PROJECTILE_COUNT_FLAT
		&"player.max_hp":
			return AbilityModifierConfig.ModifierType.MAX_HP_FLAT
		&"player.move_speed":
			return AbilityModifierConfig.ModifierType.MOVE_SPEED_PERCENT
		_:
			return AbilityModifierConfig.ModifierType.DAMAGE_PERCENT


func get_value_text(display_value: float) -> String:
	if get_value_type() == ValueType.PERCENT:
		return "%+d%%" % roundi(display_value * 100.0)

	return "%+d" % roundi(display_value)


func get_effect_label(final_value: float) -> String:
	return "%s %s" % [get_effect_display_name(), get_value_text(final_value)]


func get_target_name() -> String:
	var key := String(get_modifier_key())
	if key.begins_with("weapon."):
		return "Weapon"
	if key.begins_with("player."):
		return "Player"
	if key.begins_with("utility."):
		return "Utility"

	return "Modifier"


func get_effect_display_name() -> String:
	match get_modifier_key():
		&"weapon.damage":
			return "Damage"
		&"weapon.cooldown":
			return "Cooldown"
		&"weapon.range":
			return "Range"
		&"weapon.projectile_count":
			return "Projectile Count"
		&"weapon.projectile_speed":
			return "Projectile Speed"
		&"weapon.aura_radius":
			return "Aura Radius"
		&"weapon.beam_duration":
			return "Beam Duration"
		&"weapon.summon_count":
			return "Summon Count"
		&"player.max_hp":
			return "Max HP"
		&"player.move_speed":
			return "Move Speed"
		&"player.pickup_radius":
			return "Pickup Radius"
		&"utility.magnet_duration":
			return "Magnet Duration"
		_:
			return String(get_modifier_key()).capitalize()


func _get_legacy_modifier_key() -> StringName:
	var legacy_effect_type := _get_legacy_effect_type()
	match legacy_effect_type:
		LEGACY_DAMAGE_PERCENT:
			return &"weapon.damage"
		LEGACY_ATTACK_SPEED_PERCENT:
			return &"weapon.cooldown"
		LEGACY_MAX_HP_FLAT:
			return &"player.max_hp"
		LEGACY_PROJECTILE_COUNT_FLAT:
			return &"weapon.projectile_count"
		LEGACY_MOVE_SPEED_PERCENT:
			return &"player.move_speed"
		_:
			return &"weapon.damage"


func _get_legacy_value_type() -> int:
	match _get_legacy_effect_type():
		LEGACY_DAMAGE_PERCENT, LEGACY_ATTACK_SPEED_PERCENT, LEGACY_MOVE_SPEED_PERCENT:
			return ValueType.PERCENT
		_:
			return ValueType.FLAT


func _get_legacy_effect_type() -> int:
	return effect_type
