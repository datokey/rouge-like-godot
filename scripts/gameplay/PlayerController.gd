extends CharacterBody2D

# Semua angka balancing player diambil dari resource agar mudah diubah dari editor.
@export var config: PlayerConfig
@export var weapon_config: WeaponConfig
@export var xp_config: XPConfig
@export var ability_modifier_config: AbilityModifierConfig
@export var projectile_scene: PackedScene

@onready var pickup_area_collision: CollisionShape2D = $PickupArea/CollisionShape2D

var current_hp := 0
var current_xp := 0
var current_level := 1
var attack_timer := 0.0

# Modifier runtime disiapkan untuk upgrade tanpa mengubah base config.
var flat_damage_modifier := 0
var damage_percent_modifier := 0.0
var attack_interval_modifier := 0.0
var attack_speed_percent_modifier := 0.0
var max_hp_modifier := 0
var move_speed_modifier := 0.0


func _ready() -> void:
	EventBus.ability_selected.connect(_on_ability_selected)
	current_hp = get_max_hp()
	current_xp = 0
	current_level = 1
	_apply_pickup_radius()
	GameState.mode = GameState.GameMode.RUNNING

	# GameState menyimpan nilai global, sedangkan EventBus memberi tahu UI.
	_emit_health_changed()
	_emit_xp_changed()


func _physics_process(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)

	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = input_direction * get_move_speed()
	move_and_slide()

	# Auto-shoot berjalan setiap frame, tetapi tetap dibatasi attack_timer.
	_try_auto_attack()


func _try_auto_attack() -> void:
	if attack_timer > 0.0 or projectile_scene == null:
		return

	var target := _get_nearest_enemy()
	if target == null:
		return

	var projectile := projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.call("setup", global_position, target.global_position, get_weapon_damage())
	attack_timer = get_attack_interval()


func _get_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D
	var nearest_distance := get_attack_range()

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
		GameState.set_game_over()
		EventBus.player_died.emit()
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

	return base_speed + move_speed_modifier


func get_max_hp() -> int:
	var base_max_hp := 100
	if config != null:
		base_max_hp = config.max_hp

	return maxi(1, base_max_hp + max_hp_modifier)


func get_weapon_damage() -> int:
	var base_damage := 0
	if weapon_config != null:
		base_damage = weapon_config.damage

	var flat_damage := maxi(0, base_damage + flat_damage_modifier)
	var scaled_damage := float(flat_damage) * (1.0 + damage_percent_modifier)
	return maxi(0, roundi(scaled_damage))


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


func get_attack_interval() -> float:
	var base_interval := 1.0
	if weapon_config != null:
		base_interval = weapon_config.attack_interval

	var modified_interval := maxf(0.05, base_interval + attack_interval_modifier)
	var attack_speed_scale := maxf(0.05, 1.0 + attack_speed_percent_modifier)
	return maxf(0.05, modified_interval / attack_speed_scale)


func get_attack_range() -> float:
	if weapon_config == null:
		return 0.0

	return weapon_config.attack_range


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
	if ability == null or not ability.has_method("apply_to_player"):
		return

	ability.call("apply_to_player", self, ability_modifier_config, rarity)


func _apply_max_hp_modifier(amount: int) -> void:
	if amount == 0:
		return

	max_hp_modifier += amount
	current_hp = clampi(current_hp + amount, 0, get_max_hp())
	_emit_health_changed()


func _get_default_modifier_value(modifier_type: int) -> float:
	if ability_modifier_config != null:
		match modifier_type:
			AbilityModifierConfig.ModifierType.DAMAGE_PERCENT:
				return ability_modifier_config.default_damage_percent
			AbilityModifierConfig.ModifierType.ATTACK_SPEED_PERCENT:
				return ability_modifier_config.default_attack_speed_percent
			AbilityModifierConfig.ModifierType.MAX_HP_FLAT:
				return ability_modifier_config.default_max_hp_flat

	match modifier_type:
		AbilityModifierConfig.ModifierType.DAMAGE_PERCENT:
			return 0.05
		AbilityModifierConfig.ModifierType.ATTACK_SPEED_PERCENT:
			return 0.15
		AbilityModifierConfig.ModifierType.MAX_HP_FLAT:
			return 5.0
		_:
			return 0.0


func _apply_pickup_radius() -> void:
	if pickup_area_collision == null:
		return

	var circle_shape := pickup_area_collision.shape as CircleShape2D
	if circle_shape != null:
		circle_shape.radius = config.pickup_radius
