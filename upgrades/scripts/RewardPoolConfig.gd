extends Resource
class_name RewardPoolConfig

@export_range(1, 8, 1) var offer_count := 3
@export var weapon_definitions: Array[Resource] = []
@export var talisman_definitions: Array[Resource] = []
@export var utility_definitions: Array[Resource] = []
@export var fallback_definitions: Array[Resource] = []
@export var rarity_weights: Array[float] = [70.0, 20.0, 7.0, 2.5, 0.5]
@export var rarity_multipliers: Array[float] = [1.0, 1.15, 1.3, 1.5, 2.0]


func roll_offers(context: Dictionary, max_offer_count: int) -> Array[RewardOffer]:
	var candidates := get_valid_candidates(context)
	var offers: Array[RewardOffer] = []
	var target_count := mini(offer_count, max_offer_count)
	while offers.size() < target_count and not candidates.is_empty():
		var candidate_index := _roll_candidate_index(candidates)
		if candidate_index < 0:
			break
		var offer := candidates.pop_at(candidate_index) as RewardOffer
		_roll_rarity(offer, float(context.get("luck", 0.0)))
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
	var upgrade_stacks: Dictionary = context.get("weapon_upgrade_stacks", {})
	for weapon_id_value in owned_weapon_ids:
		var weapon_id := str(weapon_id_value)
		var definition := owned_definitions.get(weapon_id) as WeaponDefinition
		if definition == null:
			continue
		var weapon_stacks: Dictionary = upgrade_stacks.get(weapon_id, {})
		for resource in definition.upgrade_options:
			var upgrade := resource as WeaponUpgradeDefinition
			if upgrade == null or upgrade.id.is_empty():
				continue
			if int(weapon_stacks.get(upgrade.id, 0)) >= upgrade.max_stack:
				continue
			var offer := RewardOffer.new()
			offer.category = RewardOffer.Category.WEAPON_UPGRADE
			offer.weapon_definition = definition
			offer.weapon_id = weapon_id
			offer.weapon_upgrade = upgrade
			offer.weight = upgrade.weight
			candidates.append(offer)

	var owned_talisman_levels: Dictionary = context.get("owned_talisman_levels", {})
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
		var offer := RewardOffer.new()
		offer.category = RewardOffer.Category.TALISMAN_NEW if current_level == 0 else RewardOffer.Category.TALISMAN_UPGRADE
		offer.talisman = talisman
		offer.weight = talisman.weight
		candidates.append(offer)

	var utility_levels: Dictionary = context.get("utility_levels", {})
	for resource in utility_definitions:
		var utility := resource as UtilityDefinition
		if utility == null or not utility.enabled or utility.id.is_empty():
			continue
		if utility.max_level > 0 and int(utility_levels.get(utility.id, 0)) >= utility.max_level:
			continue
		var offer := RewardOffer.new()
		offer.category = RewardOffer.Category.UTILITY
		offer.utility = utility
		offer.weight = utility.weight
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
		_roll_rarity(offer, luck)
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
	var utility_levels: Dictionary = context.get("utility_levels", {})
	for resource in fallback_definitions:
		var utility := resource as UtilityDefinition
		if utility == null or not utility.enabled or utility.id.is_empty():
			continue
		if utility.max_level > 0 and int(utility_levels.get(utility.id, 0)) >= utility.max_level:
			continue
		var offer := RewardOffer.new()
		offer.category = RewardOffer.Category.UTILITY
		offer.utility = utility
		offer.weight = utility.weight
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
