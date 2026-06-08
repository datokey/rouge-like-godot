extends Resource
class_name AbilityPoolConfig

@export var offer_count := 3
@export var abilities: Array[Resource] = []


func get_valid_abilities(excluded_ids: Array[String] = []) -> Array[AbilityDefinition]:
	var valid_abilities: Array[AbilityDefinition] = []
	for ability in abilities:
		if not ability is AbilityDefinition:
			continue

		var ability_definition := ability as AbilityDefinition
		if not ability_definition.stackable and excluded_ids.has(ability_definition.id):
			continue

		valid_abilities.append(ability_definition)

	return valid_abilities


func roll_offers(max_offer_count: int, excluded_ids: Array[String] = []) -> Array[AbilityDefinition]:
	var offers: Array[AbilityDefinition] = []
	var available_abilities := get_valid_abilities(excluded_ids)
	var rolled_offer_count := mini(offer_count, max_offer_count)
	rolled_offer_count = mini(rolled_offer_count, available_abilities.size())

	for _index in range(rolled_offer_count):
		var ability_index := Rng.range_i(0, available_abilities.size() - 1)
		offers.append(available_abilities[ability_index])
		available_abilities.remove_at(ability_index)

	return offers
