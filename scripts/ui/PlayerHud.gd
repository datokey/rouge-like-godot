extends Control

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var xp_label: Label = %XpLabel


func _ready() -> void:
	# HUD hanya mendengar event, tidak mencari node Player secara langsung.
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_xp_changed.connect(_on_player_xp_changed)
	_on_player_health_changed(GameState.player_hp, GameState.player_max_hp)
	_on_player_xp_changed(GameState.player_xp, GameState.player_required_xp, GameState.player_level)


func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = "HP %d / %d" % [current_hp, max_hp]


func _on_player_xp_changed(current_xp: int, required_xp: int, level: int) -> void:
	xp_bar.max_value = required_xp
	xp_bar.value = current_xp
	xp_label.text = "LV %d  XP %d / %d" % [level, current_xp, required_xp]
