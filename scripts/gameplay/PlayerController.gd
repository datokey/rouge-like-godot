extends CharacterBody2D

const BuildManagerScript = preload("res://upgrades/scripts/BuildManager.gd")
const WeaponManagerScript = preload("res://scripts/gameplay/WeaponManager.gd")

# Semua angka balancing player diambil dari resource agar mudah diubah dari editor.
@export var config: PlayerConfig
@export var xp_config: XPConfig
@export var starting_weapon: Resource
@export var max_weapon_slots := 4
@export var max_talisman_slots := 4

@onready var pickup_area_collision: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var weapon_holder: Node2D = $WeaponHolder
@onready var magnet_component: Node = $MagnetComponent

var current_hp := 0
var current_xp := 0
var current_level := 1

var upgrade_rerolls := 0
var pickup_radius_bonus := 0.0
var revive_charges := 0
var extra_upgrade_choices := 0
var extra_dash_charges := 0
var elite_kill_heal := 0.0
var damage_to_shield_ratio := 0.0
var utility_max_hp_bonus := 0
var build_manager: BuildManager
var weapon_manager
var weapon_ammo_status: Dictionary = {}
var weapon_reload_status: Dictionary = {}


func _ready() -> void:
	EventBus.reward_selected.connect(_on_reward_selected)
	EventBus.weapon_ammo_changed.connect(_on_weapon_ammo_changed)
	EventBus.weapon_reload_changed.connect(_on_weapon_reload_changed)
	build_manager = BuildManagerScript.new()
	build_manager.max_talisman_slots = max_talisman_slots
	build_manager.setup(self)
	weapon_manager = WeaponManagerScript.new()
	weapon_manager.max_weapon_slots = max_weapon_slots
	weapon_manager.setup(self, weapon_holder, build_manager)
	current_hp = get_max_hp()
	current_xp = 0
	current_level = 1
	sync_pickup_radius()

	# GameState menyimpan nilai global, sedangkan EventBus memberi tahu UI.
	_emit_health_changed()
	_emit_xp_changed()


func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = input_direction * get_move_speed()
	move_and_slide()

	# Auto-shoot sekarang dikelola masing-masing weapon di WeaponHolder.


func get_nearest_enemy_in_range(attack_range: float) -> Node2D:
	var nearest_enemy: Node2D
	var nearest_distance := attack_range

	# Enemy dicari lewat group agar spawner bebas membuat enemy baru kapan saja.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D:
			continue

		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_enemy = enemy
			nearest_distance = distance

	return nearest_enemy


func take_damage(amount: int) -> void:
	var armor := build_manager.get_armor() if build_manager != null else 0
	var final_damage := maxi(0, amount - armor)
	current_hp = maxi(current_hp - final_damage, 0)
	_emit_health_changed()

	if current_hp <= 0:
		if revive_charges > 0:
			revive_charges -= 1
			current_hp = maxi(1, roundi(float(get_max_hp()) * 0.5))
			_emit_health_changed()
			return
		# Player dimatikan lewat mode global dan signal agar UI/gameplay tidak saling tergantung.
		RunManager.lose_run()
		set_physics_process(false)
		modulate = Color(0.45, 0.45, 0.45, 1.0)


func heal(amount: int) -> void:
	if current_hp <= 0:
		return

	current_hp = mini(current_hp + amount, get_max_hp())
	_emit_health_changed()


func add_xp(amount: int) -> void:
	if amount <= 0:
		return

	current_xp += amount
	_check_level_up()
	_emit_xp_changed()


func _check_level_up() -> void:
	while current_xp >= get_xp_required_for_next_level():
		var required_xp := get_xp_required_for_next_level()
		current_xp -= required_xp
		current_level += 1
		_sync_xp_state()
		EventBus.player_level_up.emit(current_level, current_xp, get_xp_required_for_next_level())


func get_move_speed() -> float:
	var base_speed := 0.0
	if config != null:
		base_speed = config.move_speed

	var percent_bonus := build_manager.get_percent_modifier(&"player.move_speed") \
		if build_manager != null else 0.0
	return maxf(0.0, base_speed * (1.0 + percent_bonus))


func get_max_hp() -> int:
	var base_max_hp := 100
	if config != null:
		base_max_hp = config.max_hp

	return maxi(1, base_max_hp + utility_max_hp_bonus)


func increase_current_hp(amount: int) -> void:
	current_hp = clampi(current_hp + maxi(0, amount), 0, get_max_hp())
	_emit_health_changed()


func activate_magnet() -> void:
	if magnet_component == null or not magnet_component.has_method("activate"):
		return

	magnet_component.call("activate")


func get_xp_required_for_next_level() -> int:
	var scaled_requirement := float(xp_config.required_per_level) * pow(xp_config.growth_multiplier, current_level - 1)
	return maxi(1, roundi(scaled_requirement))


func _emit_xp_changed() -> void:
	_sync_xp_state()
	EventBus.player_xp_changed.emit(current_xp, GameState.player_required_xp, current_level)


func _emit_health_changed() -> void:
	GameState.player_max_hp = get_max_hp()
	GameState.player_hp = current_hp
	EventBus.player_health_changed.emit(current_hp, GameState.player_max_hp)


func _sync_xp_state() -> void:
	GameState.player_xp = current_xp
	GameState.player_required_xp = get_xp_required_for_next_level()
	GameState.player_level = current_level


func _on_reward_selected(offer: RewardOffer) -> void:
	if build_manager == null:
		return
	if build_manager.apply_offer(offer, weapon_manager):
		EventBus.player_build_changed.emit()


func _on_weapon_ammo_changed(weapon_id: String, current_ammo: int, capacity: int) -> void:
	weapon_ammo_status[weapon_id] = {
		"current": current_ammo,
		"capacity": capacity,
	}
	EventBus.player_build_changed.emit()


func _on_weapon_reload_changed(
	weapon_id: String,
	is_reloading: bool,
	remaining_time: float,
	duration: float
) -> void:
	weapon_reload_status[weapon_id] = {
		"is_reloading": is_reloading,
		"remaining_time": remaining_time,
		"duration": duration,
	}
	EventBus.player_build_changed.emit()


func get_reward_offer_context() -> Dictionary:
	var context := {"player_level": current_level}

	if weapon_manager == null:
		return context

	context.merge(weapon_manager.get_offer_context(), true)
	if build_manager != null:
		context.merge(build_manager.get_offer_context(
			context.get("owned_compatibility_tags", [])
		), true)

	return context


func equip_starting_weapon(weapon_definition: Resource = null) -> bool:
	if weapon_manager == null:
		return false

	var selected_weapon := weapon_definition
	if selected_weapon == null:
		selected_weapon = starting_weapon
	if selected_weapon == null:
		return false

	starting_weapon = selected_weapon
	var equipped: bool = weapon_manager.add_weapon(selected_weapon)
	if equipped:
		EventBus.player_build_changed.emit()
	return equipped


func get_build_hud_snapshot() -> Dictionary:
	var weapon_entries: Array[Dictionary] = []
	var damage_values: Array[String] = []
	var attack_speed_values: Array[String] = []
	var projectile_values: Array[String] = []
	var beam_count_values: Array[String] = []
	var beam_width_values: Array[String] = []
	var attack_range_values: Array[String] = []
	var pierce_values: Array[String] = []
	var ammo_values: Array[String] = []
	var reload_values: Array[String] = []
	var owned_tags: Array = []
	if weapon_manager != null:
		for instance in weapon_manager.weapons:
			var definition: Resource = instance.definition
			var weapon_name := str(definition.get("display_name"))
			weapon_entries.append({
				"name": weapon_name,
				"level": instance.level,
				"icon": definition.get("icon"),
			})
			var supported_keys: Array = definition.get("supported_modifier_keys")
			if supported_keys.has(&"weapon.beam_tick_interval"):
				damage_values.append("%s %.2f/tick" % [weapon_name, instance.get_damage_value()])
				attack_speed_values.append(
					"%s %.2f tick/s" % [
						weapon_name,
						1.0 / maxf(instance.get_beam_tick_interval(), 0.001),
					]
				)
			else:
				damage_values.append("%s %d" % [weapon_name, instance.get_damage_preview()])
			if supported_keys.has(&"weapon.cooldown"):
				attack_speed_values.append(
					"%s %.2fs" % [weapon_name, instance.get_cooldown()]
				)
			if supported_keys.has(&"weapon.projectile_count"):
				projectile_values.append(
					"%s x%d" % [weapon_name, instance.get_projectile_count()]
				)
			if supported_keys.has(&"weapon.beam_count"):
				beam_count_values.append("%s x%d" % [weapon_name, instance.get_beam_count()])
			if supported_keys.has(&"weapon.beam_width"):
				beam_width_values.append("%s %.1f" % [weapon_name, instance.get_beam_width()])
			if supported_keys.has(&"weapon.range"):
				attack_range_values.append(
					"%s %.0f" % [weapon_name, instance.get_attack_range()]
				)
			if supported_keys.has(&"weapon.pierce_percent"):
				pierce_values.append(
					"%s %d%% (+%d target)" % [
						weapon_name,
						roundi(instance.get_pierce_percent() * 100.0),
						instance.get_projectile_pierce_count(),
					]
				)
			var uses_runtime_ammo := supported_keys.has(&"weapon.ammo_capacity")
			var uses_basic_magazine := definition is BasicGunDefinition
			if uses_runtime_ammo or uses_basic_magazine:
				var weapon_id: String = instance.get_weapon_id()
				var ammo_status: Dictionary = weapon_ammo_status.get(weapon_id, {})
				var live_capacity: int = (
					instance.get_beam_ammo_capacity()
					if uses_runtime_ammo
					else instance.get_magazine_capacity()
				)
				var displayed_ammo: int = int(ammo_status.get("current", live_capacity))
				ammo_values.append("%s %d / %d" % [weapon_name, displayed_ammo, live_capacity])
				var reload_status: Dictionary = weapon_reload_status.get(weapon_id, {})
				var is_reloading := bool(reload_status.get("is_reloading", false))
				var reload_remaining := float(reload_status.get("remaining_time", 0.0))
				var displayed_reload_time: float = (
					instance.get_beam_reload_duration()
					if uses_runtime_ammo
					else instance.get_reload_time()
				)
				if is_reloading:
					displayed_reload_time = float(reload_status.get(
						"duration",
						displayed_reload_time
					))
				reload_values.append(
					"%s %.2fs%s" % [
						weapon_name,
						displayed_reload_time,
						" (Reloading: %.1fs)" % reload_remaining if is_reloading else "",
					]
				)
			for tag in definition.get("compatibility_tags"):
				if not owned_tags.has(tag):
					owned_tags.append(tag)

	var talisman_entries: Array[Dictionary] = []
	var utility_entries: Array[Dictionary] = []
	if build_manager != null:
		for talisman_id in build_manager.talisman_levels:
			var talisman: Resource = build_manager.talisman_definitions.get(talisman_id)
			if talisman != null:
				talisman_entries.append({
					"name": str(talisman.get("display_name")),
					"level": int(build_manager.talisman_levels[talisman_id]),
					"icon": talisman.get("icon"),
				})
		for utility_id in build_manager.utility_stacks:
			var utility: Resource = build_manager.utility_definitions.get(utility_id)
			if utility != null:
				utility_entries.append({
					"name": str(utility.get("display_name")),
					"count": int(build_manager.utility_stacks[utility_id]),
					"icon": utility.get("icon"),
				})

	var stat_lines: Array[String] = [
		"Attack Speed: %s" % (
			", ".join(attack_speed_values) if not attack_speed_values.is_empty() else "-"
		),
		"Projectile Count: %s" % (
			", ".join(projectile_values) if not projectile_values.is_empty() else "-"
		),
		"Attack Range: %s" % (
			", ".join(attack_range_values) if not attack_range_values.is_empty() else "-"
		),
		"Pierce: %s" % (", ".join(pierce_values) if not pierce_values.is_empty() else "-"),
		"Damage: %s" % (", ".join(damage_values) if not damage_values.is_empty() else "-"),
		"Movement Speed: %.1f" % get_move_speed(),
		"Pickup Radius: %.1f" % (config.pickup_radius + pickup_radius_bonus),
		"Revive: %d" % revive_charges,
	]
	if not beam_count_values.is_empty():
		stat_lines.insert(2, "Beam Count: %s" % ", ".join(beam_count_values))
	if not beam_width_values.is_empty():
		stat_lines.insert(3, "Beam Width: %s" % ", ".join(beam_width_values))
	if not ammo_values.is_empty():
		stat_lines.append("Ammo: %s" % ", ".join(ammo_values))
		stat_lines.append("Reload Time: %s" % ", ".join(reload_values))
	if build_manager != null:
		stat_lines.append("Armor: %d" % build_manager.get_armor())
		stat_lines.append("Critical Chance: %.1f%%" % (build_manager.get_critical_chance(owned_tags) * 100.0))
		stat_lines.append("Critical Damage: %.1f%%" % (build_manager.get_critical_damage(owned_tags) * 100.0))
		stat_lines.append("Life Steal: %.1f%%" % (build_manager.get_life_steal(owned_tags) * 100.0))
		stat_lines.append("Luck: %.1f" % build_manager.get_luck())
		var projectile_progress := build_manager.get_talisman_milestone_progress(
			"projectile_count"
		)
		if not projectile_progress.is_empty():
			var progress_percent := float(projectile_progress["progress_percent"]) * 100.0
			var required_percent := float(projectile_progress["required_percent"]) * 100.0
			var completed := int(projectile_progress["completed"])
			stat_lines.append(
				"Projectile Bonus %.0f%% — %.0f%% = +1 projectile (Aktif +%d)" % [
					progress_percent,
					required_percent,
					completed,
				]
			)

	return {
		"weapons": weapon_entries,
		"talismans": talisman_entries,
		"utilities": utility_entries,
		"stat_lines": stat_lines,
	}


func sync_pickup_radius() -> void:
	if pickup_area_collision == null:
		return

	var circle_shape := pickup_area_collision.shape as CircleShape2D
	if circle_shape != null:
		circle_shape.radius = config.pickup_radius + pickup_radius_bonus
