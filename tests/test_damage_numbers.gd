extends SceneTree

const ENEMY_SCENE := preload("res://scenes/entities/Enemy.tscn")
const DAMAGE_NUMBER_MANAGER := preload("res://scripts/ui/DamageNumberManager.gd")

var _failed := false
var _event_amount := 0
var _event_is_critical := false
var _event_position := Vector2.ZERO
var _event_source := &""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root

	var canvas := CanvasLayer.new()
	scene_root.add_child(canvas)
	var manager := DAMAGE_NUMBER_MANAGER.new() as DamageNumberManager
	manager.pool_size = 8
	manager.aggregate_interval = 0.1
	canvas.add_child(manager)
	await process_frame
	_assert(manager._label_pool.size() == 8, "Damage number pool tidak dibuat sesuai konfigurasi")

	EventBus.enemy_damaged.connect(_capture_damage_event)
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	enemy.global_position = Vector2(80.0, 40.0)
	scene_root.add_child(enemy)
	await process_frame
	enemy.call("take_damage", 7, Vector2.ZERO, enemy.global_position, true, &"projectile")
	_assert(_event_amount == 7, "Event tidak membawa final damage")
	_assert(_event_is_critical, "Status critical hilang dari event")
	_assert(_event_position == enemy.global_position, "World position event salah")
	_assert(_event_source == &"projectile", "Source type event salah")
	_assert(manager._active_numbers.size() == 1, "Projectile hit tidak langsung ditampilkan")
	var critical_label := manager._active_numbers[0]["label"] as Label
	_assert(critical_label.text == "7!", "Critical damage tidak memakai tanda seru")

	manager._on_enemy_damaged(2, false, Vector2(100.0, 100.0), &"beam")
	manager._on_enemy_damaged(3, false, Vector2(104.0, 100.0), &"beam")
	_assert(manager._pending_aggregates.size() == 1, "Beam damage tidak digabung")
	manager._process(0.11)
	_assert(manager._pending_aggregates.is_empty(), "Aggregate beam tidak di-flush")
	_assert(manager._active_numbers.size() == 2, "Aggregate beam tidak ditampilkan")
	var beam_label := manager._active_numbers[1]["label"] as Label
	_assert(beam_label.text == "5", "Jumlah aggregate beam salah")
	_assert(manager._label_pool.size() == 8, "Hit membuat node di luar object pool")

	EventBus.enemy_damaged.disconnect(_capture_damage_event)
	if _failed:
		quit(1)
	else:
		print("Damage number regression tests: PASS")
		quit(0)


func _capture_damage_event(
	amount: int,
	is_critical: bool,
	world_position: Vector2,
	source_type: StringName
) -> void:
	_event_amount = amount
	_event_is_critical = is_critical
	_event_position = world_position
	_event_source = source_type


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
