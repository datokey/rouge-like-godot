extends Control

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var xp_label: Label = %XpLabel
@onready var run_bar: ProgressBar = %RunBar
@onready var run_label: Label = %RunLabel
@onready var weapon_list: VBoxContainer = %WeaponList
@onready var talisman_list: VBoxContainer = %TalismanList
@onready var utility_list: GridContainer = %UtilityList
@onready var stat_list: VBoxContainer = %StatList


func _ready() -> void:
	# HUD hanya mendengar event, tidak mencari node Player secara langsung.
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_xp_changed.connect(_on_player_xp_changed)
	EventBus.run_time_changed.connect(_on_run_time_changed)
	EventBus.player_build_changed.connect(_refresh_build_hud)
	_on_player_health_changed(GameState.player_hp, GameState.player_max_hp)
	_on_player_xp_changed(GameState.player_xp, GameState.player_required_xp, GameState.player_level)
	_on_run_time_changed(GameState.run_elapsed_time, GameState.run_target_time)
	call_deferred("_refresh_build_hud")


func _refresh_build_hud() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("get_build_hud_snapshot"):
		_populate_build_list(weapon_list, [], "No weapon")
		_populate_build_list(talisman_list, [], "No talisman")
		_populate_utility_list([])
		_populate_stat_list([])
		return

	var snapshot: Dictionary = player.call("get_build_hud_snapshot")
	_populate_build_list(weapon_list, snapshot.get("weapons", []), "No weapon")
	_populate_build_list(talisman_list, snapshot.get("talismans", []), "No talisman")
	_populate_utility_list(snapshot.get("utilities", []))
	_populate_stat_list(snapshot.get("stat_lines", []))


func _populate_build_list(container: VBoxContainer, entries: Array, empty_text: String) -> void:
	_clear_container(container)
	if entries.is_empty():
		container.add_child(_create_text_label(empty_text, Color(0.7, 0.72, 0.76)))
		return
	for entry in entries:
		container.add_child(_create_build_entry(entry))


func _populate_utility_list(entries: Array) -> void:
	_clear_container(utility_list)
	if entries.is_empty():
		utility_list.add_child(_create_text_label("No active utility", Color(0.7, 0.72, 0.76)))
		return
	for entry in entries:
		utility_list.add_child(_create_utility_entry(entry))


func _populate_stat_list(lines: Array) -> void:
	_clear_container(stat_list)
	for line in lines:
		stat_list.add_child(_create_text_label(str(line), Color.WHITE))


func _create_build_entry(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := entry.get("icon") as Texture2D
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(20.0, 20.0)
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon_rect)
	else:
		row.add_child(_create_text_label("◆", Color(0.82, 0.84, 0.9)))
	var level := int(entry.get("level", 1))
	row.add_child(_create_text_label("%s  Lv.%d" % [entry.get("name", "Unknown"), level], Color.WHITE))
	return row


func _create_utility_entry(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(158.0, 52.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var icon := entry.get("icon") as Texture2D
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(24.0, 24.0)
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon_rect)
	else:
		var fallback_icon := _create_text_label("◆", Color(0.32, 0.92, 0.76))
		fallback_icon.custom_minimum_size = Vector2(18.0, 0.0)
		fallback_icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		fallback_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(fallback_icon)

	var label := _create_text_label(
		"%s\nx%d" % [entry.get("name", "Unknown"), int(entry.get("count", 1))],
		Color.WHITE
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return card


func _create_text_label(text_value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = "HP %d / %d" % [current_hp, max_hp]


func _on_player_xp_changed(current_xp: int, required_xp: int, level: int) -> void:
	xp_bar.max_value = required_xp
	xp_bar.value = current_xp
	xp_label.text = "LV %d  XP %d / %d" % [level, current_xp, required_xp]


func _on_run_time_changed(elapsed_time: float, target_time: float) -> void:
	run_bar.max_value = target_time
	run_bar.value = elapsed_time
	run_label.text = "RUN %s / %s" % [
		_format_time(elapsed_time),
		_format_time(target_time),
	]


func _format_time(time_seconds: float) -> String:
	var total_seconds := maxi(0, floori(time_seconds))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
