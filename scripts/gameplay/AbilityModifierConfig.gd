extends Resource
class_name AbilityModifierConfig

enum ModifierType {
	DAMAGE_PERCENT,
	ATTACK_SPEED_PERCENT,
	MAX_HP_FLAT,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

# Default value dipakai jika ability memanggil fungsi tanpa nilai khusus.
@export var default_damage_percent := 0.05
@export var default_attack_speed_percent := 0.15
@export var default_max_hp_flat := 5.0

# Multiplier rarity dipisah agar balancing rarity bisa diubah dari resource.
@export var common_multiplier := 1.0
@export var uncommon_multiplier := 1.15
@export var rare_multiplier := 1.3
@export var epic_multiplier := 1.5
@export var legendary_multiplier := 2.0


func calculate_value(base_value: float, rarity: int) -> float:
	return base_value * get_rarity_multiplier(rarity)


func get_rarity_multiplier(rarity: int) -> float:
	match rarity:
		Rarity.COMMON:
			return common_multiplier
		Rarity.UNCOMMON:
			return uncommon_multiplier
		Rarity.RARE:
			return rare_multiplier
		Rarity.EPIC:
			return epic_multiplier
		Rarity.LEGENDARY:
			return legendary_multiplier
		_:
			return common_multiplier


func get_rarity_name(rarity: int) -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Common"
