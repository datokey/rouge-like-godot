extends Node2D

@export var config: ProjectileConfig
# Damage runtime diisi oleh PlayerController dari WeaponConfig saat projectile ditembakkan.
@export var damage := 0

@onready var hitbox: Area2D = $Hitbox
@onready var visual: Node2D = $Visual

var direction := Vector2.RIGHT
var lifetime_remaining := 0.0
var has_hit := false
var speed_override := -1.0
var source_weapon: WeaponInstance
var size_multiplier := 1.0


func _ready() -> void:
	hitbox.body_entered.connect(_on_body_entered)
	hitbox.area_entered.connect(_on_area_entered)
	_sync_projectile_size()
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
	if source_weapon != null:
		source_weapon.register_damage_source(self)
	# WeaponInstance sudah menerapkan batas size dari WeaponDefinition.
	size_multiplier = projectile_size
	_sync_projectile_size()
	direction = start_position.direction_to(target_position)
	rotation = direction.angle()


func _sync_projectile_size() -> void:
	if visual != null:
		visual.scale = Vector2.ONE * size_multiplier
	if hitbox != null:
		hitbox.scale = Vector2.ONE * size_multiplier


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
		if source_weapon != null:
			source_weapon.apply_damage(owner_node, damage, direction, global_position)
		# Menghindari perubahan state Area2D langsung dari callback area_entered.
		call_deferred("queue_free")


func _exit_tree() -> void:
	if source_weapon != null:
		source_weapon.unregister_damage_source(self)
