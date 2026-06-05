extends Control

@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	hide()

	# Screen ini muncul saat gameplay memancarkan event kematian player.
	EventBus.player_died.connect(_show_game_over)
	restart_button.pressed.connect(_restart_game)
	quit_button.pressed.connect(_quit_game)


func _show_game_over() -> void:
	show()
	restart_button.grab_focus()


func _restart_game() -> void:
	get_tree().reload_current_scene()


func _quit_game() -> void:
	get_tree().quit()
