extends Node2D

@export var config: ProjectileConfig
# Damage runtime diisi oleh PlayerController dari WeaponConfig saat projectile ditembakkan.
@export var damage := 0

@onready var hitbox: Area2D = $Hitbox

var direction := Vector2.RIGHT
var lifetime_remaining := 0.0
var has_hit := false
var speed_override := -1.0
var source_weapon: WeaponInstance


func _ready() -> void:
	hitbox.body_entered.connect(_on_body_entered)
	hitbox.area_entered.connect(_on_area_entered)
	if config != null:
		lifetime_remaining = config.lifetime


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	var move_speed := speed_override
	if move_speed <= 0.0 and config != null:
		move_speed = config.speed

	position += direction * move_speed * delta
	lifetime_remaining -= delta

	if lifetime_remaining <= 0.0:
		has_hit = true
		# Free ditunda agar aman jika lifetime habis saat physics sedang memproses query.
		call_deferred("queue_free")


func setup(
	start_position: Vector2,
	target_position: Vector2,
	projectile_damage: int,
	projectile_speed: float = -1.0,
	projectile_size: float = 1.0,
	new_source_weapon: WeaponInstance = null
) -> void:
	global_position = start_position
	damage = projectile_damage
	speed_override = projectile_speed
	source_weapon = new_source_weapon
	scale = Vector2.ONE * maxf(0.1, projectile_size)
	direction = start_position.direction_to(target_position)
	rotation = direction.angle()


func _on_body_entered(body: Node) -> void:
	if has_hit:
		return

	if body is StaticBody2D:
		has_hit = true
		call_deferred("queue_free")


func _on_area_entered(area: Area2D) -> void:
	if has_hit:
		return

	var owner_node := area.get_parent()
	if owner_node != null and owner_node.is_in_group("enemy") and owner_node.has_method("take_damage"):
		has_hit = true
		owner_node.take_damage(damage, direction, global_position)
		if source_weapon != null:
			source_weapon.on_damage_dealt(damage)
		# Menghindari perubahan state Area2D langsung dari callback area_entered.
		call_deferred("queue_free")
