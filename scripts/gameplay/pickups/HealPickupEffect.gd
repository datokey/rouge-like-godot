extends "res://scripts/gameplay/pickups/PickupEffect.gd"
class_name HealPickupEffect

@export var amount := 5
@export var use_config_amount := true


func apply(player: Node) -> void:
	if player != null and player.has_method("heal"):
		player.heal(amount)


func set_runtime_amount(new_amount: int) -> void:
	if use_config_amount:
		amount = new_amount
