extends SceneTree

const BEAM_DEFINITION := preload("res://resources/weapons/BeamGun.tres")

var _failed := false


class TestPlayer extends Node2D:
	func get_nearest_enemy_in_range(attack_range: float) -> Node2D:
		var nearest: Node2D
		var nearest_distance := attack_range
		for node in get_tree().get_nodes_in_group("enemy"):
			var enemy := node as TestEnemy
			if enemy == null or enemy.is_dead:
				continue
			var distance := global_position.distance_to(enemy.global_position)
			if distance <= nearest_distance:
				nearest = enemy
				nearest_distance = distance
		return nearest


class TestEnemy extends CharacterBody2D:
	var is_dead := false

	func _init() -> void:
		add_to_group("enemy")
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 8.0
		collision.shape = shape
		add_child(collision)

	func take_damage(
		_amount: int,
		_direction: Vector2,
		_hit_position: Vector2,
		_is_critical: bool = false,
		_source_type: StringName = &"unknown"
	) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root
	var player := TestPlayer.new()
	scene_root.add_child(player)
	var holder := Node2D.new()
	player.add_child(holder)

	var definition := BEAM_DEFINITION.duplicate(true) as BeamWeaponDefinition
	definition.base_range = 100.0
	definition.base_beam_count = 2
	definition.max_beam_count = 3
	definition.minimum_lock_duration = 0.30
	definition.retarget_interval = 0.20
	definition.out_of_range_grace_time = 0.25
	definition.lock_range_margin = 20.0

	var manager := WeaponManager.new()
	manager.setup(player, holder, null)
	_assert(manager.add_weapon(definition), "BeamGun gagal dibuat")
	var beam := manager.weapon_nodes.get("beam_gun") as BeamGun
	beam.set_physics_process(false)

	var first := _spawn_enemy(scene_root, Vector2(50.0, 0.0))
	var second := _spawn_enemy(scene_root, Vector2(52.0, 10.0))
	var third := _spawn_enemy(scene_root, Vector2(70.0, -15.0))
	await physics_frame
	beam._start_beam(first)
	var locked_first := beam.beam_targets[0]
	var locked_second := beam.beam_targets[1]
	_assert(locked_first != locked_second, "multiple beam tidak memilih target unik")

	# Jarak yang hampir sama dan perubahan urutan tidak boleh mencuri lock aktif.
	second.position = Vector2(45.0, 10.0)
	beam._update_target_lock_state(0.40)
	beam._retarget_missing_slots()
	_assert(beam.beam_targets[0] == locked_first, "slot pertama berpindah ke target yang sedikit lebih dekat")
	_assert(beam.beam_targets[1] == locked_second, "slot kedua kehilangan persistent lock")

	# Target mati dilepas, lalu hanya slot kosong yang mencari pengganti.
	locked_first.is_dead = true
	beam._update_target_lock_state(0.01)
	_assert(beam.beam_targets[0] == null, "target mati tidak dilepas")
	_assert(beam.beam_targets[1] == locked_second, "kematian target mengubah slot beam lain")
	beam._retarget_missing_slots()
	_assert(beam.beam_targets[0] == third, "slot kosong tidak memilih target hidup yang unik")

	# Keluar sebentar lalu masuk kembali harus mereset grace timer.
	third.position = Vector2(125.0, 0.0)
	beam._update_target_lock_state(0.15)
	_assert(beam.beam_targets[0] == third, "target dilepas sebelum grace time habis")
	third.position = Vector2(95.0, 0.0)
	beam._update_target_lock_state(0.05)
	_assert(beam.beam_targets[0] == third, "target dalam hysteresis tidak dipertahankan")
	_assert(is_zero_approx(beam.beam_out_of_range_elapsed[0]), "grace timer tidak direset saat target masuk range")

	# Setelah melewati margin dan grace, lock boleh dilepas.
	third.position = Vector2(125.0, 0.0)
	beam._update_target_lock_state(0.30)
	_assert(beam.beam_targets[0] == null, "target di luar range+margin tidak dilepas setelah grace")

	# Jika hanya satu target tersedia, semua slot boleh memakai target yang sama.
	locked_first.is_dead = true
	third.is_dead = true
	second.position = Vector2(60.0, 0.0)
	beam._ensure_target_slots(3)
	for index in range(beam.beam_targets.size()):
		beam._release_target_slot(index)
	beam._retarget_missing_slots()
	_assert(beam.beam_targets.size() == 3, "jumlah slot beam tidak sesuai")
	_assert(
		beam.beam_targets.all(func(target: Node2D) -> bool: return target == second),
		"satu enemy tidak dipakai ulang oleh seluruh slot beam"
	)

	if _failed:
		quit(1)
	else:
		print("Beam target-lock regression tests: PASS")
		quit(0)


func _spawn_enemy(parent: Node, position: Vector2) -> TestEnemy:
	var enemy := TestEnemy.new()
	enemy.position = position
	parent.add_child(enemy)
	return enemy


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
