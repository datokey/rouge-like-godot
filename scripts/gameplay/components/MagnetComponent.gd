extends Node
class_name MagnetComponent

@export var config: MagnetConfig
@export var owner_path: NodePath = ^".."

var magnet_remaining := 0.0
var activation_queue: Array[WeakRef] = []
var owner_node: Node2D


func _ready() -> void:
	owner_node = get_node_or_null(owner_path) as Node2D


func _physics_process(delta: float) -> void:
	if magnet_remaining <= 0.0:
		return

	magnet_remaining = maxf(magnet_remaining - delta, 0.0)
	_process_activation_queue()

	if magnet_remaining <= 0.0:
		activation_queue.clear()


func activate() -> void:
	if config == null or owner_node == null:
		return

	magnet_remaining = maxf(magnet_remaining, config.duration)
	_refresh_activation_queue()
	_process_activation_queue()


func _refresh_activation_queue() -> void:
	activation_queue.clear()
	if owner_node == null or config == null:
		return

	for pickup_node in get_tree().get_nodes_in_group("pickup_item"):
		var pickup := pickup_node as Node2D
		if pickup == null:
			continue
		if not pickup.has_method("can_be_magnetized") or not pickup.call("can_be_magnetized"):
			continue
		if config.radius > 0.0 and owner_node.global_position.distance_to(pickup.global_position) > config.radius:
			continue

		activation_queue.append(weakref(pickup))


func _process_activation_queue() -> void:
	if config == null or owner_node == null or magnet_remaining <= 0.0:
		return

	var batch_size := maxi(1, config.activation_batch_size)
	var processed_count := 0

	while processed_count < batch_size and not activation_queue.is_empty():
		var pickup_ref: WeakRef = activation_queue.pop_back()
		processed_count += 1

		if pickup_ref == null:
			continue

		var pickup := pickup_ref.get_ref() as Node
		if pickup == null or not is_instance_valid(pickup):
			continue
		if not pickup.has_method("activate_magnet_pull"):
			continue

		pickup.call(
			"activate_magnet_pull",
			owner_node,
			magnet_remaining,
			config.pull_speed,
			config.radius
		)
