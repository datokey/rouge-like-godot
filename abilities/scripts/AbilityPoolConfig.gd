extends Resource
class_name AbilityPoolConfig

@export var offer_count := 3
@export var abilities: Array[Resource] = []


func get_valid_abilities(
	excluded_ids: Array[String] = [],
	taken_counts: Dictionary = {},
	weapon_context: Dictionary = {}
) -> Array[AbilityDefinition]:
	var valid_abilities: Array[AbilityDefinition] = []
	for ability in abilities:
		if not ability is AbilityDefinition:
			continue

		var ability_definition := ability as AbilityDefinition
		if not ability_definition.stackable and excluded_ids.has(ability_definition.id):
			continue
		if ability_definition.max_stack > 0:
			var taken_count := int(taken_counts.get(ability_definition.id, 0))
			if taken_count >= ability_definition.max_stack:
				continue
		if ability_definition.is_weapon_reward() and not _can_offer_weapon_reward(ability_definition, weapon_context):
			continue

		valid_abilities.append(ability_definition)

	return valid_abilities


func roll_offers(
	max_offer_count: int,
	excluded_ids: Array[String] = [],
	taken_counts: Dictionary = {},
	weapon_context: Dictionary = {}
) -> Array[AbilityDefinition]:
	var offers: Array[AbilityDefinition] = []
	var available_abilities := get_valid_abilities(excluded_ids, taken_counts, weapon_context)
	var rolled_offer_count := mini(offer_count, max_offer_count)
	rolled_offer_count = mini(rolled_offer_count, available_abilities.size())

	for _index in range(rolled_offer_count):
		var ability_index := Rng.range_i(0, available_abilities.size() - 1)
		offers.append(available_abilities[ability_index])
		available_abilities.remove_at(ability_index)

	return offers


func _can_offer_weapon_reward(ability_definition: AbilityDefinition, weapon_context: Dictionary) -> bool:
	var weapon_id := ability_definition.get_weapon_id()
	if weapon_id.is_empty():
		return false

	var owned_levels: Dictionary = weapon_context.get("owned_weapon_levels", {})
	var owned_max_levels: Dictionary = weapon_context.get("owned_weapon_max_levels", {})
	if owned_levels.has(weapon_id):
		var current_level := int(owned_levels.get(weapon_id, 1))
		var max_level := int(owned_max_levels.get(weapon_id, 1))
		return current_level < max_level

	return bool(weapon_context.get("can_add_weapon", true))
