extends Resource
class_name PickupConfig

# Data balancing pickup item. Effects menentukan perilaku pickup tanpa switch di PickupItem.
@export var id := ""
@export var display_name := "Pickup"
@export var magnetizable := true
@export var visual_color := Color.WHITE
@export var label_template := ""
@export var amount := 5
@export var effects: Array[Resource] = []

@export_storage var kind := ""


func set_runtime_amount(new_amount: int) -> void:
	amount = new_amount
	for effect in effects:
		if effect != null and effect.has_method("set_runtime_amount"):
			effect.call("set_runtime_amount", amount)
