extends Area2D

@export var config: ProjectileConfig
@export var damage := 1

var direction := Vector2.RIGHT
var lifetime_remaining := 0.0
var has_hit := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	lifetime_remaining = config.lifetime


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	position += direction * config.speed * delta
	lifetime_remaining -= delta

	if lifetime_remaining <= 0.0:
		has_hit = true
		# Free ditunda agar aman jika lifetime habis saat physics sedang memproses query.
		call_deferred("queue_free")


func setup(start_position: Vector2, target_position: Vector2, projectile_damage: int) -> void:
	global_position = start_position
	damage = projectile_damage
	direction = start_position.direction_to(target_position)
	rotation = direction.angle()


func _on_body_entered(body: Node) -> void:
	if has_hit:
		return

	if body.is_in_group("enemy") and body.has_method("take_damage"):
		has_hit = true
		body.take_damage(damage)
		# Menghindari perubahan state Area2D langsung dari callback body_entered.
		call_deferred("queue_free")
		return

	if body is StaticBody2D:
		has_hit = true
		call_deferred("queue_free")
