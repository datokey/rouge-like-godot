extends Resource
class_name RunConfig

# Target prototype: player menang jika bertahan hidup selama 5 menit.
@export var survival_duration := 300.0

# Disiapkan untuk pindah scene/floor berikutnya setelah menang. Prototype saat ini belum memakainya.
@export_file("*.tscn") var next_scene_path := ""
