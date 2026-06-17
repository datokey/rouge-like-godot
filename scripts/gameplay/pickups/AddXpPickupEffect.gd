extends "res://scripts/gameplay/pickups/PickupEffect.gd"
class_name AddXpPickupEffect

@export var amount := 1
@export var use_config_amount := true


func apply(player: Node) -> void:
	if player != null and player.has_method("add_xp"):
		player.add_xp(amount)


func set_runtime_amount(new_amount: int) -> void:
	if use_config_amount:
		amount = new_amount
