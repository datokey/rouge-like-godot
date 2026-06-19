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


func apply_damage(
	target: Node,
	amount: int,
	direction: Vector2,
	hit_position: Vector2,
	is_critical: bool = false
) -> bool:
	if not is_active or amount <= 0 or not is_instance_valid(target):
		return false
	if not target.has_method("take_damage"):
		return false
	target.call("take_damage", amount, direction, hit_position, is_critical, get_damage_source_type())
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
	return int(get_damage_result().get("amount", 0))


func get_damage_result() -> Dictionary:
	if not is_active:
		return {"amount": 0, "is_critical": false}
	var damage := get_damage_preview()
	var is_critical := _roll_critical_hit()
	if is_critical:
		damage = roundi(float(damage) * (1.0 + _get_critical_damage()))
	return {"amount": damage, "is_critical": is_critical}


func get_damage_preview() -> int:
	var base_damage := _get_float("base_damage", 0.0)
	var damage_per_level := _get_float("damage_per_level", 0.0)
	var level_bonus := damage_per_level * float(level - 1)
	return maxi(0, roundi(_apply_modifiers(base_damage + level_bonus, &"weapon.damage")))


func get_cooldown() -> float:
	var base_cooldown := _get_float("base_cooldown", 1.0)
	var reduction := _get_float("cooldown_reduction_per_level", 0.0) * float(level - 1)
	var minimum_interval := _get_float("minimum_fire_interval", 0.05)
	var cooldown := maxf(minimum_interval, base_cooldown - reduction)
	return maxf(minimum_interval, _apply_modifiers_with_talisman_alias(
		cooldown,
		&"weapon.cooldown",
		&"weapon.attack_speed"
	))


func get_projectile_count() -> int:
	var base_count := _get_int("base_projectile_count", 1)
	var level_bonus := _get_int("projectile_count_per_level", 0) * (level - 1)
	var max_count := _get_int("max_minion_projectile_count", _get_int("max_projectile_count", 100))
	return clampi(
		_apply_count_modifiers(base_count + level_bonus, &"weapon.projectile_count"),
		1,
		maxi(1, max_count)
	)


func get_projectile_size() -> float:
	var base_size := _get_float("base_projectile_size", 1.0)
	var size_per_level := _get_float("projectile_size_per_level", 0.0)
	var minimum_size := maxf(0.01, _get_float("min_projectile_size", 0.1))
	var maximum_size := maxf(minimum_size, _get_float("max_projectile_size", 10.0))
	var scaled_size := base_size + size_per_level * float(level - 1)
	return clampf(
		_apply_modifiers(scaled_size, &"weapon.projectile_size"),
		minimum_size,
		maximum_size
	)


func get_projectile_speed() -> float:
	var base_speed := _get_float("base_projectile_speed", 300.0)
	var speed_per_level := _get_float("projectile_speed_per_level", 0.0)
	return maxf(1.0, _apply_modifiers(base_speed + speed_per_level * float(level - 1), &"weapon.projectile_speed"))


func get_attack_range() -> float:
	var max_range := _get_float("max_attack_range", 1200.0)
	return clampf(_apply_modifiers(_get_float("base_range", 300.0), &"weapon.range"), 0.0, max_range)


func get_summon_cooldown() -> float:
	var base_cooldown := _get_float("base_cooldown", 1.0)
	var reduction := _get_float("cooldown_reduction_per_level", 0.0) * float(level - 1)
	return maxf(0.05, _apply_modifiers(base_cooldown - reduction, &"weapon.summon_cooldown"))


func get_summon_max_active() -> int:
	var base_count := _get_int("max_active_minions", 1)
	return maxi(0, _apply_count_modifiers(base_count, &"weapon.summon_count"))


func get_summon_lifetime() -> float:
	return maxf(0.0, _apply_modifiers(_get_float("minion_lifetime", 25.0), &"weapon.summon_lifetime"))


func get_summon_damage_multiplier() -> float:
	return maxf(0.0, _get_float("minion_damage_multiplier", 0.7))


func get_summon_damage() -> int:
	return int(get_summon_damage_result().get("amount", 0))


func get_summon_damage_result() -> Dictionary:
	var result := get_damage_result()
	var base_damage := float(result.get("amount", 0)) * get_summon_damage_multiplier()
	result["amount"] = maxi(1, roundi(_apply_modifiers(base_damage, &"weapon.summon_damage")))
	return result


func get_damage_source_type() -> StringName:
	if definition == null:
		return &"unknown"
	match int(definition.get("weapon_type")):
		WeaponDefinition.WeaponType.PROJECTILE:
			return &"projectile"
		WeaponDefinition.WeaponType.AURA:
			return &"aura"
		WeaponDefinition.WeaponType.SUMMON:
			return &"summon"
		WeaponDefinition.WeaponType.BEAM:
			return &"beam"
	return &"weapon"


func get_summon_attack_cooldown() -> float:
	var base_interval := _get_float("minion_attack_cooldown", 1.5)
	var minimum_interval := _get_float("minimum_fire_interval", 0.05)
	return maxf(minimum_interval, _apply_modifiers_with_talisman_alias(
		base_interval,
		&"weapon.summon_attack_cooldown",
		&"weapon.attack_speed"
	))


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
	return clampf(
		_apply_modifiers(radius, &"weapon.aura_radius"),
		0.0,
		_get_float("max_aura_radius", 300.0)
	)


func get_aura_tick_interval() -> float:
	var base_interval := _get_float("tick_interval", _get_float("base_cooldown", 1.0))
	return maxf(
		_get_float("minimum_fire_interval", 0.05),
		_apply_modifiers(base_interval, &"weapon.aura_tick_interval")
	)


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
	return clampf(
		_apply_modifiers(_get_float("beam_width", 5.0), &"weapon.beam_width"),
		1.0,
		_get_float("max_beam_width", 40.0)
	)


func get_beam_count() -> int:
	var base_count := _get_int("base_projectile_count", 1)
	var level_bonus := _get_int("projectile_count_per_level", 0) * (level - 1)
	return clampi(
		_apply_count_modifiers(base_count + level_bonus, &"weapon.beam_count"),
		1,
		maxi(1, _get_int("max_beam_count", 6))
	)


func get_pierce_percent() -> float:
	return clampf(
		_get_flat_modifier(&"weapon.pierce_percent"),
		0.0,
		_get_float("max_pierce_percent", 1.0)
	)


func get_projectile_pierce_count() -> int:
	return maxi(0, floori((get_pierce_percent() + 0.00001) / 0.1))


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
	if upgrade == null or upgrade.id.is_empty() or not can_upgrade():
		return false
	return not _has_reached_upgrade_cap(upgrade)


func apply_stat_upgrade(upgrade: WeaponUpgradeDefinition, upgrade_value: float) -> bool:
	if not can_apply_stat_upgrade(upgrade):
		return false
	var modifiers := local_percent_modifiers
	if upgrade.uses_count_value() or upgrade.stat_type == WeaponUpgradeDefinition.StatType.PIERCE:
		modifiers = local_flat_modifiers
	modifiers[upgrade.modifier_key] = float(modifiers.get(upgrade.modifier_key, 0.0)) \
		+ upgrade_value
	upgrade_stacks[upgrade.id] = int(upgrade_stacks.get(upgrade.id, 0)) + 1
	level += 1
	return true


func get_upgrade_stacks() -> Dictionary:
	return upgrade_stacks.duplicate(true)


func _has_reached_upgrade_cap(upgrade: WeaponUpgradeDefinition) -> bool:
	match upgrade.stat_type:
		WeaponUpgradeDefinition.StatType.FIRE_RATE:
			return _get_fire_interval(upgrade.modifier_key) <= _get_float("minimum_fire_interval", 0.05) + 0.00001
		WeaponUpgradeDefinition.StatType.PROJECTILE_COUNT, WeaponUpgradeDefinition.StatType.MINION_PROJECTILE_COUNT:
			return get_projectile_count() >= _get_int(
				"max_minion_projectile_count",
				_get_int("max_projectile_count", 100)
			)
		WeaponUpgradeDefinition.StatType.BEAM_COUNT:
			return get_beam_count() >= _get_int("max_beam_count", 6)
		WeaponUpgradeDefinition.StatType.ATTACK_RANGE:
			return get_attack_range() >= _get_float("max_attack_range", 1200.0) - 0.00001
		WeaponUpgradeDefinition.StatType.PIERCE:
			return get_pierce_percent() >= _get_float("max_pierce_percent", 1.0) - 0.00001
		WeaponUpgradeDefinition.StatType.SIZE:
			return _get_size_stat(upgrade.modifier_key) >= _get_size_cap(upgrade.modifier_key) - 0.00001
	return false


func _get_fire_interval(modifier_key: StringName) -> float:
	match modifier_key:
		&"weapon.aura_tick_interval":
			return get_aura_tick_interval()
		&"weapon.summon_attack_cooldown":
			return get_summon_attack_cooldown()
	return get_cooldown()


func _get_size_stat(modifier_key: StringName) -> float:
	match modifier_key:
		&"weapon.beam_width":
			return get_beam_width()
		&"weapon.aura_radius":
			return get_aura_radius()
	return get_projectile_size()


func _get_size_cap(modifier_key: StringName) -> float:
	match modifier_key:
		&"weapon.beam_width":
			return _get_float("max_beam_width", 40.0)
		&"weapon.aura_radius":
			return _get_float("max_aura_radius", 300.0)
	return _get_float("max_projectile_size", 10.0)


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
	var local_flat := float(local_flat_modifiers.get(modifier_key, 0.0))
	var local_percent := float(local_percent_modifiers.get(modifier_key, 0.0))
	# Weapon dan Talisman sama-sama dihitung dari base stat. Dengan demikian
	# 100 +20% weapon +10% Talisman = 130, bukan 132.
	if modifier_manager != null \
			and modifier_manager.has_method("get_weapon_talisman_percent_modifier"):
		var talisman_flat := float(modifier_manager.call(
			"get_weapon_flat_modifier",
			modifier_key,
			_get_compatibility_tags()
		))
		var talisman_percent := float(modifier_manager.call(
			"get_weapon_talisman_percent_modifier",
			modifier_key,
			_get_compatibility_tags()
		))
		return base_value + local_flat + talisman_flat \
			+ base_value * (local_percent + talisman_percent)
	var with_local := (base_value + local_flat) * (1.0 + local_percent)
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


func _apply_modifiers_with_talisman_alias(
	base_value: float,
	weapon_modifier_key: StringName,
	talisman_modifier_key: StringName
) -> float:
	if modifier_manager != null \
			and modifier_manager.has_method("get_weapon_talisman_percent_modifier"):
		var local_flat := float(local_flat_modifiers.get(weapon_modifier_key, 0.0))
		var local_percent := float(local_percent_modifiers.get(weapon_modifier_key, 0.0))
		var talisman_flat := float(modifier_manager.call(
			"get_weapon_flat_modifier",
			talisman_modifier_key,
			_get_compatibility_tags()
		))
		var talisman_percent := float(modifier_manager.call(
			"get_weapon_talisman_percent_modifier",
			talisman_modifier_key,
			_get_compatibility_tags()
		))
		return base_value + local_flat + talisman_flat \
			+ base_value * (local_percent + talisman_percent)

	# Compatibility untuk modifier manager lama/custom.
	var with_weapon := _apply_modifiers(base_value, weapon_modifier_key)
	return _apply_modifiers(with_weapon, talisman_modifier_key)


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


func _apply_count_modifiers(base_count: int, modifier_key: StringName) -> int:
	var local_flat := float(local_flat_modifiers.get(modifier_key, 0.0))
	var local_percent := float(local_percent_modifiers.get(modifier_key, 0.0))
	if modifier_manager != null \
			and modifier_manager.has_method("get_weapon_talisman_percent_modifier"):
		var talisman_flat := float(modifier_manager.call(
			"get_weapon_flat_modifier",
			modifier_key,
			_get_compatibility_tags()
		))
		var talisman_percent := float(modifier_manager.call(
			"get_weapon_talisman_percent_modifier",
			modifier_key,
			_get_compatibility_tags()
		))
		var talisman_milestones := 0
		if modifier_manager.has_method("get_weapon_talisman_milestone_modifier"):
			talisman_milestones = int(modifier_manager.call(
				"get_weapon_talisman_milestone_modifier",
				modifier_key,
				_get_compatibility_tags()
			))
		return roundi(float(base_count) + local_flat + talisman_flat \
			+ float(base_count) * (local_percent + talisman_percent)) \
			+ talisman_milestones
	return roundi(float(base_count) + _get_flat_modifier(modifier_key))


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
