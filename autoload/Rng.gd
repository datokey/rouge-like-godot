extends Node

var generator := RandomNumberGenerator.new()


func _ready() -> void:
	generator.randomize()


func set_seed(seed_value: int) -> void:
	generator.seed = seed_value


func random_seed() -> int:
	generator.randomize()
	return generator.randi()


func range_i(min_value: int, max_value: int) -> int:
	return generator.randi_range(min_value, max_value)


func chance(probability: float) -> bool:
	return generator.randf() <= probability
