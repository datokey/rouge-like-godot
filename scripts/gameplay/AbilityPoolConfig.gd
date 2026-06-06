extends Resource
class_name AbilityPoolConfig

@export var offer_count := 3
@export var abilities: Array[Resource] = []
@export var rarity_values: Array[int] = [
	AbilityModifierConfig.Rarity.COMMON,
	AbilityModifierConfig.Rarity.UNCOMMON,
	AbilityModifierConfig.Rarity.RARE,
	AbilityModifierConfig.Rarity.EPIC,
	AbilityModifierConfig.Rarity.LEGENDARY,
]
@export var rarity_weights: Array[int] = [55, 25, 13, 6, 1]


func get_valid_abilities() -> Array[AbilityDefinition]:
	var valid_abilities: Array[AbilityDefinition] = []
	for ability in abilities:
		if ability is AbilityDefinition:
			valid_abilities.append(ability as AbilityDefinition)

	return valid_abilities


func roll_rarity() -> int:
	var value_count := mini(rarity_values.size(), rarity_weights.size())
	if value_count <= 0:
		return AbilityModifierConfig.Rarity.COMMON

	var total_weight := 0
	for index in range(value_count):
		total_weight += maxi(0, rarity_weights[index])

	if total_weight <= 0:
		return AbilityModifierConfig.Rarity.COMMON

	var roll := Rng.range_i(1, total_weight)
	var accumulated_weight := 0
	for index in range(value_count):
		accumulated_weight += maxi(0, rarity_weights[index])
		if roll <= accumulated_weight:
			return rarity_values[index]

	return AbilityModifierConfig.Rarity.COMMON
