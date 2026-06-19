extends Resource
class_name RewardPoolConfig

@export_range(1, 8, 1) var offer_count := 3
@export var weapon_definitions: Array[Resource] = []
@export var talisman_definitions: Array[Resource] = []
@export var utility_definitions: Array[Resource] = []
@export var fallback_definitions: Array[Resource] = []
@export var rarity_weights: Array[float] = [70.0, 20.0, 7.0, 2.5, 0.5]
@export var rarity_multipliers: Array[float] = [1.0, 1.15, 1.3, 1.5, 2.0]
@export var utility_rarity_weight_multipliers: Array[float] = [1.0, 0.7, 0.4, 0.18, 0.06]
@export var weapon_percent_upgrade_values: Array[float] = [0.02, 0.04, 0.07, 0.10, 0.15]
@export var weapon_count_upgrade_values: Array[int] = [1, 2, 3, 4, 7]
@export var talisman_percent_upgrade_values: Array[float] = [0.02, 0.04, 0.07, 0.10, 0.15]


func roll_offers(context: Dictionary, max_offer_count: int) -> Array[RewardOffer]:
	var candidates := get_valid_candidates(context)
	var offers: Array[RewardOffer] = []
	var target_count := mini(offer_count, max_offer_count)
	while offers.size() < target_count and not candidates.is_empty():
		var candidate_index := _roll_candidate_index(candidates)
		if candidate_index < 0:
			break
		var offer := candidates.pop_at(candidate_index) as RewardOffer
		_assign_offer_rarity(offer, float(context.get("luck", 0.0)))
		offers.append(offer)
	if offers.size() < target_count:
		_add_fallback_offers(offers, context, target_count)
	return offers


func get_valid_candidates(context: Dictionary) -> Array[RewardOffer]:
	var candidates: Array[RewardOffer] = []
	var owned_weapon_ids: Array = context.get("owned_weapon_ids", [])
	if bool(context.get("can_add_weapon", false)):
		for resource in weapon_definitions:
			var definition := resource as WeaponDefinition
			if definition == null or owned_weapon_ids.has(definition.id):
				continue
			var offer := RewardOffer.new()
			offer.category = RewardOffer.Category.WEAPON_NEW
			offer.weapon_definition = definition
			offer.weapon_id = definition.id
			offer.weight = definition.reward_weight
			candidates.append(offer)

	var owned_definitions: Dictionary = context.get("owned_weapon_definitions", {})
	var owned_levels: Dictionary = context.get("owned_weapon_levels", {})
	var owned_max_levels: Dictionary = context.get("owned_weapon_max_levels", {})
	var upgrade_availability: Dictionary = context.get("weapon_upgrade_availability", {})
	for weapon_id_value in owned_weapon_ids:
		var weapon_id := str(weapon_id_value)
		var definition := owned_definitions.get(weapon_id) as WeaponDefinition
		if definition == null:
			continue
		if int(owned_levels.get(weapon_id, 1)) >= int(owned_max_levels.get(weapon_id, definition.max_level)):
			continue
		var available_for_weapon: Dictionary = upgrade_availability.get(weapon_id, {})
		for resource in definition.upgrade_options:
			var upgrade := resource as WeaponUpgradeDefinition
			if upgrade == null or upgrade.id.is_empty():
				continue
			if available_for_weapon.has(upgrade.id) and not bool(available_for_weapon[upgrade.id]):
				continue
			var offer := RewardOffer.new()
			offer.category = RewardOffer.Category.WEAPON_UPGRADE
			offer.weapon_definition = definition
			offer.weapon_id = weapon_id
			offer.weapon_upgrade = upgrade
			offer.weight = upgrade.weight
			candidates.append(offer)

	var owned_talisman_levels: Dictionary = context.get("owned_talisman_levels", {})
	var owned_talisman_bonuses: Dictionary = context.get("owned_talisman_bonuses", {})
	var can_add_talisman := bool(context.get("can_add_talisman", false))
	var owned_tags: Array = context.get("owned_compatibility_tags", [])
	for resource in talisman_definitions:
		var talisman := resource as TalismanDefinition
		if talisman == null or talisman.id.is_empty() or not talisman.is_compatible(owned_tags):
			continue
		var current_level := int(owned_talisman_levels.get(talisman.id, 0))
		if current_level <= 0 and not can_add_talisman:
			continue
		if current_level >= talisman.max_level:
			continue
		if talisman.is_bonus_capped(float(owned_talisman_bonuses.get(talisman.id, 0.0))):
			continue
		var offer := RewardOffer.new()
		offer.category = RewardOffer.Category.TALISMAN_NEW if current_level == 0 else RewardOffer.Category.TALISMAN_UPGRADE
		offer.talisman = talisman
		offer.weight = talisman.weight
		candidates.append(offer)

	var utility_stacks: Dictionary = context.get("utility_stacks", {})
	var luck := float(context.get("luck", 0.0))
	for resource in utility_definitions:
		var utility := resource as UtilityDefinition
		if utility == null or not utility.enabled or utility.id.is_empty():
			continue
		if utility.max_stack > 0 and int(utility_stacks.get(utility.id, 0)) >= utility.max_stack:
			continue
		var offer := RewardOffer.new()
		offer.category = RewardOffer.Category.UTILITY
		offer.utility = utility
		_configure_utility_offer(offer, utility, luck)
		candidates.append(offer)

	return candidates


func _roll_candidate_index(candidates: Array[RewardOffer]) -> int:
	if candidates.is_empty():
		return -1
	var total_weight := 0
	var weights: Array[int] = []
	for candidate in candidates:
		var scaled_weight := maxi(0, roundi(candidate.weight * 1000.0))
		weights.append(scaled_weight)
		total_weight += scaled_weight
	if total_weight <= 0:
		return _range_i(0, candidates.size() - 1)
	var roll := _range_i(1, total_weight)
	var accumulated := 0
	for index in range(weights.size()):
		accumulated += weights[index]
		if roll <= accumulated:
			return index
	return candidates.size() - 1


func _roll_rarity(offer: RewardOffer, luck: float) -> void:
	var weighted_rarities: Array[int] = []
	var total_weight := 0
	for index in range(RewardOffer.Rarity.size()):
		var base_weight := rarity_weights[index] if index < rarity_weights.size() else 0.0
		var luck_scale := 1.0 + maxf(0.0, luck) * float(index)
		var scaled_weight := maxi(0, roundi(base_weight * luck_scale * 100.0))
		weighted_rarities.append(scaled_weight)
		total_weight += scaled_weight
	var rarity_index := 0
	if total_weight > 0:
		var roll := _range_i(1, total_weight)
		var accumulated := 0
		for index in range(weighted_rarities.size()):
			accumulated += weighted_rarities[index]
			if roll <= accumulated:
				rarity_index = index
				break
	offer.rarity = rarity_index as RewardOffer.Rarity
	offer.rarity_multiplier = rarity_multipliers[rarity_index] if rarity_index < rarity_multipliers.size() else 1.0
	if offer.category == RewardOffer.Category.WEAPON_UPGRADE and offer.weapon_upgrade != null:
		offer.weapon_upgrade_value = offer.weapon_upgrade.get_rarity_value(
			rarity_index,
			weapon_percent_upgrade_values,
			weapon_count_upgrade_values
		)
	elif offer.category in [RewardOffer.Category.TALISMAN_NEW, RewardOffer.Category.TALISMAN_UPGRADE] \
			and offer.talisman != null:
		var rarity_percent := talisman_percent_upgrade_values[rarity_index] \
			if rarity_index < talisman_percent_upgrade_values.size() else 0.0
		offer.talisman_upgrade_value = offer.talisman.get_upgrade_value(rarity_percent)


func _assign_offer_rarity(offer: RewardOffer, luck: float) -> void:
	if offer.category == RewardOffer.Category.UTILITY:
		return
	_roll_rarity(offer, luck)


func _configure_utility_offer(offer: RewardOffer, utility: UtilityDefinition, luck: float) -> void:
	var rarity_index := clampi(int(utility.rarity), 0, RewardOffer.Rarity.size() - 1)
	var rarity_weight := utility_rarity_weight_multipliers[rarity_index] \
		if rarity_index < utility_rarity_weight_multipliers.size() else 1.0
	var luck_boost := 1.0 + maxf(0.0, luck) * float(rarity_index)
	offer.rarity = rarity_index as RewardOffer.Rarity
	offer.rarity_multiplier = 1.0
	offer.weight = utility.weight * maxf(0.0, rarity_weight) * luck_boost


func _add_fallback_offers(
	offers: Array[RewardOffer],
	context: Dictionary,
	target_count: int
) -> void:
	var luck := float(context.get("luck", 0.0))
	var fallback_candidates := _get_valid_fallback_candidates(context, offers)
	while offers.size() < target_count:
		if fallback_candidates.is_empty():
			fallback_candidates = _get_valid_fallback_candidates(context, [])
		if fallback_candidates.is_empty():
			push_warning("RewardPoolConfig tidak memiliki fallback reward yang valid.")
			return
		var selected_index := _roll_candidate_index(fallback_candidates)
		var offer := fallback_candidates.pop_at(selected_index) as RewardOffer
		_assign_offer_rarity(offer, luck)
		offers.append(offer)


func _get_valid_fallback_candidates(
	context: Dictionary,
	existing_offers: Array
) -> Array[RewardOffer]:
	var candidates: Array[RewardOffer] = []
	var existing_ids: Array[String] = []
	for existing_offer in existing_offers:
		if existing_offer is RewardOffer:
			existing_ids.append((existing_offer as RewardOffer).get_unique_id())
	var utility_stacks: Dictionary = context.get("utility_stacks", {})
	for resource in fallback_definitions:
		var utility := resource as UtilityDefinition
		if utility == null or not utility.enabled or utility.id.is_empty():
			continue
		if utility.max_stack > 0 and int(utility_stacks.get(utility.id, 0)) >= utility.max_stack:
			continue
		var offer := RewardOffer.new()
		offer.category = RewardOffer.Category.UTILITY
		offer.utility = utility
		_configure_utility_offer(offer, utility, float(context.get("luck", 0.0)))
		if existing_ids.has(offer.get_unique_id()):
			continue
		candidates.append(offer)
	return candidates


func _range_i(min_value: int, max_value: int) -> int:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var rng := scene_tree.root.get_node_or_null("Rng") if scene_tree != null else null
	if rng == null:
		push_warning("Autoload Rng tidak tersedia; memakai nilai minimum deterministik.")
		return min_value
	return int(rng.call("range_i", min_value, max_value))
