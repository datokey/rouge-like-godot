extends Node

# EventBus adalah pusat signal global agar gameplay dan UI tidak saling mencari node.
signal run_started(seed: int)
signal run_time_changed(elapsed_time: float, target_time: float)
signal run_won(elapsed_time: float, target_time: float, next_scene_path: String)
signal run_lost(elapsed_time: float, target_time: float)
signal floor_changed(floor: int)
signal player_health_changed(current_hp: int, max_hp: int)
signal player_xp_changed(current_xp: int, required_xp: int, level: int)
signal player_level_up(level: int, remaining_xp: int, next_required_xp: int)
signal reward_selected(offer: RewardOffer)
signal player_build_changed
signal weapon_ammo_changed(weapon_id: String, current_ammo: int, magazine_capacity: int)
signal weapon_reload_changed(weapon_id: String, is_reloading: bool, remaining_time: float, duration: float)
signal player_died
signal enemy_damaged(amount: int, is_critical: bool, world_position: Vector2, source_type: StringName)
