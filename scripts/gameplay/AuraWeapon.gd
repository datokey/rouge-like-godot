extends "res://scripts/gameplay/weapons/WeaponBase.gd"
class_name AuraWeapon

var _tick_timer := 0.0
var _current_aura_radius := -1.0

@onready var hitbox: Area2D = $Hitbox
@onready var collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D


func _on_weapon_setup() -> void:
	var def: AuraWeaponDefinition = _get_aura_definition()
	if def != null:
		_sync_aura_radius(def)
		
	# Trigger the first tick immediately
	_tick_timer = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	var owner_node := get_owner_node()
	if owner_node == null:
		return

	var def: AuraWeaponDefinition = _get_aura_definition()
	if def == null:
		return

	# Aura follows the player
	global_position = owner_node.global_position
	_sync_aura_radius(def)

	_tick_timer = maxf(_tick_timer - delta, 0.0)
	if _tick_timer <= 0.0:
		_apply_aura_effects(def)
		_tick_timer = maxf(get_cooldown(), 0.1)


func _apply_aura_effects(def: AuraWeaponDefinition) -> void:
	var bodies: Array[Node2D] = hitbox.get_overlapping_bodies()
	for body in bodies:
		if not body.is_in_group("enemy"):
			continue
			
		if body.has_method("take_damage"):
			var damage: int = _get_tick_damage(def)
			var knockback_dir := Vector2.ZERO
			if def.enable_knockback:
				knockback_dir = global_position.direction_to(body.global_position)
			body.take_damage(damage, knockback_dir, body.global_position)
			
		if body.has_method("apply_slow"):
			body.apply_slow(def.slow_percent, def.slow_duration)

func _draw() -> void:
	var def: AuraWeaponDefinition = _get_aura_definition()
	if def == null:
		return
		
	# Draw a translucent circle
	var aura_radius := _get_aura_radius(def)
	draw_circle(Vector2.ZERO, aura_radius, Color(0.2, 0.6, 1.0, 0.3))
	draw_arc(Vector2.ZERO, aura_radius, 0, TAU, 32, Color(0.2, 0.6, 1.0, 0.8), 2.0)


func _get_aura_definition() -> AuraWeaponDefinition:
	if weapon_instance == null:
		return null
	var def: Resource = weapon_instance.definition
	if def is AuraWeaponDefinition:
		return def as AuraWeaponDefinition
	return null


func _get_tick_damage(def: AuraWeaponDefinition) -> int:
	var base_damage: float = float(get_damage())
	return maxi(1, roundi(base_damage * def.tick_damage_multiplier))


func _get_aura_radius(def: AuraWeaponDefinition) -> float:
	if weapon_instance == null:
		return maxf(0.0, def.aura_radius)

	return maxf(0.0, get_range() + def.aura_radius_per_level * float(weapon_instance.level - 1))


func _sync_aura_radius(def: AuraWeaponDefinition) -> void:
	if collision_shape == null:
		return

	var aura_radius := _get_aura_radius(def)
	if is_equal_approx(aura_radius, _current_aura_radius):
		return

	var circle: CircleShape2D = collision_shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		collision_shape.shape = circle

	circle.radius = aura_radius
	_current_aura_radius = aura_radius
	queue_redraw()
