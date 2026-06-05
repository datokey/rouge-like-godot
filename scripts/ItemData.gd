extends Resource
class_name ItemData

enum ItemKind {
	CONSUMABLE,
	WEAPON,
	ARMOR,
	KEY,
}

@export var display_name := ""
@export var kind: ItemKind = ItemKind.CONSUMABLE
@export_multiline var description := ""
