extends Node2D

const DEFAULT_STARTING_WEAPONS: Array[Resource] = [
	preload("res://resources/weapons/BasicGun.tres"),
	preload("res://resources/weapons/RapidGun.tres"),
	preload("res://resources/weapons/ScatterGun.tres"),
]

@export var starting_weapon_options: Array[Resource] = []

@onready var player: Node = $World/Player
@onready var starting_weapon_screen: Control = $UI/StartingWeaponSelectionScreen


func _ready() -> void:
	GameState.mode = GameState.GameMode.MENU
	get_tree().paused = true

	if starting_weapon_screen.has_signal("weapon_selected"):
		starting_weapon_screen.weapon_selected.connect(_on_starting_weapon_selected)
	if starting_weapon_screen.has_method("show_start_menu"):
		starting_weapon_screen.call("show_start_menu", _get_starting_weapon_options())


func _on_starting_weapon_selected(weapon_definition: Resource) -> void:
	if player != null and player.has_method("equip_starting_weapon"):
		player.call("equip_starting_weapon", weapon_definition)

	starting_weapon_screen.hide()
	RunManager.start_run()


func _get_starting_weapon_options() -> Array[Resource]:
	var options := starting_weapon_options
	if options.is_empty():
		options = DEFAULT_STARTING_WEAPONS

	return options
