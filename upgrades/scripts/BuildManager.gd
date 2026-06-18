extends RefCounted
class_name BuildManager

const BASE_CRITICAL_CHANCE := 0.05
const BASE_CRITICAL_DAMAGE := 0.5

var max_talisman_slots := 4
var owner_node: Node
var talisman_levels: Dictionary = {}
var talisman_definitions: Dictionary = {}
var utility_levels: Dictionary = {}
var active_modifiers: Array[Dictionary] = []


func setup(new_owner_node: Node) -> void:
	owner_node = new_owner_node


func apply_offer(offer: RewardOffer, weapon_manager: WeaponManager) -> bool:
	if offer == null:
		return false
	match offer.category:
		RewardOffer.Category.WEAPON_NEW:
			return weapon_manager != null and weapon_manager.add_weapon(offer.weapon_definition)
		RewardOffer.Category.WEAPON_UPGRADE:
			return weapon_manager != null and weapon_manager.apply_stat_upgrade(
				offer.weapon_id,
				offer.weapon_upgrade,
				offer.rarity_multiplier
			)
		RewardOffer.Category.TALISMAN_NEW, RewardOffer.Category.TALISMAN_UPGRADE:
			return add_talisman(offer.talisman, offer.rarity_multiplier)
		RewardOffer.Category.UTILITY:
			return add_utility(offer.utility, offer.rarity_multiplier)
	return false


func add_talisman(talisman: TalismanDefinition, rarity_multiplier: float) -> bool:
	if talisman == null or talisman.id.is_empty():
		return false
	var current_level := int(talisman_levels.get(talisman.id, 0))
	if current_level == 0 and not can_add_talisman():
		return false
	if current_level >= talisman.max_level:
		return false

	talisman_levels[talisman.id] = current_level + 1
	talisman_definitions[talisman.id] = talisman
	active_modifiers.append({
		"modifier_key": talisman.modifier_key,
		"value": talisman.get_scaled_value(rarity_multiplier),
		"value_type": talisman.value_type,
		"compatibility_tags": talisman.compatibility_tags.duplicate(),
	})
	return true


func add_utility(utility: UtilityDefinition, rarity_multiplier: float) -> bool:
	if utility == null or not utility.enabled or utility.id.is_empty():
		return false
	var current_level := int(utility_levels.get(utility.id, 0))
	if utility.max_level > 0 and current_level >= utility.max_level:
		return false
	utility_levels[utility.id] = current_level + 1
	_apply_utility(utility, utility.value * rarity_multiplier)
	return true


func can_add_talisman() -> bool:
	return talisman_levels.size() < max_talisman_slots


func apply_weapon_modifiers(base_value: float, modifier_key: StringName, weapon_tags: Array) -> float:
	var flat := _get_modifier_value(modifier_key, ModifierDefinition.ValueType.FLAT, weapon_tags, true)
	var percent := _get_modifier_value(modifier_key, ModifierDefinition.ValueType.PERCENT, weapon_tags, true)
	return (base_value + flat) * (1.0 + percent)


func get_weapon_flat_modifier(modifier_key: StringName, weapon_tags: Array) -> float:
	return _get_modifier_value(modifier_key, ModifierDefinition.ValueType.FLAT, weapon_tags, true)


func get_flat_modifier(modifier_key: StringName) -> float:
	return _get_modifier_value(modifier_key, ModifierDefinition.ValueType.FLAT, [], false)


func get_percent_modifier(modifier_key: StringName) -> float:
	return _get_modifier_value(modifier_key, ModifierDefinition.ValueType.PERCENT, [], false)


func get_critical_chance(weapon_tags: Array) -> float:
	if not weapon_tags.has(CompatibilityTags.CAN_CRIT):
		return 0.0
	return clampf(BASE_CRITICAL_CHANCE + _get_modifier_value(
		&"combat.critical_chance",
		ModifierDefinition.ValueType.FLAT,
		weapon_tags,
		true
	), 0.0, 1.0)


func get_critical_damage(weapon_tags: Array) -> float:
	if not weapon_tags.has(CompatibilityTags.CAN_CRIT):
		return 0.0
	return maxf(0.0, BASE_CRITICAL_DAMAGE + _get_modifier_value(
		&"combat.critical_damage",
		ModifierDefinition.ValueType.FLAT,
		weapon_tags,
		true
	))


func get_life_steal(weapon_tags: Array) -> float:
	return clampf(_get_modifier_value(&"combat.life_steal", ModifierDefinition.ValueType.FLAT, weapon_tags, true), 0.0, 1.0)


func get_luck() -> float:
	return maxf(0.0, get_flat_modifier(&"meta.luck"))


func get_armor() -> int:
	return maxi(0, roundi(get_flat_modifier(&"player.armor")))


func get_offer_context(owned_weapon_tags: Array) -> Dictionary:
	return {
		"max_talisman_slots": max_talisman_slots,
		"used_talisman_slots": talisman_levels.size(),
		"available_talisman_slots": maxi(0, max_talisman_slots - talisman_levels.size()),
		"can_add_talisman": can_add_talisman(),
		"owned_talisman_levels": talisman_levels.duplicate(true),
		"owned_compatibility_tags": owned_weapon_tags.duplicate(),
		"utility_levels": utility_levels.duplicate(true),
		"luck": get_luck(),
	}


func _get_modifier_value(
	modifier_key: StringName,
	value_type: int,
	weapon_tags: Array,
	check_compatibility: bool
) -> float:
	var total := 0.0
	for modifier in active_modifiers:
		if modifier.get("modifier_key") != modifier_key:
			continue
		if int(modifier.get("value_type", ModifierDefinition.ValueType.FLAT)) != value_type:
			continue
		var required_tags: Array = modifier.get("compatibility_tags", [])
		if check_compatibility and not _tags_match(required_tags, weapon_tags):
			continue
		total += float(modifier.get("value", 0.0))
	return total


func _tags_match(required_tags: Array, weapon_tags: Array) -> bool:
	if required_tags.is_empty():
		return true
	for tag in required_tags:
		if weapon_tags.has(tag):
			return true
	return false


func _apply_utility(utility: UtilityDefinition, scaled_value: float) -> void:
	if owner_node == null:
		return
	match utility.effect_type:
		UtilityDefinition.EffectType.REROLL:
			owner_node.set("upgrade_rerolls", int(owner_node.get("upgrade_rerolls")) + roundi(scaled_value))
		UtilityDefinition.EffectType.PICKUP_RADIUS:
			owner_node.set("pickup_radius_bonus", float(owner_node.get("pickup_radius_bonus")) + scaled_value)
			if owner_node.has_method("sync_pickup_radius"):
				owner_node.call("sync_pickup_radius")
		UtilityDefinition.EffectType.REVIVE:
			owner_node.set("revive_charges", int(owner_node.get("revive_charges")) + roundi(scaled_value))
		UtilityDefinition.EffectType.EXTRA_OFFER:
			owner_node.set("extra_upgrade_choices", int(owner_node.get("extra_upgrade_choices")) + roundi(scaled_value))
		UtilityDefinition.EffectType.EXTRA_DASH:
			owner_node.set("extra_dash_charges", int(owner_node.get("extra_dash_charges")) + roundi(scaled_value))
		UtilityDefinition.EffectType.ELITE_KILL_HEAL:
			owner_node.set("elite_kill_heal", float(owner_node.get("elite_kill_heal")) + scaled_value)
		UtilityDefinition.EffectType.DAMAGE_TO_SHIELD:
			owner_node.set("damage_to_shield_ratio", float(owner_node.get("damage_to_shield_ratio")) + scaled_value)
		UtilityDefinition.EffectType.PERMANENT_MAX_HP:
			var bonus := maxi(1, roundi(scaled_value))
			owner_node.set("utility_max_hp_bonus", int(owner_node.get("utility_max_hp_bonus")) + bonus)
			if owner_node.has_method("increase_current_hp"):
				owner_node.call("increase_current_hp", bonus)
