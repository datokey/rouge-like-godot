extends RefCounted
class_name AbilityRewardApplier


func apply(
	ability: AbilityDefinition,
	rarity: int,
	ability_manager: AbilityManager,
	weapon_manager: WeaponManager,
	skill_manager: SkillManager
) -> bool:
	if ability == null:
		return false

	if ability.is_weapon_reward():
		return weapon_manager != null and weapon_manager.add_weapon(ability.weapon_definition)
	if ability.is_skill_reward():
		return skill_manager != null and skill_manager.add_skill(ability.skill_definition)

	return ability_manager != null and ability_manager.add_ability(ability, rarity)
