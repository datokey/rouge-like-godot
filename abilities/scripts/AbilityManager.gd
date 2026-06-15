extends RefCounted
class_name AbilityManager

const TARGET_PLAYER := 0
const TARGET_WEAPON := 1
const EFFECT_DAMAGE_PERCENT := 0
const EFFECT_ATTACK_SPEED_PERCENT := 1
const EFFECT_MAX_HP_FLAT := 2
const EFFECT_PROJECTILE_COUNT_FLAT := 3
const EFFECT_MOVE_SPEED_PERCENT := 4

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


func get_flat_modifier(target: int, effect_type: int) -> float:
	var total := 0.0
	for effect_data in active_effects:
		if int(effect_data.get("target", -1)) != target:
			continue
		if int(effect_data.get("effect_type", -1)) != effect_type:
			continue
		if bool(effect_data.get("is_percent", false)):
			continue

		total += float(effect_data.get("value", 0.0))

	return total


func get_percent_modifier(target: int, effect_type: int) -> float:
	var total := 0.0
	for effect_data in active_effects:
		if int(effect_data.get("target", -1)) != target:
			continue
		if int(effect_data.get("effect_type", -1)) != effect_type:
			continue
		if not bool(effect_data.get("is_percent", false)):
			continue

		total += float(effect_data.get("value", 0.0))

	return total


func get_active_effects() -> Array[Dictionary]:
	return active_effects.duplicate(true)


func get_weapon_damage_percent_modifier() -> float:
	return get_percent_modifier(TARGET_WEAPON, EFFECT_DAMAGE_PERCENT)


func get_weapon_attack_speed_percent_modifier() -> float:
	return get_percent_modifier(TARGET_WEAPON, EFFECT_ATTACK_SPEED_PERCENT)


func get_weapon_projectile_count_modifier() -> float:
	return get_flat_modifier(TARGET_WEAPON, EFFECT_PROJECTILE_COUNT_FLAT)


func get_player_max_hp_modifier() -> float:
	return get_flat_modifier(TARGET_PLAYER, EFFECT_MAX_HP_FLAT)


func get_player_move_speed_percent_modifier() -> float:
	return get_percent_modifier(TARGET_PLAYER, EFFECT_MOVE_SPEED_PERCENT)


func _add_active_effects(ability: Resource, ability_id: String, rarity: int) -> void:
	var effects: Array = ability.call("get_effects")
	for effect in effects:
		if not effect is Resource:
			continue

		var final_value := _get_effect_final_value(effect as Resource, rarity)
		active_effects.append({
			"ability_id": ability_id,
			"target": int(effect.get("target")),
			"effect_type": int(effect.get("effect_type")),
			"value": final_value,
			"stack_mode": int(effect.get("stack_mode")),
			"is_percent": _is_percent_effect(effect as Resource),
		})


func _get_effect_final_value(effect: Resource, rarity: int) -> float:
	if not effect.has_method("get_final_value"):
		return 0.0

	var final_value = effect.call("get_final_value", modifier_config, rarity)
	if typeof(final_value) == TYPE_INT or typeof(final_value) == TYPE_FLOAT:
		return float(final_value)

	return 0.0


func _is_percent_effect(effect: Resource) -> bool:
	if not effect.has_method("is_percent_effect"):
		return false

	var is_percent = effect.call("is_percent_effect")
	return is_percent == true
