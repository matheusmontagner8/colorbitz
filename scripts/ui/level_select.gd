## Seleção de fases: grade com estrelas conquistadas, fases bloqueadas e
## fases-portão (10, 20, 30...), que exigem um mínimo de estrelas.
extends Control

const StarsView = preload("res://scripts/ui/stars_view.gd")
const WordTiles = preload("res://scripts/ui/word_tiles.gd")
const DragScroll = preload("res://scripts/ui/drag_scroll.gd")
const BadgeIcon = preload("res://scripts/ui/badge_icon.gd")
const ChestBar = preload("res://scripts/ui/chest_bar.gd")
const Endless = preload("res://scripts/endless.gd")

const BUTTON_SIZE := Vector2(132, 144)
const LOCK_COLOR := Color(0.3, 0.36, 0.55, 1)
const GATE_COLOR := Color("#FFE53D")
const GATE_MISSING_COLOR := Color(1.0, 0.9, 0.24, 0.55)
## Brilho dos botões da grade mais leve que o do tema (60 botões rolando).
const GRID_SHADOW_SIZE := 6

## Rolagem por arrasto da grade (um arrasto não abre fase).
var drag: DragScroll


func _ready() -> void:
	Audio.play_music("menu")
	%BackButton.pressed.connect(GameState.go_to_menu)
	drag = DragScroll.new(%Scroll)
	add_child(drag)
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
		_lighten(button)
		if unlocked:
			button.text = str(i + 1)
			button.pressed.connect(_open_level.bind(i))
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
	%StarsLabel.text = tr("Estrelas: %d de %d") % [progress.stars_before(levels.size(), levels), levels.size() * 3]
	_add_endless_button()
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


func _open_level(index: int) -> void:
	if not drag.dragged:  # soltar o dedo depois de rolar não abre a fase
		GameState.play_level(index)


## Troca o brilho dos estados do botão por uma versão menor (mais leve para
## rolar no celular), mantendo cores e bordas do tema.
func _lighten(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := button.get_theme_stylebox(state) as StyleBoxFlat
		if sb:
			var light := sb.duplicate() as StyleBoxFlat
			light.shadow_size = mini(light.shadow_size, GRID_SHADOW_SIZE)
			button.add_theme_stylebox_override(state, light)


## Fixo embaixo da grade: a palavra "MODO INFINITO" (uma letra a cada 5
## fases) e, com ela completa, o botão que continua o modo infinito, a
## patente, o próximo chefe e o baú de estrelas.
func _add_endless_button() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var word := WordTiles.new(50.0)
	word.setup(tr("MODO INFINITO"), GameState.letters_revealed())
	box.add_child(word)
	if GameState.endless_unlocked():
		var next: int = GameState.endless_next_index()
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 104)
		button.add_theme_font_size_override("font_size", 34)
		button.text = tr("Modo infinito: fase %d") % (next + 1)
		button.theme_type_variation = &"AccentButton"
		button.pressed.connect(GameState.play_level.bind(next))
		box.add_child(button)
		box.add_child(_endless_status(next + 1))
		var chest := ChestBar.new(260.0)
		chest.set_stars(GameState.chest_stars())
		box.add_child(chest)
	else:
		var hint := Label.new()
		hint.text = "Cada fase múltipla de 5 revela uma letra"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 24)
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		box.add_child(hint)
	%Scroll.add_sibling(box)


## Linha "medalha + patente | coroa + próximo chefe" do modo infinito.
func _endless_status(next_level: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var rank: int = GameState.rank_index()
	var rank_color := Color(Endless.RANKS[rank].color) if rank >= 0 else Color(1, 1, 1, 0.45)
	row.add_child(BadgeIcon.new("medal", rank_color, 48.0))
	var rank_label := _small_label(row, rank_color)
	rank_label.text = tr("Patente %s") % tr(Endless.RANKS[rank].name) if rank >= 0 else tr("Sem patente")
	var gap := Control.new()
	gap.custom_minimum_size.x = 24
	row.add_child(gap)
	row.add_child(BadgeIcon.new("crown", BadgeIcon.GOLD, 48.0))
	_small_label(row, BadgeIcon.GOLD).text = tr("Chefe: fase %d") % Endless.next_boss(next_level)
	return row


func _small_label(parent: Node, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


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
