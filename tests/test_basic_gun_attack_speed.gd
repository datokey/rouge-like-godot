extends SceneTree

const BASIC := preload("res://resources/weapons/BasicGun.tres")
const ATTACK_SPEED_TALISMAN := preload("res://upgrades/talismans/attack_speed.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := BASIC.duplicate(true) as BasicGunDefinition
	definition.base_attack_speed = 1.0
	definition.attack_speed_reduction_per_level = 0.2
	definition.minimum_attack_speed = 0.01

	var build := BuildManager.new()
	var instance := WeaponInstance.new()
	instance.setup(definition, null, build)
	var attack_speed_upgrade := _find_attack_speed_upgrade(definition)

	_assert(
		instance.apply_stat_upgrade(attack_speed_upgrade, -0.20),
		"upgrade Attack Speed BasicGun gagal"
	)
	_assert(is_equal_approx(instance.get_basic_gun_base_attack_speed(), 1.0), "base stat berubah")
	_assert(
		is_equal_approx(instance.get_basic_gun_level_attack_speed_reduction(), 0.2),
		"pengurangan level bukan 0.2 detik"
	)
	_assert(is_equal_approx(instance.get_cooldown(), 0.8), "interval setelah level bukan 0.8 detik")
	_assert(
		not instance.local_percent_modifiers.has(&"weapon.cooldown"),
		"hasil upgrade tersimpan sebagai persen dan berisiko terakumulasi"
	)

	_assert(build.add_talisman(ATTACK_SPEED_TALISMAN, 0.25), "Talisman 25% gagal dipasang")
	_assert(
		is_equal_approx(instance.get_basic_gun_talisman_attack_speed_percent(), 0.25),
		"bonus Talisman bukan positif 25%"
	)
	_assert(is_equal_approx(instance.get_cooldown(), 0.64), "formula 0.8 / 1.25 bukan 0.64 detik")
	for _index in range(20):
		_assert(is_equal_approx(instance.get_cooldown(), 0.64), "getter menumpuk modifier berulang")

	instance.level = 99
	_assert(is_equal_approx(instance.get_cooldown(), 0.01), "minimum 0.01 detik tidak diterapkan")

	if _failed:
		quit(1)
	else:
		print("BasicGun attack speed regression tests: PASS")
		quit(0)


func _find_attack_speed_upgrade(definition: WeaponDefinition) -> WeaponUpgradeDefinition:
	for resource in definition.upgrade_options:
		var upgrade := resource as WeaponUpgradeDefinition
		if upgrade != null and upgrade.stat_type == WeaponUpgradeDefinition.StatType.FIRE_RATE:
			return upgrade
	return null


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
