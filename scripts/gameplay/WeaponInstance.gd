extends RefCounted
class_name WeaponInstance

var definition: Resource
var level := 1
var owner_node: Node2D
var ability_manager


func setup(new_definition: Resource, new_owner_node: Node2D, new_ability_manager, start_level: int = 1) -> void:
	definition = new_definition
	owner_node = new_owner_node
	ability_manager = new_ability_manager
	level = maxi(1, start_level)


func can_upgrade() -> bool:
	if definition == null:
		return false

	return level < int(definition.get("max_level"))


func upgrade() -> bool:
	if not can_upgrade():
		return false

	level += 1
	return true


func get_weapon_id() -> String:
	if definition == null:
		return ""

	return str(definition.get("id"))


func get_damage() -> int:
	var base_damage := _get_float("base_damage", 0.0)
	var damage_per_level := _get_float("damage_per_level", 0.0)
	var level_bonus := damage_per_level * float(level - 1)
	return maxi(0, roundi(_apply_modifiers(base_damage + level_bonus, &"weapon.damage")))


func get_cooldown() -> float:
	var base_cooldown := _get_float("base_cooldown", 1.0)
	var reduction := _get_float("cooldown_reduction_per_level", 0.0) * float(level - 1)
	var cooldown := maxf(0.05, base_cooldown - reduction)
	return maxf(0.05, _apply_modifiers(cooldown, &"weapon.cooldown"))


func get_projectile_count() -> int:
	var base_count := _get_int("base_projectile_count", 1)
	var level_bonus := _get_int("projectile_count_per_level", 0) * (level - 1)
	var modifier := roundi(_get_flat_modifier(&"weapon.projectile_count"))
	return maxi(1, base_count + level_bonus + modifier)


func get_projectile_speed() -> float:
	var base_speed := _get_float("base_projectile_speed", 300.0)
	var speed_per_level := _get_float("projectile_speed_per_level", 0.0)
	return maxf(1.0, _apply_modifiers(base_speed + speed_per_level * float(level - 1), &"weapon.projectile_speed"))


func get_attack_range() -> float:
	return maxf(0.0, _apply_modifiers(_get_float("base_range", 300.0), &"weapon.range"))


func get_beam_duration() -> float:
	var base_duration := _get_float("beam_duration", 1.2)
	var duration_per_level := _get_float("beam_duration_per_level", 0.0)
	return maxf(0.05, _apply_modifiers(base_duration + duration_per_level * float(level - 1), &"weapon.beam_duration"))


func get_beam_tick_interval() -> float:
	var base_interval := _get_float("beam_tick_interval", 0.2)
	var reduction := _get_float("beam_tick_interval_reduction_per_level", 0.0) * float(level - 1)
	return maxf(0.03, base_interval - reduction)


func get_beam_width() -> float:
	return maxf(1.0, _get_float("beam_width", 5.0))


func _get_float(property_name: String, fallback: float) -> float:
	if definition == null:
		return fallback

	var value: Variant = definition.get(property_name)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)

	return fallback


func _get_int(property_name: String, fallback: int) -> int:
	if definition == null:
		return fallback

	var value: Variant = definition.get(property_name)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return roundi(float(value))

	return fallback


func _get_weapon_damage_percent_modifier() -> float:
	return _get_percent_modifier(&"weapon.damage")


func _get_weapon_attack_speed_percent_modifier() -> float:
	if ability_manager == null or not ability_manager.has_method("get_weapon_attack_speed_percent_modifier"):
		return 0.0

	return float(ability_manager.call("get_weapon_attack_speed_percent_modifier"))


func _get_weapon_projectile_count_modifier() -> float:
	return _get_flat_modifier(&"weapon.projectile_count")


func _apply_modifiers(base_value: float, modifier_key: StringName) -> float:
	if ability_manager == null or not ability_manager.has_method("apply_modifiers"):
		return base_value

	return float(ability_manager.call("apply_modifiers", base_value, modifier_key))


func _get_flat_modifier(modifier_key: StringName) -> float:
	if ability_manager == null or not ability_manager.has_method("get_flat_modifier"):
		return 0.0

	return float(ability_manager.call("get_flat_modifier", modifier_key))


func _get_percent_modifier(modifier_key: StringName) -> float:
	if ability_manager == null or not ability_manager.has_method("get_percent_modifier"):
		return 0.0

	return float(ability_manager.call("get_percent_modifier", modifier_key))
