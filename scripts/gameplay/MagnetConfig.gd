extends Resource
class_name MagnetConfig

# Data balancing efek Magnet. Radius <= 0 berarti global untuk prototype.
@export var duration := 5.0
@export var radius := 0.0
@export var pull_speed := 420.0

# Jumlah pickup yang diaktifkan per frame saat Magnet dipakai agar tidak spike.
@export var activation_batch_size := 32
