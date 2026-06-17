extends "res://scripts/gameplay/weapons/WeaponBase.gd"
class_name KoalisiDadakan

# Weapon tipe SUMMON — memanggil minion Simpatisan secara berkala.
# Semua value dikonfigurasi lewat SummonWeaponDefinition resource.

var _summon_timer := 0.0
var _active_minions: Array[Node] = []


func _on_weapon_setup() -> void:
	# Langsung summon minion pertama saat weapon diaktifkan.
	_summon_timer = 0.0


func _physics_process(delta: float) -> void:
	if get_owner_node() == null:
		return

	_cleanup_dead_minions()

	var max_minions: int = _get_max_active_minions()
	if _active_minions.size() >= max_minions:
		# Slot penuh — tunggu sampai ada minion yang hilang.
		return

	_summon_timer = maxf(_summon_timer - delta, 0.0)
	if _summon_timer > 0.0:
		return

	_summon_minion()
	_summon_timer = get_cooldown()


func _cleanup_dead_minions() -> void:
	# Hapus entry minion yang sudah queue_free atau tidak valid.
	var alive: Array[Node] = []
	for minion in _active_minions:
		if is_instance_valid(minion):
			alive.append(minion)
	_active_minions = alive


func _summon_minion() -> void:
	var def: SummonWeaponDefinition = _get_summon_definition()
	if def == null:
		return

	var minion_scene: PackedScene = def.minion_scene
	if minion_scene == null:
		return

	var projectile_scene: PackedScene = def.minion_projectile_scene
	if projectile_scene == null:
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

	if minion.has_method("setup"):
		minion.call(
			"setup",
			player_node,
			_get_minion_damage(),
			get_range(),
			def.minion_attack_cooldown,
			def.minion_projectile_speed,
			def.minion_lifetime,
			_active_minions.size(),    # orbit_index
			def.minion_orbit_radius,
			projectile_scene
		)

	_active_minions.append(minion)


# ── Helpers untuk baca data dari SummonWeaponDefinition ──────────────────────

func _get_summon_definition() -> SummonWeaponDefinition:
	if weapon_instance == null:
		return null
	var def: Resource = weapon_instance.definition
	if def is SummonWeaponDefinition:
		return def as SummonWeaponDefinition
	return null


func _get_max_active_minions() -> int:
	var def: SummonWeaponDefinition = _get_summon_definition()
	if def == null:
		return 1
	return def.max_active_minions


func _get_minion_damage() -> int:
	# Damage minion = damage weapon (yang sudah dikalkulasi level + ability modifier)
	# dikali minion_damage_multiplier.
	var base_damage: float = float(get_damage())
	var def: SummonWeaponDefinition = _get_summon_definition()
	var multiplier := 0.7
	if def != null:
		multiplier = def.minion_damage_multiplier
	return maxi(1, roundi(base_damage * multiplier))
