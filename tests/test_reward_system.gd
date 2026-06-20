extends SceneTree

const POOL := preload("res://upgrades/default_reward_pool.tres")
const BASIC := preload("res://resources/weapons/BasicGun.tres")
const BEAM := preload("res://resources/weapons/BeamGun.tres")
const AURA := preload("res://resources/weapons/AuraWeapon.tres")
const SUMMON := preload("res://resources/weapons/KoalisiDadakan.tres")

var _failed := false


class TestPlayer extends Node2D:
	var healed := 0

	func get_nearest_enemy_in_range(_attack_range: float) -> Node2D:
		return null

	func heal(amount: int) -> void:
		healed += amount


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_weapon_candidate_filtering()
	_test_weapon_level_upgrade_isolation_and_caps()
	_test_talisman_slot_and_compatibility_filtering()
	_test_talisman_rarity_level_and_additive_formula()
	_test_projectile_talisman_milestones()
	_test_modifier_scope()
	_test_utility_collection()
	_test_controlled_rng_and_fallback()
	if _failed:
		quit(1)
	else:
		print("Reward system regression tests: PASS")
		quit(0)


func _test_weapon_candidate_filtering() -> void:
	var beam_context := {
		"owned_weapon_ids": ["beam_gun"],
		"can_add_weapon": true,
		"owned_weapon_definitions": {"beam_gun": BEAM},
		"weapon_upgrade_stacks": {"beam_gun": {}},
		"owned_compatibility_tags": BEAM.compatibility_tags,
		"owned_talisman_levels": {},
		"can_add_talisman": true,
		"utility_stacks": {},
	}
	var candidates := POOL.get_valid_candidates(beam_context)
	var rolled_offers := POOL.roll_offers(beam_context, 3)
	var rolled_ids: Array[String] = []
	for offer in rolled_offers:
		_assert(not rolled_ids.has(offer.get_unique_id()), "RNG menghasilkan pilihan duplikat")
		rolled_ids.append(offer.get_unique_id())
		_assert(offer.rarity_multiplier >= 1.0, "rarity multiplier tidak dihitung")
	_assert(rolled_offers.size() == 3, "RNG tidak menghasilkan tiga pilihan")
	var beam_upgrade_keys: Array[StringName] = []
	for offer in candidates:
		if offer.category == RewardOffer.Category.WEAPON_UPGRADE:
			beam_upgrade_keys.append(offer.weapon_upgrade.modifier_key)
		_assert(not (
			offer.category == RewardOffer.Category.WEAPON_NEW
			and offer.weapon_id == "beam_gun"
		), "weapon yang sudah dimiliki muncul sebagai weapon baru")

	_assert(beam_upgrade_keys.has(&"weapon.beam_width"), "Beam width tidak masuk upgrade BeamGun")
	_assert(beam_upgrade_keys.has(&"weapon.beam_count"), "Beam count tidak masuk upgrade BeamGun")
	_assert(not beam_upgrade_keys.has(&"weapon.projectile_speed"), "BeamGun mendapat projectile speed")
	_assert(not beam_upgrade_keys.has(&"weapon.projectile_size"), "BeamGun mendapat projectile size")

	var full_context := beam_context.duplicate(true)
	full_context["owned_weapon_ids"] = ["basic_gun", "beam_gun", "weapon_aura", "koalisi_dadakan"]
	full_context["can_add_weapon"] = false
	full_context["owned_weapon_definitions"] = {
		"basic_gun": BASIC,
		"beam_gun": BEAM,
		"weapon_aura": AURA,
		"koalisi_dadakan": SUMMON,
	}
	full_context["weapon_upgrade_stacks"] = {
		"basic_gun": {}, "beam_gun": {}, "weapon_aura": {}, "koalisi_dadakan": {},
	}
	var full_candidates := POOL.get_valid_candidates(full_context)
	for offer in full_candidates:
		_assert(offer.category != RewardOffer.Category.WEAPON_NEW, "weapon baru muncul saat empat slot penuh")
	_assert(
		_get_candidate_upgrade_ids(full_candidates, "beam_gun") == [
			"ammo_capacity", "attack_speed", "beam_count", "beam_length", "beam_width", "damage", "reload_duration",
		],
		"reward pool BeamGun memuat stat di luar konfigurasi"
	)
	_assert(
		_get_candidate_upgrade_ids(full_candidates, "weapon_aura") == [
			"damage", "radius", "tick_rate",
		],
		"reward pool Aura memuat stat di luar konfigurasi"
	)
	_assert(
		_get_candidate_upgrade_ids(full_candidates, "koalisi_dadakan") == [
			"attack_range", "minion_projectile_count", "pierce", "summon_attack_speed", "summon_damage",
		],
		"reward pool Koalisi Dadakan memuat stat di luar konfigurasi"
	)

	var maxed_context := beam_context.duplicate(true)
	maxed_context["owned_weapon_levels"] = {"beam_gun": 99}
	maxed_context["owned_weapon_max_levels"] = {"beam_gun": 99}
	for offer in POOL.get_valid_candidates(maxed_context):
		_assert(offer.category != RewardOffer.Category.WEAPON_UPGRADE, "upgrade maksimal masih berada di pool")

	_assert(_get_upgrade_types(BASIC) == [0, 1, 4, 5, 6], "upgrade_options BasicGun tidak sesuai")
	_assert(
		_get_upgrade_ids(BASIC) == [
			"attack_speed", "projectile_count", "attack_range", "pierce", "damage",
		],
		"urutan upgrade_options BasicGun tidak sesuai"
	)
	_assert(_get_upgrade_types(BEAM) == [0, 2, 4, 6, 7, 8, 9], "upgrade_options BeamGun tidak sesuai")
	_assert(_get_upgrade_types(AURA) == [0, 6, 7], "upgrade_options Aura tidak sesuai")
	_assert(_get_upgrade_types(SUMMON) == [0, 3, 4, 5, 6], "upgrade_options Koalisi tidak sesuai")
	_assert(
		_get_sorted_upgrade_ids(BEAM) == ["ammo_capacity", "attack_speed", "beam_count", "beam_length", "beam_width", "damage", "reload_duration"],
		"ID upgrade BeamGun tidak sesuai"
	)
	_assert(
		_get_sorted_upgrade_ids(AURA) == ["damage", "radius", "tick_rate"],
		"ID upgrade Aura tidak sesuai"
	)
	_assert(
		_get_sorted_upgrade_ids(SUMMON) == [
			"attack_range", "minion_projectile_count", "pierce", "summon_attack_speed", "summon_damage",
		],
		"ID upgrade Koalisi Dadakan tidak sesuai"
	)


func _test_weapon_level_upgrade_isolation_and_caps() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root
	var player := TestPlayer.new()
	scene_root.add_child(player)
	var holder := Node2D.new()
	player.add_child(holder)
	var build := BuildManager.new()
	build.setup(player)
	var manager := WeaponManager.new()
	manager.setup(player, holder, build)
	_assert(manager.add_weapon(BASIC), "BasicGun gagal dibuat untuk test level")
	_assert(manager.add_weapon(BEAM), "BeamGun gagal dibuat untuk test isolasi")

	var basic := manager.get_weapon_instance("basic_gun")
	var beam := manager.get_weapon_instance("beam_gun")
	var basic_damage_before := basic.get_damage_preview()
	var beam_damage_before := beam.get_damage_preview()
	var damage_upgrade := _find_weapon_upgrade(BASIC, WeaponUpgradeDefinition.StatType.DAMAGE)
	_assert(manager.apply_stat_upgrade("basic_gun", damage_upgrade, 0.15), "upgrade damage BasicGun gagal")
	_assert(basic.level == 2, "level BasicGun tidak bertambah")
	_assert(beam.level == 1, "level BeamGun ikut berubah")
	_assert(basic.get_damage_preview() > basic_damage_before, "damage BasicGun tidak bertambah")
	_assert(beam.get_damage_preview() == beam_damage_before, "modifier BasicGun bocor ke BeamGun")

	var count_upgrade := _find_weapon_upgrade(BASIC, WeaponUpgradeDefinition.StatType.PROJECTILE_COUNT)
	while basic.can_apply_stat_upgrade(count_upgrade):
		_assert(manager.apply_stat_upgrade("basic_gun", count_upgrade, 7.0), "upgrade projectile count gagal")
	_assert(basic.get_projectile_count() == int(BASIC.max_projectile_count), "projectile count melewati cap")
	_assert(not basic.can_apply_stat_upgrade(count_upgrade), "projectile count cap masih ditawarkan")
	var offer_context := manager.get_offer_context()
	var basic_availability: Dictionary = offer_context["weapon_upgrade_availability"]["basic_gun"]
	_assert(
		not bool(basic_availability[count_upgrade.id]),
		"projectile count yang mencapai cap masih ditandai valid untuk reward"
	)
	for offer in POOL.get_valid_candidates(offer_context):
		_assert(
			not (
				offer.category == RewardOffer.Category.WEAPON_UPGRADE
				and offer.weapon_id == "basic_gun"
				and offer.weapon_upgrade.id == count_upgrade.id
			),
			"projectile count yang mencapai cap masih masuk reward pool"
		)

	var pierce_definition := BASIC.duplicate(true) as WeaponDefinition
	var pierce_instance := WeaponInstance.new()
	pierce_instance.setup(pierce_definition, player, build)
	var pierce_upgrade := _find_weapon_upgrade(BASIC, WeaponUpgradeDefinition.StatType.PIERCE)
	_assert(pierce_instance.apply_stat_upgrade(pierce_upgrade, 0.02), "Pierce Common gagal")
	_assert(pierce_instance.get_projectile_pierce_count() == 0, "Pierce 2% salah dikonversi")
	_assert(pierce_instance.apply_stat_upgrade(pierce_upgrade, 0.07), "Pierce Rare gagal")
	_assert(pierce_instance.get_projectile_pierce_count() == 0, "Pierce 9% salah dikonversi")
	_assert(pierce_instance.apply_stat_upgrade(pierce_upgrade, 0.02), "Pierce Common kedua gagal")
	_assert(pierce_instance.get_projectile_pierce_count() == 1, "Pierce 11% tidak menjadi satu pierce")

	var max_level_instance := WeaponInstance.new()
	max_level_instance.setup(BASIC, player, build, 99)
	_assert(not max_level_instance.can_apply_stat_upgrade(damage_upgrade), "weapon level 99 masih dapat upgrade")


func _test_talisman_slot_and_compatibility_filtering() -> void:
	var context := {
		"owned_weapon_ids": ["beam_gun"],
		"can_add_weapon": false,
		"owned_weapon_definitions": {"beam_gun": BEAM},
		"weapon_upgrade_stacks": {"beam_gun": {}},
		"owned_compatibility_tags": BEAM.compatibility_tags,
		"owned_talisman_levels": {},
		"can_add_talisman": true,
		"utility_stacks": {},
	}
	for offer in POOL.get_valid_candidates(context):
		if offer.talisman != null:
			_assert(offer.talisman.id != "projectile_count", "Projectile Count Talisman muncul untuk BeamGun")

	context["owned_talisman_levels"] = {
		"attack_speed": 1,
		"damage": 1,
		"critical_chance": 1,
		"life_steal": 1,
	}
	context["can_add_talisman"] = false
	for offer in POOL.get_valid_candidates(context):
		if offer.talisman != null:
			_assert(context["owned_talisman_levels"].has(offer.talisman.id), "talisman baru muncul saat slot penuh")


func _test_talisman_rarity_level_and_additive_formula() -> void:
	var damage_talisman := _find_talisman("damage")
	var original_value := damage_talisman.value
	var original_max_level := damage_talisman.max_level
	_assert(original_max_level == 99, "max level default Talisman bukan 99")
	_assert(
		POOL.talisman_percent_upgrade_values == [0.02, 0.04, 0.07, 0.10, 0.15],
		"tabel rarity Talisman bukan 2/4/7/10/15 persen"
	)
	for rarity_index in range(RewardOffer.Rarity.size()):
		var offer := RewardOffer.new()
		offer.category = RewardOffer.Category.TALISMAN_UPGRADE
		offer.talisman = damage_talisman
		POOL._roll_rarity(offer, 0.0)
		# Validasi nilai dilakukan langsung dari tabel karena rarity hasil roll memang acak.
		var expected := damage_talisman.get_upgrade_value(
			POOL.talisman_percent_upgrade_values[int(offer.rarity)]
		)
		_assert(is_equal_approx(offer.talisman_upgrade_value, expected), "nilai Talisman tidak mengikuti rarity")

	var player := TestPlayer.new()
	root.add_child(player)
	var build := BuildManager.new()
	build.setup(player)
	var definition := BASIC.duplicate(true) as WeaponDefinition
	definition.base_damage = 100.0
	definition.damage_per_level = 0.0
	var instance := WeaponInstance.new()
	instance.setup(definition, player, build)
	var damage_upgrade := _find_weapon_upgrade(definition, WeaponUpgradeDefinition.StatType.DAMAGE)
	_assert(instance.apply_stat_upgrade(damage_upgrade, 0.20), "upgrade weapon 20% gagal")
	_assert(build.add_talisman(damage_talisman, 0.10), "upgrade Talisman 10% gagal")
	_assert(instance.get_damage_preview() == 130, "bonus weapon dan Talisman masih multiplicative")

	var speed_definition := BASIC.duplicate(true) as BasicGunDefinition
	speed_definition.base_attack_speed = 1.0
	speed_definition.attack_speed_reduction_per_level = 0.2
	speed_definition.minimum_attack_speed = 0.01
	var speed_build := BuildManager.new()
	speed_build.setup(player)
	var speed_instance := WeaponInstance.new()
	speed_instance.setup(speed_definition, player, speed_build)
	var fire_rate_upgrade := _find_weapon_upgrade(
		speed_definition,
		WeaponUpgradeDefinition.StatType.FIRE_RATE
	)
	_assert(
		speed_instance.apply_stat_upgrade(fire_rate_upgrade, -0.20),
		"upgrade level Attack Speed BasicGun gagal"
	)
	_assert(
		is_equal_approx(speed_instance.get_basic_gun_base_attack_speed(), 1.0),
		"base Attack Speed berubah saat dihitung"
	)
	_assert(
		is_equal_approx(speed_instance.get_basic_gun_level_attack_speed_reduction(), 0.2),
		"pengurangan Attack Speed level salah"
	)
	_assert(is_equal_approx(speed_instance.get_cooldown(), 0.8), "Attack Speed setelah level bukan 0.8 detik")
	_assert(
		speed_build.add_talisman(_find_talisman("attack_speed"), 0.25),
		"bonus Attack Speed Talisman 25% gagal"
	)
	_assert(
		is_equal_approx(speed_instance.get_basic_gun_talisman_attack_speed_percent(), 0.25),
		"persentase Attack Speed Talisman salah"
	)
	_assert(is_equal_approx(speed_instance.get_cooldown(), 0.64), "Attack Speed akhir bukan 0.64 detik")
	for _calculation in range(10):
		_assert(
			is_equal_approx(speed_instance.get_cooldown(), 0.64),
			"Attack Speed terakumulasi ganda saat dihitung ulang"
		)
	speed_instance.level = 99
	_assert(is_equal_approx(speed_instance.get_cooldown(), 0.01), "Attack Speed melewati minimum 0.01 detik")
	_assert(int(speed_build.talisman_levels.get("attack_speed", 0)) == 1, "level Talisman tidak mandiri")
	for _level in range(2, damage_talisman.max_level + 1):
		_assert(build.add_talisman(damage_talisman, 0.01), "Talisman gagal mencapai level 99")
	_assert(int(build.talisman_levels[damage_talisman.id]) == 99, "level Talisman tidak mencapai 99")
	_assert(not build.add_talisman(damage_talisman, 0.01), "Talisman melewati level 99")
	_assert(is_equal_approx(damage_talisman.value, original_value), "Resource Talisman berubah saat runtime")
	_assert(damage_talisman.max_level == original_max_level, "max level Resource Talisman berubah saat runtime")

	var maxed_context := {
		"owned_talisman_levels": {damage_talisman.id: 99},
		"owned_talisman_bonuses": {damage_talisman.id: 1.0},
		"can_add_talisman": false,
		"owned_compatibility_tags": BASIC.compatibility_tags,
		"utility_stacks": {},
	}
	for candidate in POOL.get_valid_candidates(maxed_context):
		_assert(candidate.talisman != damage_talisman, "Talisman level 99 masih muncul di reward pool")
	player.queue_free()


func _test_modifier_scope() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root
	var player := TestPlayer.new()
	scene_root.add_child(player)
	var holder := Node2D.new()
	player.add_child(holder)
	var build := BuildManager.new()
	build.setup(player)
	var manager := WeaponManager.new()
	manager.setup(player, holder, build)
	_assert(manager.add_weapon(BASIC), "BasicGun gagal dibuat untuk test modifier")
	_assert(manager.add_weapon(BEAM), "BeamGun gagal dibuat untuk test modifier")
	var projectile_talisman := _find_talisman("projectile_count")
	_assert(build.add_talisman(projectile_talisman, 1.0), "Projectile Count Talisman gagal dipasang")
	_assert(manager.get_weapon_instance("basic_gun").get_projectile_count() == 2, "Projectile Count tidak memengaruhi BasicGun")
	_assert(manager.get_weapon_instance("beam_gun").get_beam_count() == 1, "Projectile Count bocor ke jumlah beam")


func _test_projectile_talisman_milestones() -> void:
	var projectile_talisman := _find_talisman("projectile_count")
	var original_milestone := projectile_talisman.milestone_percent
	var cases := [
		{"upgrades": [0.99], "percent": 0.99, "bonus": 0, "remainder": 0.99},
		{"upgrades": [0.85, 0.15], "percent": 1.00, "bonus": 1, "remainder": 0.00},
		{"upgrades": [0.85, 0.35], "percent": 1.20, "bonus": 1, "remainder": 0.20},
		{"upgrades": [1.20, 0.80], "percent": 2.00, "bonus": 2, "remainder": 0.00},
	]
	for test_case in cases:
		var build := BuildManager.new()
		for upgrade_value in test_case.upgrades:
			_assert(build.add_talisman(projectile_talisman, upgrade_value), "akumulasi milestone gagal")
		var instance := WeaponInstance.new()
		instance.setup(BASIC, null, build)
		_assert(
			instance.get_projectile_count() == int(BASIC.base_projectile_count) + test_case.bonus,
			"milestone %.0f%% menghasilkan projectile yang salah" % (test_case.percent * 100.0)
		)
		var progress := build.get_talisman_milestone_progress(projectile_talisman.id)
		_assert(int(progress["completed"]) == test_case.bonus, "jumlah milestone salah")
		_assert(
			is_equal_approx(float(progress["progress_percent"]), test_case.remainder),
			"sisa progress milestone salah"
		)

	var capped_definition := BASIC.duplicate(true) as ProjectileWeaponDefinition
	capped_definition.max_projectile_count = 2
	var capped_build := BuildManager.new()
	_assert(capped_build.add_talisman(projectile_talisman, 2.50), "setup cap milestone gagal")
	var capped_instance := WeaponInstance.new()
	capped_instance.setup(capped_definition, null, capped_build)
	_assert(capped_instance.get_projectile_count() == 2, "milestone melewati cap weapon")
	var capped_progress := capped_build.get_talisman_milestone_progress(projectile_talisman.id)
	_assert(is_equal_approx(float(capped_progress["progress_percent"]), 0.50), "cap menghapus sisa progress")

	var replacement_definition := BASIC.duplicate(true) as ProjectileWeaponDefinition
	replacement_definition.base_projectile_count = 3
	replacement_definition.max_projectile_count = 8
	var replacement_instance := WeaponInstance.new()
	replacement_instance.setup(replacement_definition, null, capped_build)
	_assert(replacement_instance.get_projectile_count() == 5, "progress tidak terbawa saat ganti weapon")
	_assert(
		is_equal_approx(projectile_talisman.milestone_percent, original_milestone),
		"Resource milestone berubah saat runtime"
	)


func _test_controlled_rng_and_fallback() -> void:
	var context := {
		"owned_weapon_ids": ["beam_gun"],
		"can_add_weapon": true,
		"owned_weapon_definitions": {"beam_gun": BEAM},
		"weapon_upgrade_stacks": {"beam_gun": {}},
		"owned_compatibility_tags": BEAM.compatibility_tags,
		"owned_talisman_levels": {},
		"can_add_talisman": true,
		"utility_stacks": {},
		"luck": 0.0,
	}
	var rng := root.get_node_or_null("Rng")
	_assert(rng != null, "Autoload Rng tidak tersedia")
	if rng != null:
		rng.set_seed(91234)
	var first_roll := POOL.roll_offers(context, 3)
	if rng != null:
		rng.set_seed(91234)
	var second_roll := POOL.roll_offers(context, 3)
	for index in range(first_roll.size()):
		_assert(first_roll[index].get_unique_id() == second_roll[index].get_unique_id(), "seed yang sama menghasilkan reward berbeda")
		_assert(first_roll[index].rarity == second_roll[index].rarity, "seed yang sama menghasilkan rarity berbeda")
		if first_roll[index].category == RewardOffer.Category.WEAPON_UPGRADE:
			var upgrade_offer := first_roll[index]
			var expected_value := upgrade_offer.weapon_upgrade.get_rarity_value(
				int(upgrade_offer.rarity),
				POOL.weapon_percent_upgrade_values,
				POOL.weapon_count_upgrade_values
			)
			_assert(
				is_equal_approx(upgrade_offer.weapon_upgrade_value, expected_value),
				"nilai upgrade weapon tidak sesuai rarity"
			)

	var empty_context := {
		"owned_weapon_ids": [],
		"can_add_weapon": false,
		"owned_weapon_definitions": {},
		"weapon_upgrade_stacks": {},
		"owned_compatibility_tags": [],
		"owned_talisman_levels": {},
		"can_add_talisman": false,
		"utility_stacks": {"pickup_radius": 5, "revive": 3},
		"luck": 0.0,
	}
	var fallback_offers := POOL.roll_offers(empty_context, 3)
	_assert(fallback_offers.size() == 3, "fallback tidak mengisi jumlah kartu")
	for offer in fallback_offers:
		_assert(offer.utility != null and offer.utility.id.begins_with("fallback_"), "reward non-fallback lolos saat pool kosong")


func _test_utility_collection() -> void:
	var build := BuildManager.new()
	var revive := _find_utility("revive")
	_assert(revive != null, "utility Revive tidak ditemukan")
	_assert(build.add_utility(revive), "stack Revive pertama gagal")
	_assert(build.add_utility(revive), "stack Revive kedua gagal")
	_assert(build.utility_stacks.get("revive", 0) == 2, "utility masih memakai konsep level")
	_assert(build.add_utility(revive), "stack Revive ketiga gagal")
	_assert(not build.add_utility(revive), "Revive melewati max_stack")

	var context := {
		"owned_weapon_ids": [],
		"can_add_weapon": false,
		"owned_weapon_definitions": {},
		"weapon_upgrade_stacks": {},
		"owned_compatibility_tags": [],
		"owned_talisman_levels": {},
		"can_add_talisman": false,
		"utility_stacks": {"pickup_radius": 0, "revive": 0},
		"luck": 0.0,
	}
	for offer in POOL.get_valid_candidates(context):
		if offer.category != RewardOffer.Category.UTILITY:
			continue
		_assert(int(offer.rarity) == int(offer.utility.rarity), "rarity utility tidak berasal dari definition")
		_assert(is_equal_approx(offer.rarity_multiplier, 1.0), "rarity mengubah efek per stack utility")


func _find_talisman(talisman_id: String) -> TalismanDefinition:
	for resource in POOL.talisman_definitions:
		var talisman := resource as TalismanDefinition
		if talisman != null and talisman.id == talisman_id:
			return talisman
	return null


func _find_utility(utility_id: String) -> UtilityDefinition:
	for resource in POOL.utility_definitions:
		var utility := resource as UtilityDefinition
		if utility != null and utility.id == utility_id:
			return utility
	return null


func _find_weapon_upgrade(
	definition: WeaponDefinition,
	stat_type: WeaponUpgradeDefinition.StatType
) -> WeaponUpgradeDefinition:
	for resource in definition.upgrade_options:
		var upgrade := resource as WeaponUpgradeDefinition
		if upgrade != null and upgrade.stat_type == stat_type:
			return upgrade
	return null


func _get_upgrade_types(definition: WeaponDefinition) -> Array[int]:
	var types: Array[int] = []
	for resource in definition.upgrade_options:
		var upgrade := resource as WeaponUpgradeDefinition
		if upgrade != null:
			types.append(int(upgrade.stat_type))
	types.sort()
	return types


func _get_upgrade_ids(definition: WeaponDefinition) -> Array[String]:
	var ids: Array[String] = []
	for resource in definition.upgrade_options:
		var upgrade := resource as WeaponUpgradeDefinition
		if upgrade != null:
			ids.append(upgrade.id)
	return ids


func _get_sorted_upgrade_ids(definition: WeaponDefinition) -> Array[String]:
	var ids := _get_upgrade_ids(definition)
	ids.sort()
	return ids


func _get_candidate_upgrade_ids(candidates: Array[RewardOffer], weapon_id: String) -> Array[String]:
	var ids: Array[String] = []
	for offer in candidates:
		if offer.category != RewardOffer.Category.WEAPON_UPGRADE or offer.weapon_id != weapon_id:
			continue
		ids.append(offer.weapon_upgrade.id)
	ids.sort()
	return ids


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
