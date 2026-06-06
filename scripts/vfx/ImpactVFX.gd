extends Node2D

@export var lifetime := 0.12

@onready var visual: Polygon2D = $Visual

var elapsed_time := 0.0
var start_scale := Vector2.ONE


func _ready() -> void:
	start_scale = scale


func setup(vfx_scale: float) -> void:
	scale = Vector2.ONE * vfx_scale
	start_scale = scale


func _process(delta: float) -> void:
	elapsed_time += delta
	var progress := clampf(elapsed_time / lifetime, 0.0, 1.0)
	scale = start_scale.lerp(start_scale * 1.6, progress)
	modulate.a = 1.0 - progress

	if elapsed_time >= lifetime:
		queue_free()
