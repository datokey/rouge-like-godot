extends WeaponBase
class_name KoalisiDadakan

# Weapon tipe SUMMON — memanggil minion Simpatisan secara berkala.
# Semua value dikonfigurasi lewat SummonWeaponDefinition resource.

var _summon_elapsed := INF
var _active_minions: Array[Node] = []
var _player_is_dead := false


func _on_weapon_setup() -> void:
	# Langsung summon minion pertama saat weapon diaktifkan.
	_free_active_minions()
	_player_is_dead = false
	_summon_elapsed = INF
	var event_bus := get_node_or_null("/root/EventBus")
	var death_callback := Callable(self, "_on_player_died")
	if event_bus != null and not event_bus.is_connected("player_died", death_callback):
		event_bus.connect("player_died", death_callback)


func _physics_process(delta: float) -> void:
	if _player_is_dead:
		return

	var player_node := get_owner_node()
	if not is_instance_valid(player_node):
		_free_active_minions()
		return

	_cleanup_dead_minions()

	var max_minions := weapon_instance.get_summon_max_active()
	if _active_minions.size() >= max_minions:
		# Slot penuh — tunggu sampai ada minion yang hilang.
		return

	_summon_elapsed += delta
	if _summon_elapsed < weapon_instance.get_summon_cooldown():
		return

	_summon_minion()


func _cleanup_dead_minions() -> void:
	# Hapus entry minion yang sudah queue_free atau tidak valid.
	var alive: Array[Node] = []
	for minion in _active_minions:
		if is_instance_valid(minion):
			alive.append(minion)
	_active_minions = alive


func _summon_minion() -> void:
	var minion_scene := weapon_instance.get_summon_minion_scene()
	if minion_scene == null:
		return

	if weapon_instance.get_summon_projectile_scene() == null:
		return

	var player_node := get_owner_node()
	if player_node == null:
		return

	var minion: Node2D = minion_scene.instantiate() as Node2D
	if minion == null:
		return

	# Tambahkan ke scene root agar minion bisa bergerak bebas.
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		minion.queue_free()
		return

	scene_root.add_child(minion)
	minion.global_position = player_node.global_position

	if not minion.has_method("setup"):
		minion.queue_free()
		return

	minion.call(
		"setup",
		weapon_instance,
		weapon_instance.get_summon_lifetime(),
		_active_minions.size()
	)

	_active_minions.append(minion)
	minion.tree_exited.connect(_on_minion_tree_exited.bind(minion), CONNECT_ONE_SHOT)
	_summon_elapsed = 0.0


# Lifecycle registry summon.

func _on_minion_tree_exited(minion: Node) -> void:
	_active_minions.erase(minion)


func _on_player_died() -> void:
	_player_is_dead = true
	_free_active_minions()


func _free_active_minions() -> void:
	var minions := _active_minions.duplicate()
	_active_minions.clear()
	for minion in minions:
		if is_instance_valid(minion):
			minion.queue_free()


func _exit_tree() -> void:
	_free_active_minions()
