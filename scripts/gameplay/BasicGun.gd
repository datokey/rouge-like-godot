extends WeaponBase
class_name BasicGun

const RELOAD_SIGNAL_INTERVAL := 0.1

signal ammo_changed(current_ammo: int, magazine_capacity: int)
signal reload_changed(is_reloading: bool, remaining_time: float, duration: float)

enum State {
	READY,
	ATTACK_COOLDOWN,
	RELOADING,
}

@export var projectile_scene: PackedScene

var state := State.READY
var current_ammo := 0
var state_timer := 0.0
var reload_duration_snapshot := 0.0
var _last_known_capacity := 0
var _last_known_reload_time := 0.0
var _last_reload_signal_step := -1


func _on_weapon_setup() -> void:
	state = State.READY
	state_timer = 0.0
	reload_duration_snapshot = 0.0
	_last_reload_signal_step = -1
	current_ammo = weapon_instance.get_magazine_capacity()
	_last_known_capacity = current_ammo
	_last_known_reload_time = weapon_instance.get_reload_time()
	ammo_changed.emit(current_ammo, _last_known_capacity)
	reload_changed.emit(false, 0.0, _last_known_reload_time)


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_owner_node() == null:
		return

	_sync_live_magazine_config()

	if state == State.RELOADING:
		state_timer = maxf(state_timer - delta, 0.0)
		if state_timer <= 0.0:
			_finish_reload()
		else:
			_emit_reload_progress_if_needed()
		return

	if state == State.ATTACK_COOLDOWN:
		state_timer = maxf(state_timer - delta, 0.0)
		if state_timer > 0.0:
			return
		state = State.READY

	if current_ammo <= 0:
		_start_reload()
		return
	if projectile_scene == null:
		return

	var target := get_nearest_enemy()
	if target == null:
		return

	_shoot_projectiles(target)
	_consume_ammo()
	if current_ammo <= 0:
		_start_reload()
	else:
		state = State.ATTACK_COOLDOWN
		state_timer = get_cooldown()


func _consume_ammo() -> void:
	current_ammo = maxi(0, current_ammo - 1)
	ammo_changed.emit(current_ammo, weapon_instance.get_magazine_capacity())


func _start_reload() -> void:
	if state == State.RELOADING:
		return
	state = State.RELOADING
	reload_duration_snapshot = weapon_instance.get_reload_time()
	state_timer = reload_duration_snapshot
	_last_reload_signal_step = ceili(state_timer / RELOAD_SIGNAL_INTERVAL)
	reload_changed.emit(true, state_timer, reload_duration_snapshot)


func _finish_reload() -> void:
	current_ammo = weapon_instance.get_magazine_capacity()
	state = State.READY
	state_timer = 0.0
	_last_reload_signal_step = -1
	ammo_changed.emit(current_ammo, weapon_instance.get_magazine_capacity())
	reload_changed.emit(false, 0.0, reload_duration_snapshot)


func _emit_reload_progress_if_needed() -> void:
	var current_step := ceili(state_timer / RELOAD_SIGNAL_INTERVAL)
	if current_step == _last_reload_signal_step:
		return
	_last_reload_signal_step = current_step
	reload_changed.emit(true, state_timer, reload_duration_snapshot)


func _sync_live_magazine_config() -> void:
	var live_capacity := weapon_instance.get_magazine_capacity()
	var live_reload_time := weapon_instance.get_reload_time()
	if live_capacity != _last_known_capacity:
		_last_known_capacity = live_capacity
		ammo_changed.emit(current_ammo, live_capacity)
	if state != State.RELOADING and not is_equal_approx(live_reload_time, _last_known_reload_time):
		_last_known_reload_time = live_reload_time
		reload_changed.emit(false, 0.0, live_reload_time)


func _shoot_projectiles(target: Node2D) -> void:
	var owner_node := get_owner_node()
	if owner_node == null:
		return

	var projectile_count: int = weapon_instance.get_projectile_count()
	var base_direction: Vector2 = owner_node.global_position.direction_to(target.global_position)
	var spread_step := deg_to_rad(weapon_instance.get_spread_angle_degrees())
	var start_offset := -float(projectile_count - 1) * 0.5

	for index in range(projectile_count):
		var projectile := projectile_scene.instantiate()
		owner_node.get_tree().current_scene.add_child(projectile)
		var damage_result := get_damage_result()

		var spread_angle := (start_offset + float(index)) * spread_step
		var shot_direction: Vector2 = base_direction.rotated(spread_angle)
		var target_position: Vector2 = owner_node.global_position + shot_direction * 100.0
		projectile.call(
			"setup",
			owner_node.global_position,
			target_position,
			int(damage_result.get("amount", 0)),
			weapon_instance.get_projectile_speed(),
			weapon_instance.get_projectile_size(),
			weapon_instance,
			bool(damage_result.get("is_critical", false))
		)
