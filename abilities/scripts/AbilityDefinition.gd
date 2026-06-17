extends Resource
class_name AbilityDefinition

enum RewardCategory {
	AUTO,
	WEAPON_NEW,
	WEAPON_UPGRADE,
	SKILL_NEW,
	SKILL_UPGRADE,
	WEAPON_MODIFIER,
	SKILL_MODIFIER,
	GLOBAL_MODIFIER,
}

@export var id := ""
@export var display_name := "Ability"
@export_multiline var description := ""
@export_enum("Safe", "Risky", "Weird", "Offense", "Defense", "Mobility") var category := "Safe"
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity := "Common"
@export var archetype := ""
@export var trigger := "level_up"
@export var icon: Texture2D
@export var enabled := true
@export var stackable := true
@export var max_stack := 0
@export var reward_category: RewardCategory = RewardCategory.AUTO
@export var weight := 1.0
@export var eligibility_rules: Array[Resource] = []
@export var effects: Array[Resource] = []
@export var weapon_definition: Resource
@export var skill_definition: Resource
@export var skill_id := ""
@export var target_weapon_id := ""
@export var target_skill_id := ""


func get_upgrade_data() -> Dictionary:
	var effect_data: Array[Dictionary] = []
	for effect in get_effects():
		effect_data.append({
			"modifier_key": _get_effect_modifier_key(effect),
			"value": _get_effect_data_value(effect),
			"value_type": _get_effect_value_type(effect),
			"stack_mode": _get_effect_stack_mode(effect),
		})

	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"category": category,
		"rarity": rarity,
		"archetype": archetype,
		"trigger": trigger,
		"icon": icon,
		"stackable": stackable,
		"max_stack": max_stack,
		"reward_category": get_reward_category(),
		"weight": get_weight(),
		"effects": effect_data,
		"weapon_id": get_weapon_id(),
		"skill_id": get_skill_id(),
		"target_weapon_id": get_target_weapon_id(),
		"target_skill_id": get_target_skill_id(),
	}


func is_eligible(context: Dictionary) -> bool:
	if not enabled:
		return false

	for rule in eligibility_rules:
		if rule == null or not rule.has_method("is_satisfied"):
			return false
		if rule.call("is_satisfied", context) != true:
			return false

	return true


func get_effects() -> Array[Resource]:
	var valid_effects: Array[Resource] = []
	for effect in effects:
		if effect is Resource and effect.has_method("get_final_value"):
			valid_effects.append(effect as Resource)

	return valid_effects


func get_display_name() -> String:
	return display_name


func is_weapon_reward() -> bool:
	return weapon_definition != null


func is_skill_reward() -> bool:
	return skill_definition != null or not skill_id.is_empty()


func get_weapon_id() -> String:
	if weapon_definition == null:
		return ""

	return str(weapon_definition.get("id"))


func get_skill_id() -> String:
	if skill_definition != null:
		return str(skill_definition.get("id"))

	return skill_id


func get_target_weapon_id() -> String:
	return target_weapon_id


func get_target_skill_id() -> String:
	return target_skill_id


func get_weapon_modifier_keys() -> Array[StringName]:
	var modifier_keys: Array[StringName] = []
	for effect in get_effects():
		var modifier_key := _get_effect_modifier_key(effect)
		if String(modifier_key).begins_with("weapon.") and not modifier_keys.has(modifier_key):
			modifier_keys.append(modifier_key)

	return modifier_keys


func get_weight() -> float:
	return maxf(0.0, weight)


func get_reward_category(context: Dictionary = {}) -> int:
	if reward_category != RewardCategory.AUTO:
		return reward_category

	if is_weapon_reward():
		var weapon_id := get_weapon_id()
		var owned_weapon_levels: Dictionary = context.get("owned_weapon_levels", {})
		var owned_weapon_ids: Array = context.get("owned_weapon_ids", [])
		if not weapon_id.is_empty() and (
			owned_weapon_levels.has(weapon_id) or owned_weapon_ids.has(weapon_id)
		):
			return RewardCategory.WEAPON_UPGRADE

		return RewardCategory.WEAPON_NEW

	if is_skill_reward():
		var resolved_skill_id := get_skill_id()
		var owned_skill_levels: Dictionary = context.get("owned_skill_levels", {})
		if owned_skill_levels.has(resolved_skill_id):
			return RewardCategory.SKILL_UPGRADE

		return RewardCategory.SKILL_NEW

	if _has_modifier_key_prefix("skill.") or not target_skill_id.is_empty():
		return RewardCategory.SKILL_MODIFIER
	if _has_modifier_key_prefix("weapon.") or not target_weapon_id.is_empty():
		return RewardCategory.WEAPON_MODIFIER

	return RewardCategory.GLOBAL_MODIFIER


func get_reward_category_name(context: Dictionary = {}) -> String:
	match get_reward_category(context):
		RewardCategory.WEAPON_NEW:
			return "Weapon New"
		RewardCategory.WEAPON_UPGRADE:
			return "Weapon Upgrade"
		RewardCategory.SKILL_NEW:
			return "Skill New"
		RewardCategory.SKILL_UPGRADE:
			return "Skill Upgrade"
		RewardCategory.WEAPON_MODIFIER:
			return "Weapon Modifier"
		RewardCategory.SKILL_MODIFIER:
			return "Skill Modifier"
		RewardCategory.GLOBAL_MODIFIER:
			return "Global Modifier"
		_:
			return "Auto"


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
	var first_effect := _get_first_effect()
	if first_effect == null:
		return 0.0

	var rarity_value := get_rarity_value() if rarity_override < 0 else rarity_override
	var final_value = first_effect.call("get_final_value", modifier_config, rarity_value)
	if typeof(final_value) == TYPE_INT or typeof(final_value) == TYPE_FLOAT:
		return float(final_value)

	return 0.0


func get_offer_text(modifier_config: AbilityModifierConfig, rarity_override: int = -1) -> String:
	if is_weapon_reward():
		return _get_weapon_offer_text()
	if is_skill_reward():
		return _get_skill_offer_text()

	var rarity_value := get_rarity_value() if rarity_override < 0 else rarity_override
	var rarity_name := "Common"
	var rarity_multiplier := 1.0
	if modifier_config != null:
		rarity_name = modifier_config.get_rarity_name(rarity_value)
		rarity_multiplier = modifier_config.get_rarity_multiplier(rarity_value)

	var effect_lines: Array[String] = []
	for effect in get_effects():
		var final_value := _get_effect_final_value(effect, modifier_config, rarity_value)
		var effect_label = effect.call("get_effect_label", final_value)
		if typeof(effect_label) == TYPE_STRING:
			effect_lines.append(effect_label)

	if effect_lines.is_empty():
		effect_lines.append("No effect")

	return "%s | %s\n%s\n%s\nx %.2f" % [
		rarity_name,
		category,
		display_name,
		"\n".join(effect_lines),
		rarity_multiplier,
	]


func _get_weapon_offer_text() -> String:
	var weapon_name := display_name
	if weapon_definition != null:
		weapon_name = str(weapon_definition.get("display_name"))

	return "%s | Weapon\n%s\nAdd or upgrade weapon" % [
		rarity,
		weapon_name,
	]


func _get_skill_offer_text() -> String:
	var skill_name := display_name
	if skill_definition != null:
		skill_name = str(skill_definition.get("display_name"))

	return "%s | Skill\n%s\nAdd or upgrade skill" % [
		rarity,
		skill_name,
	]


func _has_modifier_key_prefix(prefix: String) -> bool:
	for effect in get_effects():
		var modifier_key := String(_get_effect_modifier_key(effect))
		if modifier_key.begins_with(prefix):
			return true

	return false


func apply_to_player(player: Node, modifier_config: AbilityModifierConfig, rarity_override: int = -1) -> float:
	if player == null or not player.has_method("add_ability_to_manager"):
		return 0.0

	var added = player.call("add_ability_to_manager", self, rarity_override)
	if added == true:
		return get_final_value(modifier_config, rarity_override)

	return 0.0


func _get_effect_final_value(effect: Resource, modifier_config: AbilityModifierConfig, rarity_value: int) -> float:
	var final_value = effect.call("get_final_value", modifier_config, rarity_value)
	if typeof(final_value) == TYPE_INT or typeof(final_value) == TYPE_FLOAT:
		return float(final_value)

	return 0.0


func _get_effect_data_value(effect: Resource) -> float:
	if effect.has_method("get_data_value"):
		var data_value = effect.call("get_data_value")
		if typeof(data_value) == TYPE_INT or typeof(data_value) == TYPE_FLOAT:
			return float(data_value)

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


func _get_first_effect() -> Resource:
	var valid_effects := get_effects()
	if valid_effects.is_empty():
		return null

	return valid_effects[0]
