extends Node2D


func _enter_tree() -> void:
	# Setiap Main scene dibuka/reload, run baru dimulai dan timer survival reset.
	RunManager.start_run()
