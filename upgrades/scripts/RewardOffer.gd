extends RefCounted
class_name RewardOffer

enum Category {
	WEAPON_NEW,
	WEAPON_UPGRADE,
	TALISMAN_NEW,
	TALISMAN_UPGRADE,
	UTILITY,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

var category: Category
var rarity: Rarity = Rarity.COMMON
var rarity_multiplier := 1.0
var weight := 1.0
var weapon_definition: WeaponDefinition
var weapon_id := ""
var weapon_upgrade: WeaponUpgradeDefinition
var weapon_upgrade_value := 0.0
var talisman: TalismanDefinition
var utility: UtilityDefinition


func get_unique_id() -> String:
	match category:
		Category.WEAPON_NEW:
			return "weapon_new:%s" % weapon_id
		Category.WEAPON_UPGRADE:
			return "weapon_upgrade:%s:%s" % [weapon_id, weapon_upgrade.id]
		Category.TALISMAN_NEW, Category.TALISMAN_UPGRADE:
			return "talisman:%s" % talisman.id
		Category.UTILITY:
			return "utility:%s" % utility.id
	return ""


func get_offer_text() -> String:
	var rarity_name := get_rarity_name()
	match category:
		Category.WEAPON_NEW:
			return "%s | Weapon Baru\n%s\n%s" % [
				rarity_name,
				weapon_definition.display_name,
				weapon_definition.description,
			]
		Category.WEAPON_UPGRADE:
			return "%s | Upgrade %s\n%s\n%s" % [
				rarity_name,
				weapon_definition.display_name,
				weapon_upgrade.display_name,
				_format_weapon_upgrade(),
			]
		Category.TALISMAN_NEW:
			return "%s | Talisman Baru\n%s\n%s" % [rarity_name, talisman.display_name, talisman.description]
		Category.TALISMAN_UPGRADE:
			return "%s | Upgrade Talisman\n%s\n%s" % [rarity_name, talisman.display_name, _format_modifier(talisman)]
		Category.UTILITY:
			return "%s | Utility\n%s\n%s" % [rarity_name, utility.display_name, utility.description]
	return ""


func get_rarity_name() -> String:
	match rarity:
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
	return "Common"


func _format_modifier(modifier: ModifierDefinition) -> String:
	var scaled_value := modifier.get_scaled_value(rarity_multiplier)
	if modifier.value_type == ModifierDefinition.ValueType.PERCENT:
		if scaled_value < 0.0 and modifier.modifier_key in [
			&"weapon.cooldown",
			&"weapon.attack_speed",
			&"weapon.beam_tick_interval",
			&"weapon.aura_tick_interval",
			&"weapon.summon_attack_cooldown",
		]:
			return "+%.0f%% lebih cepat" % (absf(scaled_value) * 100.0)
		return "%+.0f%%" % (scaled_value * 100.0)
	return "%+.1f" % scaled_value


func _format_weapon_upgrade() -> String:
	if weapon_upgrade == null:
		return ""
	if weapon_upgrade.uses_count_value():
		return "+%d" % roundi(weapon_upgrade_value)
	if weapon_upgrade.stat_type == WeaponUpgradeDefinition.StatType.FIRE_RATE:
		return "+%.0f%% lebih cepat" % (absf(weapon_upgrade_value) * 100.0)
	return "+%.0f%%" % (weapon_upgrade_value * 100.0)
