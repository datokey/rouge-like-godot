extends Resource
class_name AbilityPoolConfig

enum RollMode {
	WEIGHTED,
	CATEGORY_SLOTS,
}

@export var offer_count := 3
@export var roll_mode: RollMode = RollMode.WEIGHTED
@export var category_slots: Array[String] = ["Safe", "Risky", "Weird"]
@export var abilities: Array[Resource] = []
@export var fallback_abilities: Array[Resource] = []


func get_valid_abilities(
	excluded_ids: Array[String] = [],
	taken_counts: Dictionary = {},
	offer_context: Dictionary = {}
) -> Array[AbilityDefinition]:
	var context := offer_context.duplicate(true)
	_merge_legacy_selection_context(context, excluded_ids, taken_counts)

	var valid_abilities: Array[AbilityDefinition] = []
	for ability in abilities:
		var ability_definition := ability as AbilityDefinition
		if ability_definition == null:
			continue
		if not _is_reward_valid(ability_definition, context):
			continue

		valid_abilities.append(ability_definition)

	return valid_abilities


func roll_offers(
	max_offer_count: int,
	excluded_ids: Array[String] = [],
	taken_counts: Dictionary = {},
	offer_context: Dictionary = {}
) -> Array[AbilityDefinition]:
	var context := offer_context.duplicate(true)
	_merge_legacy_selection_context(context, excluded_ids, taken_counts)

	var target_count := mini(offer_count, max_offer_count)
	var available_abilities := get_valid_abilities([], {}, context)
	var offers: Array[AbilityDefinition] = []
	if roll_mode == RollMode.CATEGORY_SLOTS:
		offers = _roll_category_slots(available_abilities, target_count)
	else:
		offers = _roll_weighted_without_duplicates(available_abilities, target_count)

	if offers.size() < target_count:
		_add_fallback_offers(offers, context, target_count)

	return offers


func _merge_legacy_selection_context(
	context: Dictionary,
	excluded_ids: Array[String],
	taken_counts: Dictionary
) -> void:
	var selected_reward_ids: Array = context.get("selected_reward_ids", [])
	for ability_id in excluded_ids:
		if not selected_reward_ids.has(ability_id):
			selected_reward_ids.append(ability_id)
	context["selected_reward_ids"] = selected_reward_ids

	var modifier_stack_counts: Dictionary = context.get("modifier_stack_counts", {})
	for ability_id in taken_counts.keys():
		var current_count := int(modifier_stack_counts.get(ability_id, 0))
		modifier_stack_counts[ability_id] = maxi(current_count, int(taken_counts[ability_id]))
	context["modifier_stack_counts"] = modifier_stack_counts


func _is_reward_valid(ability: AbilityDefinition, context: Dictionary) -> bool:
	if ability.id.is_empty():
		return false
	if not ability.is_eligible(context):
		return false

	var category := ability.get_reward_category(context)
	match category:
		AbilityDefinition.RewardCategory.WEAPON_NEW:
			return _can_offer_new_weapon(ability, context)
		AbilityDefinition.RewardCategory.WEAPON_UPGRADE:
			return _can_offer_weapon_upgrade(ability, context)
		AbilityDefinition.RewardCategory.SKILL_NEW:
			return _can_offer_new_skill(ability, context)
		AbilityDefinition.RewardCategory.SKILL_UPGRADE:
			return _can_offer_skill_upgrade(ability, context)
		AbilityDefinition.RewardCategory.WEAPON_MODIFIER:
			return _can_offer_modifier(ability, context) and _has_required_weapon(ability, context)
		AbilityDefinition.RewardCategory.SKILL_MODIFIER:
			return _can_offer_modifier(ability, context) and _has_required_skill(ability, context)
		AbilityDefinition.RewardCategory.GLOBAL_MODIFIER:
			return _can_offer_modifier(ability, context)
		_:
			return false


func _can_offer_new_weapon(ability: AbilityDefinition, context: Dictionary) -> bool:
	var weapon_id := ability.get_weapon_id()
	if weapon_id.is_empty():
		return false
	if _is_weapon_owned(weapon_id, context):
		return false

	return bool(context.get("can_add_weapon", true))


func _can_offer_weapon_upgrade(ability: AbilityDefinition, context: Dictionary) -> bool:
	var weapon_id := ability.get_weapon_id()
	if weapon_id.is_empty():
		return false
	if not _is_weapon_owned(weapon_id, context):
		return false

	var owned_levels: Dictionary = context.get("owned_weapon_levels", {})
	var owned_max_levels: Dictionary = context.get("owned_weapon_max_levels", {})
	var current_level := int(owned_levels.get(weapon_id, 1))
	var max_level := int(owned_max_levels.get(weapon_id, 1))
	return current_level < max_level


func _can_offer_new_skill(ability: AbilityDefinition, context: Dictionary) -> bool:
	if not bool(context.get("skill_manager_active", false)):
		return false

	var skill_id := ability.get_skill_id()
	if skill_id.is_empty():
		return false
	if _is_skill_owned(skill_id, context):
		return false

	return bool(context.get("can_add_skill", false))


func _can_offer_skill_upgrade(ability: AbilityDefinition, context: Dictionary) -> bool:
	if not bool(context.get("skill_manager_active", false)):
		return false

	var skill_id := ability.get_skill_id()
	if skill_id.is_empty():
		return false
	if not _is_skill_owned(skill_id, context):
		return false

	var owned_levels: Dictionary = context.get("owned_skill_levels", {})
	var owned_max_levels: Dictionary = context.get("owned_skill_max_levels", {})
	var current_level := int(owned_levels.get(skill_id, 1))
	var max_level := int(owned_max_levels.get(skill_id, 1))
	return current_level < max_level


func _can_offer_modifier(ability: AbilityDefinition, context: Dictionary) -> bool:
	var selected_reward_ids: Array = context.get("selected_reward_ids", [])
	var modifier_stack_counts: Dictionary = context.get("modifier_stack_counts", {})

	if not ability.stackable and selected_reward_ids.has(ability.id):
		return false

	var current_stack := int(modifier_stack_counts.get(ability.id, 0))
	if not ability.stackable and current_stack > 0:
		return false
	if ability.max_stack > 0 and current_stack >= ability.max_stack:
		return false

	return true


func _has_required_weapon(ability: AbilityDefinition, context: Dictionary) -> bool:
	var target_weapon_id := ability.get_target_weapon_id()
	if not target_weapon_id.is_empty():
		return _is_weapon_owned(target_weapon_id, context) and _weapon_supports_ability(
			target_weapon_id,
			ability,
			context
		)

	var owned_weapon_ids: Array = context.get("owned_weapon_ids", [])
	for weapon_id in owned_weapon_ids:
		if _weapon_supports_ability(str(weapon_id), ability, context):
			return true

	return false


func _weapon_supports_ability(
	weapon_id: String,
	ability: AbilityDefinition,
	context: Dictionary
) -> bool:
	var capabilities_by_weapon: Dictionary = context.get(
		"owned_weapon_modifier_capabilities",
		{}
	)
	# Context lama tidak membawa capability; pertahankan perilakunya agar kompatibel.
	if not capabilities_by_weapon.has(weapon_id):
		return true

	var supported_keys: Array = capabilities_by_weapon.get(weapon_id, [])
	for modifier_key in ability.get_weapon_modifier_keys():
		if not supported_keys.has(modifier_key):
			return false

	return true


func _has_required_skill(ability: AbilityDefinition, context: Dictionary) -> bool:
	var target_skill_id := ability.get_target_skill_id()
	if target_skill_id.is_empty():
		var owned_skill_ids: Array = context.get("owned_skill_ids", [])
		return not owned_skill_ids.is_empty()

	return _is_skill_owned(target_skill_id, context)


func _is_weapon_owned(weapon_id: String, context: Dictionary) -> bool:
	var owned_weapon_levels: Dictionary = context.get("owned_weapon_levels", {})
	if owned_weapon_levels.has(weapon_id):
		return true

	var owned_weapon_ids: Array = context.get("owned_weapon_ids", [])
	return owned_weapon_ids.has(weapon_id)


func _is_skill_owned(skill_id: String, context: Dictionary) -> bool:
	var owned_skill_levels: Dictionary = context.get("owned_skill_levels", {})
	if owned_skill_levels.has(skill_id):
		return true

	var owned_skill_ids: Array = context.get("owned_skill_ids", [])
	return owned_skill_ids.has(skill_id)


func _roll_weighted_without_duplicates(
	candidates: Array[AbilityDefinition],
	target_count: int
) -> Array[AbilityDefinition]:
	var offers: Array[AbilityDefinition] = []
	var available := candidates.duplicate()
	var roll_count := mini(target_count, available.size())

	for _index in range(roll_count):
		var selected_index := _roll_weighted_index(available)
		if selected_index < 0:
			break

		offers.append(available[selected_index])
		available.remove_at(selected_index)

	return offers


func _roll_weighted_index(candidates: Array[AbilityDefinition]) -> int:
	var total_weight := 0
	var scaled_weights: Array[int] = []
	for ability in candidates:
		var scaled_weight := maxi(0, roundi(ability.get_weight() * 1000.0))
		scaled_weights.append(scaled_weight)
		total_weight += scaled_weight

	if total_weight <= 0:
		return Rng.range_i(0, candidates.size() - 1)

	var roll := Rng.range_i(1, total_weight)
	var accumulated_weight := 0
	for index in range(candidates.size()):
		accumulated_weight += int(scaled_weights[index])
		if roll <= accumulated_weight:
			return index

	return candidates.size() - 1


func _add_fallback_offers(
	offers: Array[AbilityDefinition],
	context: Dictionary,
	target_count: int
) -> void:
	var fallback_candidates := _get_valid_fallback_candidates(context)
	for existing_offer in offers:
		fallback_candidates.erase(existing_offer)

	var fallback_offers := _roll_weighted_without_duplicates(
		fallback_candidates,
		target_count - offers.size()
	)
	offers.append_array(fallback_offers)


func _get_valid_fallback_candidates(context: Dictionary) -> Array[AbilityDefinition]:
	var candidates: Array[AbilityDefinition] = []
	for fallback in fallback_abilities:
		var ability := fallback as AbilityDefinition
		if ability == null:
			continue
		if not _is_reward_valid(ability, context):
			continue
		candidates.append(ability)

	if not candidates.is_empty():
		return candidates

	for ability_resource in abilities:
		var ability := ability_resource as AbilityDefinition
		if ability == null:
			continue
		if ability.get_reward_category(context) != AbilityDefinition.RewardCategory.GLOBAL_MODIFIER:
			continue
		if not _can_offer_modifier(ability, context):
			continue
		candidates.append(ability)

	return candidates


func _roll_category_slots(
	candidates: Array[AbilityDefinition],
	target_count: int
) -> Array[AbilityDefinition]:
	var offers: Array[AbilityDefinition] = []
	var available := candidates.duplicate()

	for category_name in category_slots:
		if offers.size() >= target_count:
			break

		var category_candidates: Array[AbilityDefinition] = []
		for ability in available:
			if ability.category == category_name:
				category_candidates.append(ability)

		var category_offer := _roll_weighted_without_duplicates(category_candidates, 1)
		if category_offer.is_empty():
			continue

		offers.append(category_offer[0])
		available.erase(category_offer[0])

	if offers.size() < target_count:
		offers.append_array(_roll_weighted_without_duplicates(
			available,
			target_count - offers.size()
		))

	return offers
