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


func _ready() -> void:
	EventBus.reward_selected.connect(_on_reward_selected)
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
	build_manager.apply_offer(offer, weapon_manager)


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
	return weapon_manager.add_weapon(selected_weapon)


func sync_pickup_radius() -> void:
	if pickup_area_collision == null:
		return

	var circle_shape := pickup_area_collision.shape as CircleShape2D
	if circle_shape != null:
		circle_shape.radius = config.pickup_radius + pickup_radius_bonus
