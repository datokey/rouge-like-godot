extends ModifierDefinition
class_name WeaponUpgradeDefinition

enum StatType {
	FIRE_RATE,
	PROJECTILE_COUNT,
	BEAM_COUNT,
	MINION_PROJECTILE_COUNT,
	ATTACK_RANGE,
	PIERCE,
	DAMAGE,
	SIZE,
}

@export var stat_type: StatType = StatType.DAMAGE


func uses_count_value() -> bool:
	return stat_type in [StatType.PROJECTILE_COUNT, StatType.BEAM_COUNT, StatType.MINION_PROJECTILE_COUNT]


func get_rarity_value(
	rarity: int,
	percent_values: Array[float],
	count_values: Array[int]
) -> float:
	if uses_count_value():
		return float(count_values[rarity]) if rarity < count_values.size() else 1.0
	var value_for_rarity := percent_values[rarity] if rarity < percent_values.size() else 0.02
	return -value_for_rarity if stat_type == StatType.FIRE_RATE else value_for_rarity
