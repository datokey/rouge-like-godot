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
var taken_non_stackable_ids: Array[String] = []
var taken_ability_counts := {}


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
	if GameState.mode == GameState.GameMode.GAME_OVER or GameState.mode == GameState.GameMode.VICTORY:
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

	var rolled_abilities := ability_pool_config.roll_offers(
		option_buttons.size(),
		taken_non_stackable_ids,
		taken_ability_counts
	)
	for ability in rolled_abilities:
		var rarity := ability.get_rarity_value()
		var final_value := ability.get_final_value(ability_modifier_config)
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
	var ability := offer["ability"] as AbilityDefinition
	if ability != null:
		taken_ability_counts[ability.id] = int(taken_ability_counts.get(ability.id, 0)) + 1
		if not ability.stackable:
			taken_non_stackable_ids.append(ability.id)

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
	if GameState.mode == GameState.GameMode.PAUSED:
		GameState.mode = GameState.GameMode.RUNNING

	get_tree().paused = false
