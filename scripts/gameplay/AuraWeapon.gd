extends Node2D
class_name AuraWeapon

var weapon_instance: RefCounted

var _tick_timer := 0.0

@onready var hitbox: Area2D = $Hitbox
@onready var collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func setup(new_weapon_instance: RefCounted) -> void:
	weapon_instance = new_weapon_instance
	
	var def: AuraWeaponDefinition = _get_aura_definition()
	if def != null and collision_shape != null:
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = def.aura_radius
		collision_shape.shape = circle
		
	# Trigger the first tick immediately
	_tick_timer = 0.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	if weapon_instance == null or weapon_instance.owner_node == null:
		return

	var def: AuraWeaponDefinition = _get_aura_definition()
	if def == null:
		return

	# Aura follows the player
	global_position = weapon_instance.owner_node.global_position

	_tick_timer = maxf(_tick_timer - delta, 0.0)
	if _tick_timer <= 0.0:
		_apply_aura_effects(def)
		_tick_timer = maxf(def.tick_interval, 0.1)

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
	draw_circle(Vector2.ZERO, def.aura_radius, Color(0.2, 0.6, 1.0, 0.3))
	draw_arc(Vector2.ZERO, def.aura_radius, 0, TAU, 32, Color(0.2, 0.6, 1.0, 0.8), 2.0)

func _get_aura_definition() -> AuraWeaponDefinition:
	if weapon_instance == null:
		return null
	var def: Resource = weapon_instance.definition
	if def is AuraWeaponDefinition:
		return def as AuraWeaponDefinition
	return null

func _get_tick_damage(def: AuraWeaponDefinition) -> int:
	if weapon_instance == null:
		return 1
	var base_damage: float = float(weapon_instance.get_damage())
	return maxi(1, roundi(base_damage * def.tick_damage_multiplier))
