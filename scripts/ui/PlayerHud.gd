extends Control

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel


func _ready() -> void:
	# HUD hanya mendengar event, tidak mencari node Player secara langsung.
	EventBus.player_health_changed.connect(_on_player_health_changed)
	_on_player_health_changed(GameState.player_hp, GameState.player_max_hp)


func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = "HP %d / %d" % [current_hp, max_hp]
