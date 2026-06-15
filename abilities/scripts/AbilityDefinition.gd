extends Resource
class_name AbilityDefinition

@export var id := ""
@export var display_name := "Ability"
@export_multiline var description := ""
@export_enum("Safe", "Offense", "Defense", "Mobility") var category := "Safe"
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity := "Common"
@export var trigger := "level_up"
@export var icon: Texture2D
@export var stackable := true
@export var max_stack := 0
@export var effects: Array[Resource] = []
@export var weapon_definition: Resource


func get_upgrade_data() -> Dictionary:
	var effect_data: Array[Dictionary] = []
	for effect in get_effects():
		effect_data.append({
			"target": int(effect.get("target")),
			"effect_type": int(effect.get("effect_type")),
			"value": _get_effect_data_value(effect),
			"stack_mode": int(effect.get("stack_mode")),
		})

	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"category": category,
		"rarity": rarity,
		"trigger": trigger,
		"icon": icon,
		"stackable": stackable,
		"max_stack": max_stack,
		"effects": effect_data,
		"weapon_id": get_weapon_id(),
	}


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


func get_weapon_id() -> String:
	if weapon_definition == null:
		return ""

	return str(weapon_definition.get("id"))


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


func _get_first_effect() -> Resource:
	var valid_effects := get_effects()
	if valid_effects.is_empty():
		return null

	return valid_effects[0]
