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
signal player_died
