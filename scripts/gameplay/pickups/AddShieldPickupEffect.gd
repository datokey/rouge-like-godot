extends "res://scripts/gameplay/pickups/PickupEffect.gd"
class_name AddShieldPickupEffect

@export var amount := 1
@export var duration := 0.0


func apply(player: Node) -> void:
	if player == null:
		return
	if player.has_method("add_shield"):
		player.call("add_shield", amount, duration)
