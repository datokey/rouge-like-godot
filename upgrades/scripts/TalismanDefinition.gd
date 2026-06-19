extends ModifierDefinition
class_name TalismanDefinition

@export_range(1, 99, 1) var max_level := 99
@export var compatibility_tags: Array[StringName] = []
@export_group("Rarity Upgrade")
# Nilai rarity selalu berupa persen. Scale mengubahnya ke unit stat bila perlu
# (contoh: 0.02 * 100 = 2 armor), tanpa mengubah Resource saat runtime.
@export var rarity_value_scale := 1.0
# 0 berarti tidak dibatasi di level Talisman. Cap weapon tetap berada di
# WeaponDefinition (minimum fire interval, projectile count, dan sebagainya).
@export_range(0.0, 1000.0, 0.01) var total_bonus_cap := 0.0
@export_group("")


func is_compatible(owned_tags: Array) -> bool:
	if compatibility_tags.is_empty():
		return true

	for required_tag in compatibility_tags:
		if owned_tags.has(required_tag):
			return true

	return false


func get_upgrade_value(rarity_percent: float) -> float:
	return rarity_percent * rarity_value_scale


func clamp_total_bonus(total: float) -> float:
	if total_bonus_cap <= 0.0:
		return total
	return clampf(total, -total_bonus_cap, total_bonus_cap)


func is_bonus_capped(total: float) -> bool:
	return total_bonus_cap > 0.0 and absf(total) >= total_bonus_cap - 0.00001
