extends Node

# EventBus adalah pusat signal global agar gameplay dan UI tidak saling mencari node.
signal run_started(seed: int)
signal floor_changed(floor: int)
signal player_health_changed(current_hp: int, max_hp: int)
signal player_xp_changed(current_xp: int, required_xp: int, level: int)
signal player_level_up(level: int, remaining_xp: int, next_required_xp: int)
signal ability_selected(ability: Resource, rarity: int)
signal player_died
