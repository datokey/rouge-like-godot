extends RefCounted
class_name WeaponInstance

var definition: Resource
var level := 1
var owner_node: Node2D
var modifier_manager
var upgrade_stacks: Dictionary = {}
var local_flat_modifiers: Dictionary = {}
var local_percent_modifiers: Dictionary = {}
var is_active := true
var active_damage_sources: Array[Node] = []


func setup(new_definition: Resource, new_owner_node: Node2D, new_modifier_manager, start_level: int = 1) -> void:
	definition = new_definition
	owner_node = new_owner_node
	modifier_manager = new_modifier_manager
	level = maxi(1, start_level)
	is_active = true
	active_damage_sources.clear()


func deactivate() -> void:
	if not is_active:
		return
	is_active = false
	for damage_source in active_damage_sources.duplicate():
		if is_instance_valid(damage_source):
			damage_source.queue_free()
	active_damage_sources.clear()


func register_damage_source(damage_source: Node) -> void:
	if damage_source == null:
		return
	if not is_active:
		damage_source.queue_free()
		return
	if not active_damage_sources.has(damage_source):
		active_damage_sources.append(damage_source)


func unregister_damage_source(damage_source: Node) -> void:
	active_damage_sources.erase(damage_source)


func apply_damage(target: Node, amount: int, direction: Vector2, hit_position: Vector2) -> bool:
	if not is_active or amount <= 0 or not is_instance_valid(target):
		return false
	if not target.has_method("take_damage"):
		return false
	target.call("take_damage", amount, direction, hit_position)
	on_damage_dealt(amount)
	return true


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
	if not is_active:
		return 0
	var base_damage := _get_float("base_damage", 0.0)
	var damage_per_level := _get_float("damage_per_level", 0.0)
	var level_bonus := damage_per_level * float(level - 1)
	var damage := maxi(0, roundi(_apply_modifiers(base_damage + level_bonus, &"weapon.damage")))
	if _roll_critical_hit():
		damage = roundi(float(damage) * (1.0 + _get_critical_damage()))
	return damage


func get_cooldown() -> float:
	var base_cooldown := _get_float("base_cooldown", 1.0)
	var reduction := _get_float("cooldown_reduction_per_level", 0.0) * float(level - 1)
	var cooldown := maxf(0.05, base_cooldown - reduction)
	cooldown = _apply_modifiers(cooldown, &"weapon.cooldown")
	return maxf(0.05, _apply_modifiers(cooldown, &"weapon.attack_speed"))


func get_projectile_count() -> int:
	var base_count := _get_int("base_projectile_count", 1)
	var level_bonus := _get_int("projectile_count_per_level", 0) * (level - 1)
	var modifier := roundi(_get_flat_modifier(&"weapon.projectile_count"))
	return maxi(1, base_count + level_bonus + modifier)


func get_projectile_size() -> float:
	return maxf(0.1, _apply_modifiers(1.0, &"weapon.projectile_size"))


func get_projectile_speed() -> float:
	var base_speed := _get_float("base_projectile_speed", 300.0)
	var speed_per_level := _get_float("projectile_speed_per_level", 0.0)
	return maxf(1.0, _apply_modifiers(base_speed + speed_per_level * float(level - 1), &"weapon.projectile_speed"))


func get_attack_range() -> float:
	return maxf(0.0, _apply_modifiers(_get_float("base_range", 300.0), &"weapon.range"))


func get_summon_cooldown() -> float:
	var base_cooldown := _get_float("base_cooldown", 1.0)
	var reduction := _get_float("cooldown_reduction_per_level", 0.0) * float(level - 1)
	return maxf(0.05, _apply_modifiers(base_cooldown - reduction, &"weapon.summon_cooldown"))


func get_summon_max_active() -> int:
	var base_count := _get_int("max_active_minions", 1)
	var modifier := roundi(_get_flat_modifier(&"weapon.summon_count"))
	return maxi(0, base_count + modifier)


func get_summon_lifetime() -> float:
	return maxf(0.0, _apply_modifiers(_get_float("minion_lifetime", 25.0), &"weapon.summon_lifetime"))


func get_summon_damage_multiplier() -> float:
	return maxf(0.0, _get_float("minion_damage_multiplier", 0.7))


func get_summon_damage() -> int:
	var base_damage := float(get_damage()) * get_summon_damage_multiplier()
	return maxi(1, roundi(_apply_modifiers(base_damage, &"weapon.summon_damage")))


func get_summon_attack_cooldown() -> float:
	var base_interval := _get_float("minion_attack_cooldown", 1.5)
	var interval := _apply_modifiers(base_interval, &"weapon.summon_attack_cooldown")
	return maxf(0.05, _apply_modifiers(interval, &"weapon.attack_speed"))


func get_summon_projectile_speed() -> float:
	var base_speed := _get_float("minion_projectile_speed", 400.0)
	return maxf(1.0, _apply_modifiers(base_speed, &"weapon.projectile_speed"))


func get_summon_orbit_radius() -> float:
	return maxf(0.0, _get_float("minion_orbit_radius", 60.0))


func get_summon_minion_scene() -> PackedScene:
	if definition == null:
		return null
	return definition.get("minion_scene") as PackedScene


func get_summon_projectile_scene() -> PackedScene:
	if definition == null:
		return null
	return definition.get("minion_projectile_scene") as PackedScene


func get_aura_radius() -> float:
	var base_radius := _get_float("aura_radius", _get_float("base_range", 0.0))
	var radius_per_level := _get_float("aura_radius_per_level", 0.0)
	var radius := base_radius + radius_per_level * float(level - 1)
	return maxf(0.0, _apply_modifiers(radius, &"weapon.aura_radius"))


func get_aura_tick_interval() -> float:
	var base_interval := _get_float("tick_interval", _get_float("base_cooldown", 1.0))
	return maxf(0.05, _apply_modifiers(base_interval, &"weapon.aura_tick_interval"))


func get_aura_tick_damage_multiplier() -> float:
	return maxf(0.0, _get_float("tick_damage_multiplier", 1.0))


func get_aura_slow_percent() -> float:
	return clampf(_apply_modifiers(_get_float("slow_percent", 0.0), &"weapon.aura_slow"), 0.0, 1.0)


func get_aura_slow_duration() -> float:
	return maxf(0.0, _get_float("slow_duration", 0.0))


func is_aura_knockback_enabled() -> bool:
	if definition == null:
		return false

	return bool(definition.get("enable_knockback"))


func get_beam_duration() -> float:
	var base_duration := _get_float("beam_duration", 1.2)
	var duration_per_level := _get_float("beam_duration_per_level", 0.0)
	return maxf(0.05, _apply_modifiers(base_duration + duration_per_level * float(level - 1), &"weapon.beam_duration"))


func get_beam_tick_interval() -> float:
	var base_interval := _get_float("beam_tick_interval", 0.2)
	var reduction := _get_float("beam_tick_interval_reduction_per_level", 0.0) * float(level - 1)
	return maxf(0.03, _apply_modifiers(base_interval - reduction, &"weapon.beam_tick_interval"))


func get_beam_width() -> float:
	return maxf(1.0, _apply_modifiers(_get_float("beam_width", 5.0), &"weapon.beam_width"))


func get_beam_count() -> int:
	var base_count := _get_int("base_projectile_count", 1)
	var level_bonus := _get_int("projectile_count_per_level", 0) * (level - 1)
	return maxi(1, base_count + level_bonus + roundi(_get_flat_modifier(&"weapon.beam_count")))


func get_beam_pierce_count() -> int:
	return maxi(0, _get_int("pierce_count", 0))


func get_beam_max_collision_results() -> int:
	return maxi(1, _get_int("max_collision_results", 256))


func get_spread_angle_degrees() -> float:
	return clampf(_get_float("spread_angle_degrees", 8.0), 0.0, 90.0)


func get_beam_color() -> Color:
	if definition == null:
		return Color(0.35, 0.9, 1.0, 0.9)

	var start_color: Color = definition.get("beam_start_color")
	var end_color: Color = definition.get("beam_end_color")
	var color_max_level := _get_int("beam_color_max_level", 0)
	if color_max_level <= 0:
		color_max_level = _get_int("max_level", 1)

	var color_progress := 1.0
	if color_max_level > 1:
		color_progress = clampf(
			float(level - 1) / float(color_max_level - 1),
			0.0,
			1.0
		)
	return start_color.lerp(end_color, color_progress)


func can_apply_stat_upgrade(upgrade: WeaponUpgradeDefinition) -> bool:
	if upgrade == null or upgrade.id.is_empty():
		return false
	return int(upgrade_stacks.get(upgrade.id, 0)) < upgrade.max_stack


func apply_stat_upgrade(upgrade: WeaponUpgradeDefinition, rarity_multiplier: float) -> bool:
	if not can_apply_stat_upgrade(upgrade):
		return false
	var modifiers := local_flat_modifiers
	if upgrade.value_type == ModifierDefinition.ValueType.PERCENT:
		modifiers = local_percent_modifiers
	modifiers[upgrade.modifier_key] = float(modifiers.get(upgrade.modifier_key, 0.0)) \
		+ upgrade.get_scaled_value(rarity_multiplier)
	upgrade_stacks[upgrade.id] = int(upgrade_stacks.get(upgrade.id, 0)) + 1
	return true


func get_upgrade_stacks() -> Dictionary:
	return upgrade_stacks.duplicate(true)


func on_damage_dealt(amount: int) -> void:
	if not is_active or amount <= 0 or owner_node == null or not owner_node.has_method("heal"):
		return
	var life_steal := _get_life_steal()
	if life_steal <= 0.0:
		return
	owner_node.call("heal", maxi(1, roundi(float(amount) * life_steal)))


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


func _apply_modifiers(base_value: float, modifier_key: StringName) -> float:
	var with_local := (base_value + float(local_flat_modifiers.get(modifier_key, 0.0))) \
		* (1.0 + float(local_percent_modifiers.get(modifier_key, 0.0)))
	if modifier_manager == null:
		return with_local
	if modifier_manager.has_method("apply_weapon_modifiers"):
		return float(modifier_manager.call(
			"apply_weapon_modifiers",
			with_local,
			modifier_key,
			_get_compatibility_tags()
		))
	if modifier_manager.has_method("apply_modifiers"):
		return float(modifier_manager.call("apply_modifiers", with_local, modifier_key))
	return with_local


func _get_flat_modifier(modifier_key: StringName) -> float:
	var total := float(local_flat_modifiers.get(modifier_key, 0.0))
	if modifier_manager == null:
		return total
	if modifier_manager.has_method("get_weapon_flat_modifier"):
		return total + float(modifier_manager.call(
			"get_weapon_flat_modifier",
			modifier_key,
			_get_compatibility_tags()
		))
	if modifier_manager.has_method("get_flat_modifier"):
		return total + float(modifier_manager.call("get_flat_modifier", modifier_key))
	return total


func _get_compatibility_tags() -> Array:
	if definition == null:
		return []
	return definition.get("compatibility_tags") as Array


func _roll_critical_hit() -> bool:
	if modifier_manager == null or not modifier_manager.has_method("get_critical_chance"):
		return false
	var chance := float(modifier_manager.call("get_critical_chance", _get_compatibility_tags()))
	if chance <= 0.0:
		return false
	var scene_tree := Engine.get_main_loop() as SceneTree
	var rng := scene_tree.root.get_node_or_null("Rng") if scene_tree != null else null
	return rng != null and bool(rng.call("chance", chance))


func _get_critical_damage() -> float:
	if modifier_manager == null or not modifier_manager.has_method("get_critical_damage"):
		return 0.0
	return float(modifier_manager.call("get_critical_damage", _get_compatibility_tags()))


func _get_life_steal() -> float:
	if modifier_manager == null or not modifier_manager.has_method("get_life_steal"):
		return 0.0
	return float(modifier_manager.call("get_life_steal", _get_compatibility_tags()))
