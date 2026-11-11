## Seleção de fases: grade com estrelas conquistadas e fases bloqueadas.
extends Control

const StarsView = preload("res://scripts/ui/stars_view.gd")

const BUTTON_SIZE := Vector2(132, 144)
const LOCK_COLOR := Color(0.5, 0.54, 0.66, 1)


func _ready() -> void:
	%BackButton.pressed.connect(GameState.go_to_menu)
	var levels: Array = GameState.levels
	var progress = GameState.progress
	var last_unlocked: Button = null
	for i in levels.size():
		var unlocked: bool = progress.is_unlocked(i, levels)
		var button := Button.new()
		button.custom_minimum_size = BUTTON_SIZE
		button.disabled = not unlocked
		%Grid.add_child(button)
		if unlocked:
			button.text = str(i + 1)
			button.pressed.connect(GameState.play_level.bind(i))
			var stars := StarsView.new()
			stars.count = progress.stars_for(levels[i].get("id", i + 1))
			stars.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			stars.offset_top = -40
			stars.offset_bottom = -10
			button.add_child(stars)
			last_unlocked = button
		else:
			_add_lock_icon(button)
	%StarsLabel.text = "Estrelas: %d de %d" % [progress.total_stars(), levels.size() * 3]
	if last_unlocked:
		# Rola até a fase mais avançada liberada.
		await get_tree().process_frame
		%Scroll.ensure_control_visible(last_unlocked)


func _add_lock_icon(button: Button) -> void:
	var lock := Control.new()
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock.draw.connect(func():
		var c := lock.size / 2.0
		lock.draw_arc(c + Vector2(0, -6), 16, PI, TAU, 16, LOCK_COLOR, 7)
		lock.draw_rect(Rect2(c + Vector2(-26, -6), Vector2(52, 40)), LOCK_COLOR))
	button.add_child(lock)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.go_to_menu()
