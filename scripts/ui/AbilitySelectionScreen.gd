extends Control

@export var reward_pool_config: RewardPoolConfig

@onready var level_label: Label = %LevelLabel
@onready var option_buttons: Array[Button] = [
	%OptionButton1,
	%OptionButton2,
	%OptionButton3,
]

var pending_level_ups := 0
var is_selecting := false
var current_offers: Array[RewardOffer] = []
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


func _roll_offers() -> Array[RewardOffer]:
	if reward_pool_config == null:
		return []
	return reward_pool_config.roll_offers(_get_offer_context(), option_buttons.size())


func _get_offer_context() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("get_reward_offer_context"):
		var context = player.call("get_reward_offer_context")
		if typeof(context) == TYPE_DICTIONARY:
			return context
	return {"player_level": current_level}


func _refresh_screen() -> void:
	level_label.text = "Level %d" % current_level

	for index in range(option_buttons.size()):
		var button := option_buttons[index]
		if index >= current_offers.size():
			button.hide()
			button.disabled = true
			continue

		var offer := current_offers[index]
		if offer == null:
			button.hide()
			button.disabled = true
			continue

		button.show()
		button.disabled = false
		button.text = offer.get_offer_text()


func _on_option_pressed(index: int) -> void:
	if index < 0 or index >= current_offers.size():
		return

	var offer := current_offers[index]
	EventBus.reward_selected.emit(offer)
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
