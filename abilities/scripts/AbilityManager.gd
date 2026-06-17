extends RefCounted
class_name AbilityManager

const KEY_WEAPON_DAMAGE := &"weapon.damage"
const KEY_WEAPON_COOLDOWN := &"weapon.cooldown"
const KEY_WEAPON_PROJECTILE_COUNT := &"weapon.projectile_count"
const KEY_PLAYER_MAX_HP := &"player.max_hp"
const KEY_PLAYER_MOVE_SPEED := &"player.move_speed"

var modifier_config: AbilityModifierConfig
var ability_stacks := {}
var active_effects: Array[Dictionary] = []


func setup(new_modifier_config: AbilityModifierConfig) -> void:
	modifier_config = new_modifier_config


func add_ability(ability: Resource, rarity_override: int = -1) -> bool:
	if ability == null or not ability.has_method("get_effects"):
		return false

	var ability_id := str(ability.get("id"))
	if ability_id.is_empty():
		return false

	var current_stack := get_stack_count(ability_id)
	var stackable := bool(ability.get("stackable"))
	var max_stack := int(ability.get("max_stack"))
	if not stackable and current_stack > 0:
		return false
	if max_stack > 0 and current_stack >= max_stack:
		return false

	var rarity := rarity_override
	if rarity < 0 and ability.has_method("get_rarity_value"):
		rarity = int(ability.call("get_rarity_value"))
	if rarity < 0:
		rarity = AbilityModifierConfig.Rarity.COMMON

	ability_stacks[ability_id] = current_stack + 1
	_add_active_effects(ability, ability_id, rarity)
	return true


func get_stack_count(ability_id: String) -> int:
	return int(ability_stacks.get(ability_id, 0))


func get_ability_stacks() -> Dictionary:
	return ability_stacks.duplicate(true)


func get_flat_modifier(modifier_key: StringName) -> float:
	return _get_modifier_value(modifier_key, AbilityEffect.ValueType.FLAT)


func get_percent_modifier(modifier_key: StringName) -> float:
	return _get_modifier_value(modifier_key, AbilityEffect.ValueType.PERCENT)


func apply_modifiers(base_value: float, modifier_key: StringName) -> float:
	var with_flat := base_value + get_flat_modifier(modifier_key)
	return with_flat * (1.0 + get_percent_modifier(modifier_key))


func get_active_effects() -> Array[Dictionary]:
	return active_effects.duplicate(true)


func get_weapon_damage_percent_modifier() -> float:
	return get_percent_modifier(KEY_WEAPON_DAMAGE)


func get_weapon_attack_speed_percent_modifier() -> float:
	return -get_percent_modifier(KEY_WEAPON_COOLDOWN)


func get_weapon_projectile_count_modifier() -> float:
	return get_flat_modifier(KEY_WEAPON_PROJECTILE_COUNT)


func get_player_max_hp_modifier() -> float:
	return get_flat_modifier(KEY_PLAYER_MAX_HP)


func get_player_move_speed_percent_modifier() -> float:
	return get_percent_modifier(KEY_PLAYER_MOVE_SPEED)


func _add_active_effects(ability: Resource, ability_id: String, rarity: int) -> void:
	var effects: Array = ability.call("get_effects")
	for effect in effects:
		if not effect is Resource:
			continue

		var effect_resource := effect as Resource
		var final_value := _get_effect_final_value(effect_resource, rarity)
		active_effects.append({
			"ability_id": ability_id,
			"modifier_key": _get_effect_modifier_key(effect_resource),
			"value": final_value,
			"value_type": _get_effect_value_type(effect_resource),
			"stack_mode": _get_effect_stack_mode(effect_resource),
		})


func _get_modifier_value(modifier_key: StringName, value_type: int) -> float:
	var add_total := 0.0
	var multiply_scale := 1.0
	var override_value := 0.0
	var has_override := false

	for effect_data in active_effects:
		if effect_data.get("modifier_key") != modifier_key:
			continue
		if int(effect_data.get("value_type", AbilityEffect.ValueType.FLAT)) != value_type:
			continue

		var effect_value := float(effect_data.get("value", 0.0))
		match int(effect_data.get("stack_mode", AbilityEffect.StackMode.ADD)):
			AbilityEffect.StackMode.MULTIPLY:
				multiply_scale *= 1.0 + effect_value
			AbilityEffect.StackMode.OVERRIDE:
				override_value = effect_value
				has_override = true
			_:
				add_total += effect_value

	var total := add_total * multiply_scale
	if value_type == AbilityEffect.ValueType.PERCENT:
		total = (1.0 + add_total) * multiply_scale - 1.0
	if has_override:
		total = override_value

	return total


func _get_effect_final_value(effect: Resource, rarity: int) -> float:
	if not effect.has_method("get_final_value"):
		return 0.0

	var final_value = effect.call("get_final_value", modifier_config, rarity)
	if typeof(final_value) == TYPE_INT or typeof(final_value) == TYPE_FLOAT:
		return float(final_value)

	return 0.0


func _get_effect_modifier_key(effect: Resource) -> StringName:
	if effect.has_method("get_modifier_key"):
		return effect.call("get_modifier_key")

	var value: Variant = effect.get("modifier_key")
	if typeof(value) == TYPE_STRING_NAME:
		return value
	if typeof(value) == TYPE_STRING:
		return StringName(value)

	return &""


func _get_effect_value_type(effect: Resource) -> int:
	if effect.has_method("get_value_type"):
		return int(effect.call("get_value_type"))

	var value: Variant = effect.get("value_type")
	if typeof(value) == TYPE_INT:
		return int(value)

	return AbilityEffect.ValueType.FLAT


func _get_effect_stack_mode(effect: Resource) -> int:
	if effect.has_method("get_stack_mode"):
		return int(effect.call("get_stack_mode"))

	var value: Variant = effect.get("stack_mode")
	if typeof(value) == TYPE_INT:
		return int(value)

	return AbilityEffect.StackMode.ADD
