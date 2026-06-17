extends Node2D

@export var config: PickupConfig

@onready var pickup_area: Area2D = $Area2D
@onready var visual: Polygon2D = $Visual
@onready var value_label: Label = $ValueLabel

var is_collected := false
var magnet_target: Node2D
var magnet_remaining := 0.0
var magnet_pull_speed := 0.0
var magnet_radius := 0.0


func _ready() -> void:
	add_to_group("pickup_item")
	_apply_dummy_visual()
	pickup_area.body_entered.connect(_on_body_entered)
	pickup_area.area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if magnet_remaining <= 0.0:
		return

	magnet_remaining = maxf(magnet_remaining - delta, 0.0)
	if magnet_target == null or not is_instance_valid(magnet_target):
		_clear_magnet_pull()
		return

	if magnet_radius > 0.0 and global_position.distance_to(magnet_target.global_position) > magnet_radius:
		return

	global_position = global_position.move_toward(
		magnet_target.global_position,
		magnet_pull_speed * delta
	)

	if magnet_remaining <= 0.0:
		_clear_magnet_pull()


func set_pickup_config(new_config: PickupConfig) -> void:
	config = new_config
	if is_node_ready():
		_apply_dummy_visual()


func can_be_magnetized() -> bool:
	if is_collected or config == null:
		return false

	return config.magnetizable


func activate_magnet_pull(target: Node2D, duration: float, pull_speed: float, radius: float) -> void:
	if target == null or duration <= 0.0 or pull_speed <= 0.0:
		return
	if not can_be_magnetized():
		return
	if radius > 0.0 and global_position.distance_to(target.global_position) > radius:
		return

	magnet_target = target
	magnet_remaining = maxf(magnet_remaining, duration)
	magnet_pull_speed = pull_speed
	magnet_radius = radius


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
	if config == null:
		return

	for effect in config.effects:
		if effect != null and effect.has_method("apply"):
			effect.apply(player)


func _apply_dummy_visual() -> void:
	value_label.hide()
	value_label.text = ""

	if config == null:
		return

	visual.color = config.visual_color
	var label_text := _get_label_text()
	if not label_text.is_empty():
		value_label.show()
		value_label.text = label_text


func _get_label_text() -> String:
	if config == null:
		return ""
	if config.label_template.is_empty():
		return ""

	return config.label_template.format({
		"amount": config.amount,
		"display_name": config.display_name,
		"id": config.id,
	})


func _clear_magnet_pull() -> void:
	magnet_target = null
	magnet_remaining = 0.0
	magnet_pull_speed = 0.0
	magnet_radius = 0.0
