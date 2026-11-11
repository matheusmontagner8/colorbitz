## Cena de jogo (Semana 1): mostra o tabuleiro, recebe toques e anima.
## Toda a regra do jogo fica em board.gd / game_session.gd; aqui é só interface.
extends Control

const GameSession = preload("res://scripts/game_session.gd")
const LevelLoader = preload("res://scripts/level_loader.gd")
const BlockView = preload("res://scripts/block_view.gd")

const BG_COLOR := Color("#1e2233")
const BOARD_BG := Color("#2a2f45")
const HUD_HEIGHT := 200.0
const MARGIN := 16.0
const POP_TIME := 0.15
const FALL_TIME := 0.22

var _levels: Array = []
var _level_index := 0
var _session  # game_session.gd
var _blocks := {}  # Vector2i -> BlockView
var _cell := 64.0
var _busy := false
## Incrementado a cada (re)início; animações antigas param ao perceber a mudança.
var _generation := 0

var _board_root: Control
var _board_bg: Panel
var _level_label: Label
var _goal_label: Label
var _score_label: Label
var _moves_label: Label
var _overlay: Control
var _result_label: Label
var _next_button: Button


func _ready() -> void:
	_levels = LevelLoader.load_levels()
	_build_ui()
	resized.connect(_layout)
	_start_level(0)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var hud := VBoxContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = MARGIN
	hud.offset_right = -MARGIN
	hud.offset_top = MARGIN * 2
	hud.add_theme_constant_override("separation", 4)
	add_child(hud)
	_level_label = _make_label(hud, 30, Color("#9aa3c7"))
	_goal_label = _make_label(hud, 38, Color.WHITE)
	var row := HBoxContainer.new()
	hud.add_child(row)
	_score_label = _make_label(row, 34, Color.WHITE)
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_moves_label = _make_label(row, 34, Color("#F0E442"))
	_moves_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_board_bg = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BOARD_BG
	sb.set_corner_radius_all(18)
	_board_bg.add_theme_stylebox_override("panel", sb)
	_board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_bg)

	_board_root = Control.new()
	_board_root.clip_contents = false
	_board_root.gui_input.connect(_on_board_input)
	add_child(_board_root)

	_build_overlay()


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)
	_result_label = _make_label(box, 52, Color.WHITE)
	_next_button = _make_button(box, "Próxima fase", func(): _start_level(_level_index + 1))
	_make_button(box, "Jogar de novo", func(): _start_level(_level_index))


func _make_label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _make_button(parent: Node, text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 96)
	b.add_theme_font_size_override("font_size", 36)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


func _start_level(index: int) -> void:
	_generation += 1
	_busy = false
	_level_index = clampi(index, 0, _levels.size() - 1)
	for b in _blocks.values():
		b.queue_free()
	_blocks.clear()
	_session = LevelLoader.build_session(_levels[_level_index])
	var board = _session.board
	for y in board.height:
		for x in board.width:
			var c: int = board.get_cell(x, y)
			if c < 0:  # vazio
				continue
			var block := BlockView.new()
			block.color_index = c
			_board_root.add_child(block)
			_blocks[Vector2i(x, y)] = block
	_overlay.visible = false
	_layout()
	_update_hud()


func _layout() -> void:
	if _session == null:
		return
	var board = _session.board
	var avail := Vector2(size.x - MARGIN * 2, size.y - HUD_HEIGHT - MARGIN * 3)
	_cell = floorf(minf(avail.x / board.width, avail.y / board.height))
	var board_size := Vector2(board.width, board.height) * _cell
	_board_root.size = board_size
	_board_root.position = Vector2((size.x - board_size.x) / 2.0, HUD_HEIGHT + (avail.y - board_size.y) / 2.0 + MARGIN)
	_board_bg.position = _board_root.position - Vector2(8, 8)
	_board_bg.size = board_size + Vector2(16, 16)
	if not _busy:
		for p in _blocks:
			_place(_blocks[p], p)


func _place(block: Control, p: Vector2i) -> void:
	block.size = Vector2(_cell, _cell)
	block.pivot_offset = block.size / 2.0
	block.position = _cell_pos(p)


func _cell_pos(p: Vector2i) -> Vector2:
	return Vector2(p) * _cell


func _on_board_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _busy or _session.status != GameSession.Status.PLAYING:
		return
	var cell := Vector2i((mb.position / _cell).floor())
	var result: Dictionary = _session.tap(cell.x, cell.y)
	if result.is_empty():
		_nudge(cell)
		return
	_animate(result)


## Pequeno balanço quando o toque não forma grupo (feedback sem gastar jogada).
func _nudge(cell: Vector2i) -> void:
	var block: Control = _blocks.get(cell)
	if block == null:
		return
	var t := create_tween()
	t.tween_property(block, "rotation", 0.15, 0.05)
	t.tween_property(block, "rotation", -0.15, 0.08)
	t.tween_property(block, "rotation", 0.0, 0.05)


func _animate(result: Dictionary) -> void:
	_busy = true
	var gen := _generation
	_update_hud()

	var removed: Array[Control] = []
	var pop := create_tween().set_parallel(true)
	for p in result.removed:
		var block: Control = _blocks[p]
		_blocks.erase(p)
		removed.append(block)
		pop.tween_property(block, "scale", Vector2.ZERO, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await pop.finished
	for block in removed:
		block.queue_free()
	if gen != _generation:
		return

	if not result.moves.is_empty():
		var moved := {}
		for m in result.moves:
			moved[m.to] = _blocks[m.from]
		for m in result.moves:
			if not moved.has(m.from):
				_blocks.erase(m.from)
		for to in moved:
			_blocks[to] = moved[to]
		var fall := create_tween().set_parallel(true)
		for to in moved:
			fall.tween_property(moved[to], "position", _cell_pos(to), FALL_TIME) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await fall.finished
		if gen != _generation:
			return

	_busy = false
	_layout()
	if _session.status != GameSession.Status.PLAYING:
		_show_result()


func _update_hud() -> void:
	_level_label.text = "Fase %d" % (_level_index + 1)
	if _session.goal_type() == "color":
		var color_name: String = BlockView.COLOR_NAMES[int(_session.goal.get("color", 0)) % BlockView.COLOR_NAMES.size()]
		_goal_label.text = "Meta: %d / %d blocos %s" % [mini(_session.goal_progress(), _session.goal_target()), _session.goal_target(), color_name]
	else:
		_goal_label.text = "Meta: %d pontos" % _session.goal_target()
	_score_label.text = "Pontos: %d" % _session.score
	_moves_label.text = "Jogadas: %d" % _session.moves_left


func _show_result() -> void:
	var won: bool = _session.status == GameSession.Status.WON
	if won:
		var s: int = _session.stars()
		_result_label.text = "Vitória!\nEstrelas: %d de 3" % s
	else:
		_result_label.text = "Fim de jogo"
	_next_button.visible = won and _level_index + 1 < _levels.size()
	_overlay.visible = true
