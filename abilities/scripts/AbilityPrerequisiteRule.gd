extends AbilityEligibilityRule
class_name AbilityPrerequisiteRule

@export_range(1, 999, 1) var minimum_player_level := 1
@export_range(0, 999, 1) var maximum_player_level := 0
@export var required_card_ids: Array[String] = []
@export var blocked_card_ids: Array[String] = []
@export var required_weapon_ids: Array[String] = []
@export var required_skill_ids: Array[String] = []


func is_satisfied(context: Dictionary) -> bool:
	var player_level := int(context.get("player_level", 1))
	if player_level < minimum_player_level:
		return false
	if maximum_player_level > 0 and player_level > maximum_player_level:
		return false

	var selected_counts: Dictionary = context.get("selected_reward_counts", {})
	for card_id in required_card_ids:
		if int(selected_counts.get(card_id, 0)) <= 0:
			return false
	for card_id in blocked_card_ids:
		if int(selected_counts.get(card_id, 0)) > 0:
			return false

	var owned_weapon_ids: Array = context.get("owned_weapon_ids", [])
	for weapon_id in required_weapon_ids:
		if not owned_weapon_ids.has(weapon_id):
			return false

	var owned_skill_ids: Array = context.get("owned_skill_ids", [])
	for skill_id in required_skill_ids:
		if not owned_skill_ids.has(skill_id):
			return false

	return true


func get_failure_reason(context: Dictionary) -> String:
	if is_satisfied(context):
		return ""
	return "Card prerequisites are not satisfied."
