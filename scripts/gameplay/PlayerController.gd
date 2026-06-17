extends CharacterBody2D

const AbilityManagerScript = preload("res://abilities/scripts/AbilityManager.gd")
const WeaponManagerScript = preload("res://scripts/gameplay/WeaponManager.gd")

# Semua angka balancing player diambil dari resource agar mudah diubah dari editor.
@export var config: PlayerConfig
@export var xp_config: XPConfig
@export var ability_modifier_config: AbilityModifierConfig
@export var starting_weapon: Resource
@export var max_weapon_slots := 4

@onready var pickup_area_collision: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var weapon_holder: Node2D = $WeaponHolder
@onready var magnet_component: Node = $MagnetComponent

var current_hp := 0
var current_xp := 0
var current_level := 1

# Modifier runtime disiapkan untuk upgrade tanpa mengubah base config.
var flat_damage_modifier := 0
var damage_percent_modifier := 0.0
var attack_interval_modifier := 0.0
var attack_speed_percent_modifier := 0.0
var max_hp_modifier := 0
var move_speed_modifier := 0.0
var move_speed_percent_modifier := 0.0
var projectile_count_modifier := 0
var ability_manager
var weapon_manager


func _ready() -> void:
	EventBus.ability_selected.connect(_on_ability_selected)
	ability_manager = AbilityManagerScript.new()
	ability_manager.setup(ability_modifier_config)
	weapon_manager = WeaponManagerScript.new()
	weapon_manager.max_weapon_slots = max_weapon_slots
	weapon_manager.setup(self, weapon_holder, ability_manager)
	current_hp = get_max_hp()
	current_xp = 0
	current_level = 1
	_apply_pickup_radius()

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
	current_hp = maxi(current_hp - amount, 0)
	_emit_health_changed()

	if current_hp <= 0:
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

	var flat_speed := base_speed + move_speed_modifier
	var percent_bonus := move_speed_percent_modifier + _get_player_move_speed_percent_modifier()
	return maxf(0.0, flat_speed * (1.0 + percent_bonus))


func get_max_hp() -> int:
	var base_max_hp := 100
	if config != null:
		base_max_hp = config.max_hp

	return maxi(1, base_max_hp + max_hp_modifier + _get_player_max_hp_modifier())


func add_damage_modifier(amount: int) -> void:
	flat_damage_modifier += amount


func set_damage_modifier(value: int) -> void:
	flat_damage_modifier = value


func add_damage_percent_modifier(
	base_percent: float = -1.0,
	rarity: int = AbilityModifierConfig.Rarity.COMMON
) -> float:
	return apply_ability_modifier(
		AbilityModifierConfig.ModifierType.DAMAGE_PERCENT,
		base_percent,
		rarity
	)


func add_attack_interval_reduction(interval_reduction: float) -> void:
	# Attack speed naik berarti jeda tembak berkurang.
	attack_interval_modifier -= absf(interval_reduction)


func set_attack_interval_modifier(value: float) -> void:
	attack_interval_modifier = value


func add_attack_speed_modifier(
	base_percent: float = -1.0,
	rarity: int = AbilityModifierConfig.Rarity.COMMON
) -> float:
	return apply_ability_modifier(
		AbilityModifierConfig.ModifierType.ATTACK_SPEED_PERCENT,
		base_percent,
		rarity
	)


func add_max_hp_modifier(
	base_amount: float = -1.0,
	rarity: int = AbilityModifierConfig.Rarity.COMMON
) -> float:
	return apply_ability_modifier(
		AbilityModifierConfig.ModifierType.MAX_HP_FLAT,
		base_amount,
		rarity
	)


func add_projectile_count_modifier(
	base_amount: float = -1.0,
	rarity: int = AbilityModifierConfig.Rarity.COMMON
) -> float:
	return apply_ability_modifier(
		AbilityModifierConfig.ModifierType.PROJECTILE_COUNT_FLAT,
		base_amount,
		rarity
	)


func add_move_speed_modifier(
	base_percent: float = -1.0,
	rarity: int = AbilityModifierConfig.Rarity.COMMON
) -> float:
	return apply_ability_modifier(
		AbilityModifierConfig.ModifierType.MOVE_SPEED_PERCENT,
		base_percent,
		rarity
	)


func activate_magnet() -> void:
	if magnet_component == null or not magnet_component.has_method("activate"):
		return

	magnet_component.call("activate")


func apply_ability_modifier(
	modifier_type: int,
	base_value: float = -1.0,
	rarity: int = AbilityModifierConfig.Rarity.COMMON
) -> float:
	var final_value := calculate_ability_modifier_value(modifier_type, base_value, rarity)

	match modifier_type:
		AbilityModifierConfig.ModifierType.DAMAGE_PERCENT:
			damage_percent_modifier += final_value
		AbilityModifierConfig.ModifierType.ATTACK_SPEED_PERCENT:
			attack_speed_percent_modifier += final_value
		AbilityModifierConfig.ModifierType.MAX_HP_FLAT:
			final_value = float(roundi(final_value))
			_apply_max_hp_modifier(int(final_value))
		AbilityModifierConfig.ModifierType.PROJECTILE_COUNT_FLAT:
			final_value = float(roundi(final_value))
			_apply_projectile_count_modifier(int(final_value))
		AbilityModifierConfig.ModifierType.MOVE_SPEED_PERCENT:
			move_speed_percent_modifier += final_value
		_:
			return 0.0

	return final_value


func calculate_ability_modifier_value(
	modifier_type: int,
	base_value: float = -1.0,
	rarity: int = AbilityModifierConfig.Rarity.COMMON
) -> float:
	var value_to_scale := base_value
	if value_to_scale < 0.0:
		value_to_scale = _get_default_modifier_value(modifier_type)

	if ability_modifier_config == null:
		return value_to_scale

	return ability_modifier_config.calculate_value(value_to_scale, rarity)


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


func _on_ability_selected(ability: Resource, rarity: int) -> void:
	if ability == null or ability_manager == null:
		return

	add_ability_to_manager(ability, rarity)


func add_ability_to_manager(ability: Resource, rarity: int) -> bool:
	if ability == null or ability_manager == null:
		return false

	if ability.has_method("is_weapon_reward") and ability.call("is_weapon_reward") == true:
		var weapon_definition: Resource = ability.get("weapon_definition")
		if weapon_manager == null:
			return false
		return weapon_manager.add_weapon(weapon_definition)

	var max_hp_before := get_max_hp()
	var added: bool = ability_manager.add_ability(ability, rarity)
	if not added:
		return false

	var max_hp_after := get_max_hp()
	if max_hp_after > max_hp_before:
		current_hp = clampi(current_hp + (max_hp_after - max_hp_before), 0, max_hp_after)
		_emit_health_changed()

	return true


func get_weapon_offer_context() -> Dictionary:
	if weapon_manager == null:
		return {}

	return weapon_manager.get_offer_context()


func equip_starting_weapon(weapon_definition: Resource = null) -> bool:
	if weapon_manager == null:
		return false

	var selected_weapon := weapon_definition
	if selected_weapon == null:
		selected_weapon = starting_weapon
	if selected_weapon == null:
		return false

	starting_weapon = selected_weapon
	return weapon_manager.add_weapon(selected_weapon)


func _apply_max_hp_modifier(amount: int) -> void:
	if amount == 0:
		return

	max_hp_modifier += amount
	current_hp = clampi(current_hp + amount, 0, get_max_hp())
	_emit_health_changed()


func _apply_projectile_count_modifier(amount: int) -> void:
	if amount == 0:
		return

	projectile_count_modifier = maxi(0, projectile_count_modifier + amount)


func _get_default_modifier_value(modifier_type: int) -> float:
	if ability_modifier_config != null:
		match modifier_type:
			AbilityModifierConfig.ModifierType.DAMAGE_PERCENT:
				return ability_modifier_config.default_damage_percent
			AbilityModifierConfig.ModifierType.ATTACK_SPEED_PERCENT:
				return ability_modifier_config.default_attack_speed_percent
			AbilityModifierConfig.ModifierType.MAX_HP_FLAT:
				return ability_modifier_config.default_max_hp_flat
			AbilityModifierConfig.ModifierType.PROJECTILE_COUNT_FLAT:
				return ability_modifier_config.default_projectile_count_flat
			AbilityModifierConfig.ModifierType.MOVE_SPEED_PERCENT:
				return ability_modifier_config.default_move_speed_percent

	match modifier_type:
		AbilityModifierConfig.ModifierType.DAMAGE_PERCENT:
			return 0.05
		AbilityModifierConfig.ModifierType.ATTACK_SPEED_PERCENT:
			return 0.15
		AbilityModifierConfig.ModifierType.MAX_HP_FLAT:
			return 5.0
		AbilityModifierConfig.ModifierType.PROJECTILE_COUNT_FLAT:
			return 1.0
		AbilityModifierConfig.ModifierType.MOVE_SPEED_PERCENT:
			return 0.1
		_:
			return 0.0


func _get_weapon_damage_percent_modifier() -> float:
	if ability_manager == null:
		return 0.0

	return ability_manager.get_weapon_damage_percent_modifier()


func _get_weapon_attack_speed_percent_modifier() -> float:
	if ability_manager == null:
		return 0.0

	return ability_manager.get_weapon_attack_speed_percent_modifier()


func _get_weapon_projectile_count_modifier() -> int:
	if ability_manager == null:
		return 0

	return roundi(ability_manager.get_weapon_projectile_count_modifier())


func _get_player_max_hp_modifier() -> int:
	if ability_manager == null:
		return 0

	return roundi(ability_manager.get_player_max_hp_modifier())


func _get_player_move_speed_percent_modifier() -> float:
	if ability_manager == null:
		return 0.0

	return ability_manager.get_player_move_speed_percent_modifier()


func _apply_pickup_radius() -> void:
	if pickup_area_collision == null:
		return

	var circle_shape := pickup_area_collision.shape as CircleShape2D
	if circle_shape != null:
		circle_shape.radius = config.pickup_radius
