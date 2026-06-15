extends Control
class_name StartingWeaponSelectionScreen

signal weapon_selected(weapon_definition: Resource)

@onready var start_button: Button = %StartButton
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var weapon_list: VBoxContainer = %WeaponList

var weapon_options: Array[Resource] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_button.pressed.connect(_show_weapon_choices)
	hide()


func show_start_menu(options: Array[Resource]) -> void:
	weapon_options = options
	title_label.text = "Ready?"
	description_label.text = "Pilih Start Run untuk menentukan senjata awal."
	start_button.show()
	_clear_weapon_buttons()
	show()
	start_button.grab_focus()


func _show_weapon_choices() -> void:
	if weapon_options.size() == 1 and weapon_options[0] != null:
		_select_weapon(weapon_options[0])
		return

	start_button.hide()
	title_label.text = "Pilih Senjata Awal"
	description_label.text = "Senjata ini akan langsung aktif saat run dimulai."
	_clear_weapon_buttons()

	for weapon_definition in weapon_options:
		if weapon_definition == null:
			continue

		var button := Button.new()
		button.custom_minimum_size = Vector2(320, 54)
		button.text = _get_weapon_button_text(weapon_definition)
		button.pressed.connect(_select_weapon.bind(weapon_definition))
		weapon_list.add_child(button)

	if weapon_list.get_child_count() > 0:
		var first_button := weapon_list.get_child(0) as Button
		if first_button != null:
			first_button.grab_focus()


func _select_weapon(weapon_definition: Resource) -> void:
	weapon_selected.emit(weapon_definition)


func _clear_weapon_buttons() -> void:
	for child in weapon_list.get_children():
		child.queue_free()


func _get_weapon_button_text(weapon_definition: Resource) -> String:
	var weapon_name := str(weapon_definition.get("display_name"))
	var description := str(weapon_definition.get("description"))
	var weapon_type := _get_weapon_type_name(int(weapon_definition.get("weapon_type")))
	return "%s [%s]\n%s" % [weapon_name, weapon_type, description]


func _get_weapon_type_name(weapon_type: int) -> String:
	match weapon_type:
		WeaponDefinition.WeaponType.AURA:
			return "Aura"
		WeaponDefinition.WeaponType.AREA:
			return "Area"
		WeaponDefinition.WeaponType.SUMMON:
			return "Summon"
		WeaponDefinition.WeaponType.BEAM:
			return "Beam"
		WeaponDefinition.WeaponType.MELEE:
			return "Melee"
		_:
			return "Projectile"
