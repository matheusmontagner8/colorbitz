## Seleção de fases: grade com estrelas conquistadas, fases bloqueadas e
## fases-portão (10, 20, 30...), que exigem um mínimo de estrelas.
extends Control

const StarsView = preload("res://scripts/ui/stars_view.gd")

const BUTTON_SIZE := Vector2(132, 144)
const LOCK_COLOR := Color(0.3, 0.36, 0.55, 1)
const GATE_COLOR := Color("#FFE53D")
const GATE_MISSING_COLOR := Color(1.0, 0.9, 0.24, 0.55)


func _ready() -> void:
	Audio.play_music("menu")
	%BackButton.pressed.connect(GameState.go_to_menu)
	var levels: Array = GameState.levels
	var progress = GameState.progress
	var last_unlocked: Button = null
	for i in levels.size():
		var unlocked: bool = GameState.is_unlocked(i)
		var required: int = GameState.stars_required(i)
		var button := Button.new()
		button.custom_minimum_size = BUTTON_SIZE
		button.disabled = not unlocked
		if required > 0:
			button.theme_type_variation = &"GateButton"
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
		elif required > 0:
			_add_lock_icon(button, -18.0, 0.7)
			_add_gate_badge(button, required, GameState.missing_stars(i) == 0)
		else:
			_add_lock_icon(button, 0.0, 1.0)
	%StarsLabel.text = tr("Estrelas: %d de %d") % [progress.total_stars(), levels.size() * 3]
	var powers := Label.new()
	powers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	powers.add_theme_font_size_override("font_size", 26)
	powers.add_theme_color_override("font_color", Color("#3DE0FF"))
	var next: int = progress.stars_to_next_power()
	powers.text = tr("Martelo: %d   Troca: %d\nMais 1 de cada em %d %s") % [
		progress.power_count("hammer"), progress.power_count("swap"), next, tr("estrela") if next == 1 else tr("estrelas")]
	%StarsLabel.add_sibling(powers)
	if last_unlocked:
		# Rola até a fase mais avançada liberada.
		await get_tree().process_frame
		%Scroll.ensure_control_visible(last_unlocked)


func _add_lock_icon(button: Button, offset_y: float, scale_factor: float) -> void:
	var lock := Control.new()
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock.draw.connect(func():
		var c := lock.size / 2.0 + Vector2(0, offset_y)
		var k := scale_factor
		lock.draw_arc(c + Vector2(0, -6) * k, 16 * k, PI, TAU, 16, LOCK_COLOR, 7 * k)
		lock.draw_rect(Rect2(c + Vector2(-26, -6) * k, Vector2(52, 40) * k), LOCK_COLOR))
	button.add_child(lock)


## Selo "★ 20" no rodapé do botão: estrelas exigidas para liberar o portão.
func _add_gate_badge(button: Button, required: int, enough: bool) -> void:
	var color := GATE_COLOR if enough else GATE_MISSING_COLOR
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -46
	row.offset_bottom = -10
	var star := Control.new()
	star.custom_minimum_size = Vector2(30, 30)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.draw.connect(func():
		star.draw_colored_polygon(StarsView.star_points(star.size / 2.0, 15.0), color))
	row.add_child(star)
	var label := Label.new()
	label.text = str(required)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	row.add_child(label)
	button.add_child(row)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.go_to_menu()
