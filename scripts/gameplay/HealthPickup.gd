extends Area2D

@export var config: PickupConfig


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("heal"):
		# Nilai heal berasal dari resource agar mudah di-balance.
		body.heal(config.heal_amount)
		queue_free()
