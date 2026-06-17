extends Node2D

const DEFAULT_STARTING_WEAPONS: Array[Resource] = [
	preload("res://resources/weapons/BasicGun.tres"),
	preload("res://resources/weapons/BeamGun.tres"),
]
const WEAPON_RESOURCE_FOLDER := "res://resources/weapons"

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
	var options := _filter_valid_weapon_definitions(starting_weapon_options)
	if options.is_empty():
		options = _load_all_weapon_resources()
	if options.is_empty():
		options = _filter_valid_weapon_definitions(DEFAULT_STARTING_WEAPONS)

	return options


func _filter_valid_weapon_definitions(resources: Array[Resource]) -> Array[Resource]:
	var valid_resources: Array[Resource] = []
	for resource in resources:
		if _is_valid_weapon_definition(resource):
			valid_resources.append(resource)

	return valid_resources


func _load_all_weapon_resources() -> Array[Resource]:
	var weapon_resources: Array[Resource] = []
	var directory := DirAccess.open(WEAPON_RESOURCE_FOLDER)
	if directory == null:
		return weapon_resources

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path := "%s/%s" % [WEAPON_RESOURCE_FOLDER, file_name]
			var resource := ResourceLoader.load(resource_path)
			if _is_valid_weapon_definition(resource):
				weapon_resources.append(resource)

		file_name = directory.get_next()
	directory.list_dir_end()

	weapon_resources.sort_custom(_sort_weapon_by_display_name)
	return weapon_resources


func _is_valid_weapon_definition(resource: Resource) -> bool:
	if resource == null:
		return false
	if not resource is WeaponDefinition:
		return false

	var weapon_id := str(resource.get("id"))
	var weapon_scene: PackedScene = resource.get("weapon_scene")
	return not weapon_id.is_empty() and weapon_scene != null


func _sort_weapon_by_display_name(left: Resource, right: Resource) -> bool:
	return str(left.get("display_name")) < str(right.get("display_name"))
