extends "res://scripts/gameplay/pickups/PickupEffect.gd"
class_name ActivateUtilityPickupEffect

@export var method_name: StringName = &"activate_magnet"


func apply(player: Node) -> void:
	if player != null and not String(method_name).is_empty() and player.has_method(method_name):
		player.call(method_name)
