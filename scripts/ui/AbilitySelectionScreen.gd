extends Control

@export var ability_pool_config: AbilityPoolConfig
@export var ability_modifier_config: AbilityModifierConfig

@onready var level_label: Label = %LevelLabel
@onready var option_buttons: Array[Button] = [
	%OptionButton1,
	%OptionButton2,
	%OptionButton3,
]

var pending_level_ups := 0
var is_selecting := false
var current_offers: Array[Dictionary] = []
var current_level := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	EventBus.player_level_up.connect(_on_player_level_up)
	for index in range(option_buttons.size()):
		option_buttons[index].pressed.connect(_on_option_pressed.bind(index))


func _on_player_level_up(level: int, _remaining_xp: int, _next_required_xp: int) -> void:
	current_level = level
	pending_level_ups += 1
	call_deferred("_show_next_selection")


func _show_next_selection() -> void:
	if is_selecting or pending_level_ups <= 0:
		return
	if GameState.mode == GameState.GameMode.GAME_OVER:
		return

	pending_level_ups -= 1
	current_offers = _roll_offers()
	if current_offers.is_empty():
		_resume_game()
		return

	is_selecting = true
	GameState.mode = GameState.GameMode.PAUSED
	get_tree().paused = true
	_refresh_screen()
	show()
	option_buttons[0].grab_focus()


func _roll_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	if ability_pool_config == null:
		return offers

	var available_abilities := ability_pool_config.get_valid_abilities()
	var offer_count := mini(ability_pool_config.offer_count, option_buttons.size())
	offer_count = mini(offer_count, available_abilities.size())

	for _index in range(offer_count):
		var ability_index := Rng.range_i(0, available_abilities.size() - 1)
		var ability := available_abilities[ability_index]
		available_abilities.remove_at(ability_index)

		var rarity := ability_pool_config.roll_rarity()
		var final_value := ability.get_final_value(ability_modifier_config, rarity)
		offers.append({
			"ability": ability,
			"rarity": rarity,
			"final_value": final_value,
		})

	return offers


func _refresh_screen() -> void:
	level_label.text = "Level %d" % current_level

	for index in range(option_buttons.size()):
		var button := option_buttons[index]
		if index >= current_offers.size():
			button.hide()
			button.disabled = true
			continue

		var offer := current_offers[index]
		var ability := offer["ability"] as AbilityDefinition
		if ability == null:
			button.hide()
			button.disabled = true
			continue

		var rarity := int(offer["rarity"])
		button.show()
		button.disabled = false
		button.text = ability.get_offer_text(ability_modifier_config, rarity)


func _on_option_pressed(index: int) -> void:
	if index < 0 or index >= current_offers.size():
		return

	var offer := current_offers[index]
	EventBus.ability_selected.emit(offer["ability"], int(offer["rarity"]))
	_close_selection()


func _close_selection() -> void:
	hide()
	current_offers.clear()
	is_selecting = false

	if pending_level_ups > 0:
		call_deferred("_show_next_selection")
		return

	_resume_game()


func _resume_game() -> void:
	if GameState.mode != GameState.GameMode.GAME_OVER:
		GameState.mode = GameState.GameMode.RUNNING

	get_tree().paused = false
