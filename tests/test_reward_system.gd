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
	_test_talisman_slot_and_compatibility_filtering()
	_test_modifier_scope()
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
		"utility_levels": {},
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
	for offer in POOL.get_valid_candidates(full_context):
		_assert(offer.category != RewardOffer.Category.WEAPON_NEW, "weapon baru muncul saat empat slot penuh")

	var maxed_context := beam_context.duplicate(true)
	var maxed_stacks := {}
	for resource in BEAM.upgrade_options:
		var upgrade := resource as WeaponUpgradeDefinition
		maxed_stacks[upgrade.id] = upgrade.max_stack
	maxed_context["weapon_upgrade_stacks"] = {"beam_gun": maxed_stacks}
	for offer in POOL.get_valid_candidates(maxed_context):
		_assert(offer.category != RewardOffer.Category.WEAPON_UPGRADE, "upgrade maksimal masih berada di pool")


func _test_talisman_slot_and_compatibility_filtering() -> void:
	var context := {
		"owned_weapon_ids": ["beam_gun"],
		"can_add_weapon": false,
		"owned_weapon_definitions": {"beam_gun": BEAM},
		"weapon_upgrade_stacks": {"beam_gun": {}},
		"owned_compatibility_tags": BEAM.compatibility_tags,
		"owned_talisman_levels": {},
		"can_add_talisman": true,
		"utility_levels": {},
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


func _test_controlled_rng_and_fallback() -> void:
	var context := {
		"owned_weapon_ids": ["beam_gun"],
		"can_add_weapon": true,
		"owned_weapon_definitions": {"beam_gun": BEAM},
		"weapon_upgrade_stacks": {"beam_gun": {}},
		"owned_compatibility_tags": BEAM.compatibility_tags,
		"owned_talisman_levels": {},
		"can_add_talisman": true,
		"utility_levels": {},
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

	var empty_context := {
		"owned_weapon_ids": [],
		"can_add_weapon": false,
		"owned_weapon_definitions": {},
		"weapon_upgrade_stacks": {},
		"owned_compatibility_tags": [],
		"owned_talisman_levels": {},
		"can_add_talisman": false,
		"utility_levels": {"pickup_radius": 5, "revive": 1},
		"luck": 0.0,
	}
	var fallback_offers := POOL.roll_offers(empty_context, 3)
	_assert(fallback_offers.size() == 3, "fallback tidak mengisi jumlah kartu")
	for offer in fallback_offers:
		_assert(offer.utility != null and offer.utility.id.begins_with("fallback_"), "reward non-fallback lolos saat pool kosong")


func _find_talisman(talisman_id: String) -> TalismanDefinition:
	for resource in POOL.talisman_definitions:
		var talisman := resource as TalismanDefinition
		if talisman != null and talisman.id == talisman_id:
			return talisman
	return null


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
