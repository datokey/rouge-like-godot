extends Node2D

@export var config: PickupConfig

@onready var pickup_area: Area2D = $Area2D
@onready var visual: Polygon2D = $Visual
@onready var value_label: Label = $ValueLabel

var is_collected := false


func _ready() -> void:
	_apply_dummy_visual()
	pickup_area.body_entered.connect(_on_body_entered)
	pickup_area.area_entered.connect(_on_area_entered)


func set_pickup_config(new_config: PickupConfig) -> void:
	config = new_config
	if is_node_ready():
		_apply_dummy_visual()


func _on_body_entered(body: Node) -> void:
	_try_collect(body)


func _on_area_entered(area: Area2D) -> void:
	_try_collect(area.get_parent())


func _try_collect(target: Node) -> void:
	if is_collected:
		return

	if target == null or not target.is_in_group("player"):
		return

	is_collected = true
	_apply_to_player(target)
	call_deferred("queue_free")


func _apply_to_player(player: Node) -> void:
	match config.kind:
		"hp":
			if player.has_method("heal"):
				player.heal(config.amount)
		"xp":
			if player.has_method("add_xp"):
				player.add_xp(config.amount)


func _apply_dummy_visual() -> void:
	value_label.hide()
	value_label.text = ""

	match config.kind:
		"hp":
			visual.color = Color(0.2, 1.0, 0.35, 1.0)
			value_label.show()
			value_label.text = "HP: %d" % config.amount
		"xp":
			visual.color = Color(0.2, 0.62, 1.0, 1.0)
			value_label.show()
			value_label.text = "XP: %d" % config.amount
