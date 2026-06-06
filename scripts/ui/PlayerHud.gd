extends Control

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var xp_label: Label = %XpLabel
@onready var run_bar: ProgressBar = %RunBar
@onready var run_label: Label = %RunLabel


func _ready() -> void:
	# HUD hanya mendengar event, tidak mencari node Player secara langsung.
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_xp_changed.connect(_on_player_xp_changed)
	EventBus.run_time_changed.connect(_on_run_time_changed)
	_on_player_health_changed(GameState.player_hp, GameState.player_max_hp)
	_on_player_xp_changed(GameState.player_xp, GameState.player_required_xp, GameState.player_level)
	_on_run_time_changed(GameState.run_elapsed_time, GameState.run_target_time)


func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = "HP %d / %d" % [current_hp, max_hp]


func _on_player_xp_changed(current_xp: int, required_xp: int, level: int) -> void:
	xp_bar.max_value = required_xp
	xp_bar.value = current_xp
	xp_label.text = "LV %d  XP %d / %d" % [level, current_xp, required_xp]


func _on_run_time_changed(elapsed_time: float, target_time: float) -> void:
	run_bar.max_value = target_time
	run_bar.value = elapsed_time
	run_label.text = "RUN %s / %s" % [
		_format_time(elapsed_time),
		_format_time(target_time),
	]


func _format_time(time_seconds: float) -> String:
	var total_seconds := maxi(0, floori(time_seconds))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
