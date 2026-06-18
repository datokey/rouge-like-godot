extends Resource
class_name ModifierDefinition

enum ValueType {
	FLAT,
	PERCENT,
}

@export var id := ""
@export var display_name := "Modifier"
@export_multiline var description := ""
@export var icon: Texture2D
@export var modifier_key: StringName
@export var value := 0.0
@export var value_type: ValueType = ValueType.FLAT
@export_range(0.0, 1000.0, 0.05) var weight := 1.0


func get_scaled_value(rarity_multiplier: float) -> float:
	return value * rarity_multiplier
