extends Control

@onready var description: Label = %Description
@onready var continue_button: Button = %ContinueButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	EventBus.run_won.connect(_show_win)
	continue_button.pressed.connect(_go_to_next_scene)
	restart_button.pressed.connect(_restart_game)
	quit_button.pressed.connect(_quit_game)


func _show_win(elapsed_time: float, _target_time: float, next_scene_path: String) -> void:
	description.text = "Kamu berhasil bertahan selama %s." % _format_time(elapsed_time)
	continue_button.visible = not next_scene_path.is_empty()
	show()

	if continue_button.visible:
		continue_button.grab_focus()
	else:
		restart_button.grab_focus()


func _go_to_next_scene() -> void:
	RunManager.go_to_next_scene()


func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


func _format_time(time_seconds: float) -> String:
	var total_seconds := maxi(0, floori(time_seconds))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
