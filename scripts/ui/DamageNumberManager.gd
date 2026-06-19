extends Control
class_name DamageNumberManager

@export_group("Pool")
@export_range(8, 256, 1) var pool_size := 64
@export_group("Timing")
@export_range(0.1, 3.0, 0.05) var display_duration := 0.8
@export_range(0.0, 3.0, 0.05) var fade_delay := 0.3
@export_range(0.01, 1.0, 0.01) var aggregate_interval := 0.12
@export_range(0.0, 200.0, 1.0) var aggregate_distance := 24.0
@export var aggregated_source_types: Array[StringName] = [&"beam", &"aura"]
@export_group("Motion")
@export_range(0.0, 300.0, 1.0) var rise_speed := 55.0
@export_range(0.0, 200.0, 1.0) var horizontal_offset := 18.0
@export_group("Style")
@export var normal_color := Color(1.0, 0.95, 0.75)
@export var critical_color := Color(1.0, 0.35, 0.2)
@export_range(8, 72, 1) var normal_font_size := 20
@export_range(8, 96, 1) var critical_font_size := 30
@export_range(0.01, 1.0, 0.01) var critical_pop_duration := 0.14
@export var label_size := Vector2(140.0, 52.0)

var _label_pool: Array[Label] = []
var _active_numbers: Array[Dictionary] = []
var _pending_aggregates: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_pool()
	if not EventBus.enemy_damaged.is_connected(_on_enemy_damaged):
		EventBus.enemy_damaged.connect(_on_enemy_damaged)


func _process(delta: float) -> void:
	_update_pending_aggregates(delta)
	_update_active_numbers(delta)


func _exit_tree() -> void:
	if EventBus.enemy_damaged.is_connected(_on_enemy_damaged):
		EventBus.enemy_damaged.disconnect(_on_enemy_damaged)


func _on_enemy_damaged(
	amount: int,
	is_critical: bool,
	world_position: Vector2,
	source_type: StringName
) -> void:
	if amount <= 0:
		return
	if aggregated_source_types.has(source_type):
		_add_aggregate(amount, is_critical, world_position, source_type)
		return
	_show_damage_number(amount, is_critical, world_position)


func _create_pool() -> void:
	for index in range(pool_size):
		var label := Label.new()
		label.name = "DamageNumber%d" % index
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = label_size
		label.pivot_offset = label_size * 0.5
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.04, 0.9))
		label.add_theme_constant_override("outline_size", 4)
		add_child(label)
		_label_pool.append(label)


func _add_aggregate(
	amount: int,
	is_critical: bool,
	world_position: Vector2,
	source_type: StringName
) -> void:
	for aggregate in _pending_aggregates:
		if aggregate["source_type"] != source_type:
			continue
		var aggregate_position: Vector2 = aggregate["world_position"]
		if aggregate_position.distance_to(world_position) > aggregate_distance:
			continue
		aggregate["amount"] = int(aggregate["amount"]) + amount
		aggregate["is_critical"] = bool(aggregate["is_critical"]) or is_critical
		aggregate["world_position"] = aggregate_position.lerp(world_position, 0.5)
		return
	_pending_aggregates.append({
		"amount": amount,
		"is_critical": is_critical,
		"world_position": world_position,
		"source_type": source_type,
		"remaining": aggregate_interval,
	})


func _update_pending_aggregates(delta: float) -> void:
	for index in range(_pending_aggregates.size() - 1, -1, -1):
		var aggregate := _pending_aggregates[index]
		aggregate["remaining"] = float(aggregate["remaining"]) - delta
		if float(aggregate["remaining"]) > 0.0:
			continue
		_show_damage_number(
			int(aggregate["amount"]),
			bool(aggregate["is_critical"]),
			aggregate["world_position"]
		)
		_pending_aggregates.remove_at(index)


func _show_damage_number(
	amount: int,
	is_critical: bool,
	world_position: Vector2
) -> void:
	var label := _acquire_label()
	var random_x := _random_range(-horizontal_offset, horizontal_offset)

	label.text = "%d!" % amount if is_critical else str(amount)
	label.scale = Vector2.ONE * (0.65 if is_critical else 1.0)
	label.modulate = Color.WHITE
	label.add_theme_color_override(
		"font_color",
		critical_color if is_critical else normal_color
	)
	label.add_theme_font_size_override(
		"font_size",
		critical_font_size if is_critical else normal_font_size
	)
	label.visible = true

	_active_numbers.append({
		"label": label,
		"elapsed": 0.0,
		"is_critical": is_critical,
		"world_position": world_position,
		"visual_offset": Vector2(random_x, 0.0),
	})


func _update_active_numbers(delta: float) -> void:
	var canvas_transform := get_viewport().get_canvas_transform()

	for index in range(_active_numbers.size() - 1, -1, -1):
		var entry := _active_numbers[index]
		var label := entry["label"] as Label
		var elapsed := float(entry["elapsed"]) + delta

		entry["elapsed"] = elapsed

		var visual_offset: Vector2 = entry["visual_offset"]
		visual_offset.y -= rise_speed * delta
		entry["visual_offset"] = visual_offset

		var world_position: Vector2 = entry["world_position"]
		var screen_position := canvas_transform * world_position

		label.position = (
			screen_position
			- label_size * 0.5
			+ visual_offset
		)

		var fade_duration := maxf(0.01, display_duration - fade_delay)
		label.modulate.a = 1.0 - clampf(
			(elapsed - fade_delay) / fade_duration,
			0.0,
			1.0
		)

		if bool(entry["is_critical"]):
			label.scale = Vector2.ONE * _get_critical_scale(elapsed)

		if elapsed >= display_duration:
			_release_number(index)


func _get_critical_scale(elapsed: float) -> float:
	if elapsed < critical_pop_duration:
		return lerpf(0.65, 1.25, elapsed / critical_pop_duration)
	var settle_duration := maxf(0.01, critical_pop_duration)
	return lerpf(1.25, 1.0, clampf((elapsed - critical_pop_duration) / settle_duration, 0.0, 1.0))


func _acquire_label() -> Label:
	for label in _label_pool:
		if not label.visible:
			return label
	# Pool penuh: daur ulang angka tertua, tidak membuat node baru saat hit terjadi.
	var oldest_index := 0
	var oldest_elapsed := -1.0
	for index in range(_active_numbers.size()):
		var elapsed := float(_active_numbers[index]["elapsed"])
		if elapsed > oldest_elapsed:
			oldest_elapsed = elapsed
			oldest_index = index
	var label := _active_numbers[oldest_index]["label"] as Label
	_active_numbers.remove_at(oldest_index)
	return label


func _release_number(index: int) -> void:
	var label := _active_numbers[index]["label"] as Label
	label.visible = false
	label.text = ""
	label.scale = Vector2.ONE
	label.modulate = Color.WHITE
	_active_numbers.remove_at(index)


func _random_range(min_value: float, max_value: float) -> float:
	var rng := get_node_or_null("/root/Rng")
	if rng != null:
		return float(rng.call("range_f", min_value, max_value))
	return randf_range(min_value, max_value)
