## Tela de jogo: tabuleiro, HUD, efeitos, pausa e resultado.
## Toda a regra do jogo fica em board.gd / game_session.gd; aqui é só interface.
extends Control

const GameSession = preload("res://scripts/game_session.gd")
const LevelLoader = preload("res://scripts/level_loader.gd")
const BlockView = preload("res://scripts/block_view.gd")
const StarsView = preload("res://scripts/ui/stars_view.gd")
const Fx = preload("res://scripts/fx.gd")

const NEON_CYAN := Color("#3DE0FF")
const MOVES_COLOR := Color("#FFE53D")
const DANGER_COLOR := Color("#FF3B3B")
const HUD_HEIGHT := 230.0
const MARGIN := 16.0
const POP_TIME := 0.15
const FALL_TIME := 0.22
const HINT_DELAY := 6.0
## Tamanhos de grupo que disparam os efeitos de combinação.
const COMBO_GOOD := 6
const COMBO_GREAT := 9
const COMBO_AMAZING := 13
const TUTORIAL_TEXT := "Toque em 2 ou mais blocos iguais\nencostados para estourá-los!"
const BOMB_TIP_TEXT := "Você ganhou uma bomba! Toque nela\npara explodir os blocos em volta."

var _session  # game_session.gd
var _blocks := {}  # Vector2i -> BlockView
var _cell := 64.0
var _busy := false
## Incrementado a cada (re)início; animações antigas param ao perceber a mudança.
var _generation := 0

var _stage: Control  # tabuleiro + efeitos (é ele que treme)
var _board_root: Control
var _board_bg: Panel
var _fx_layer: Control
var _pause_button: Button
var _level_label: Label
var _goal_label: Label
var _goal_chip: Control
var _score_label: Label
var _moves_label: Label
var _tutorial_label: Label
var _tip_tween: Tween
var _hint_timer: Timer
var _pause_overlay: Control
var _result_overlay: Control
var _result_title: Label
var _result_stars: StarsView
var _result_score: Label
var _next_button: Button
var _gate_label: Label


func _ready() -> void:
	Audio.play_music("level")
	_build_ui()
	resized.connect(_layout)
	_start_level()


# --- Construção da interface -------------------------------------------------

func _build_ui() -> void:
	var hud := VBoxContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = MARGIN
	hud.offset_right = -MARGIN
	hud.offset_top = MARGIN * 2
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_constant_override("separation", 6)
	add_child(hud)
	_level_label = _make_label(hud, 44, NEON_CYAN)
	_level_label.custom_minimum_size.y = 88
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Fx.glow_label(_level_label, NEON_CYAN, 14)

	var goal_row := HBoxContainer.new()
	goal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	goal_row.add_theme_constant_override("separation", 12)
	hud.add_child(goal_row)
	_goal_label = _make_label(goal_row, 38, Color.WHITE)
	_goal_chip = BlockView.new()
	_goal_chip.custom_minimum_size = Vector2(52, 52)
	_goal_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	goal_row.add_child(_goal_chip)

	var row := HBoxContainer.new()
	hud.add_child(row)
	_score_label = _make_label(row, 36, Color.WHITE)
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_moves_label = _make_label(row, 36, MOVES_COLOR)
	_moves_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.position = Vector2(MARGIN, MARGIN * 2)
	_pause_button.size = Vector2(88, 88)
	_pause_button.pressed.connect(_pause)
	add_child(_pause_button)

	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_board_bg = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.15, 0.85)
	sb.border_color = Color(NEON_CYAN, 0.35)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(NEON_CYAN, 0.12)
	sb.shadow_size = 24
	sb.set_corner_radius_all(22)
	sb.anti_aliasing = true
	_board_bg.add_theme_stylebox_override("panel", sb)
	_board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_board_bg)

	_board_root = Control.new()
	_board_root.gui_input.connect(_on_board_input)
	_stage.add_child(_board_root)

	_fx_layer = Control.new()
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_fx_layer)

	# Balão de dica (tutorial e bomba), com fundo para ficar legível sobre o tabuleiro.
	_tutorial_label = _make_label(self, 30, Color.WHITE)
	_tutorial_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	_tutorial_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tutorial_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tutorial_label.offset_bottom = -24
	_tutorial_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.02, 0.03, 0.1, 0.92)
	tip_style.border_color = Color(NEON_CYAN, 0.8)
	tip_style.set_border_width_all(2)
	tip_style.set_corner_radius_all(20)
	tip_style.shadow_color = Color(NEON_CYAN, 0.3)
	tip_style.shadow_size = 12
	tip_style.content_margin_left = 22
	tip_style.content_margin_right = 22
	tip_style.content_margin_top = 12
	tip_style.content_margin_bottom = 12
	_tutorial_label.add_theme_stylebox_override("normal", tip_style)

	_hint_timer = Timer.new()
	_hint_timer.wait_time = HINT_DELAY
	_hint_timer.timeout.connect(_show_hint)
	add_child(_hint_timer)

	_build_pause_overlay()
	_build_result_overlay()


func _make_overlay() -> Array:
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.015, 0.06, 0.86)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS  # funciona com o jogo pausado
	overlay.visible = false
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	center.add_child(box)
	return [overlay, box]


func _build_pause_overlay() -> void:
	var parts := _make_overlay()
	_pause_overlay = parts[0]
	var box: VBoxContainer = parts[1]
	var title := _make_label(box, 68, NEON_CYAN)
	title.text = "Pausado"
	Fx.glow_label(title, NEON_CYAN, 18)
	_make_spacer(box, 16)
	_make_button(box, "Continuar", _resume).theme_type_variation = &"AccentButton"
	_make_button(box, "Reiniciar fase", _restart)
	_make_button(box, "Menu", GameState.go_to_menu)


func _build_result_overlay() -> void:
	var parts := _make_overlay()
	_result_overlay = parts[0]
	var box: VBoxContainer = parts[1]
	_result_title = _make_label(box, 72, Color.WHITE)
	_result_stars = StarsView.new()
	_result_stars.custom_minimum_size = Vector2(380, 120)
	box.add_child(_result_stars)
	_result_score = _make_label(box, 38, Color(1, 1, 1, 0.75))
	_gate_label = _make_label(box, 30, Color("#FFE53D"))
	_gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gate_label.custom_minimum_size.x = 520
	_make_spacer(box, 16)
	_next_button = _make_button(box, "Próxima fase", func(): GameState.play_level(GameState.current_index + 1))
	_next_button.theme_type_variation = &"AccentButton"
	_make_button(box, "Tentar de novo", _restart)
	_make_button(box, "Fases", GameState.go_to_level_select)


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
	b.custom_minimum_size = Vector2(440, 108)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


func _make_spacer(parent: Node, height: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)


# --- Ciclo da fase ------------------------------------------------------------

func _start_level() -> void:
	_generation += 1
	_busy = false
	get_tree().paused = false
	_session = LevelLoader.build_session(GameState.current_level())
	_rebuild_blocks()
	_pause_overlay.visible = false
	_result_overlay.visible = false
	_pause_button.disabled = false
	if GameState.current_index == 0:
		_show_tip(TUTORIAL_TEXT)
	else:
		_tutorial_label.visible = false
	_layout()
	_update_hud()
	_hint_timer.start()


## Recria os nós visuais a partir do estado atual do tabuleiro.
func _rebuild_blocks() -> void:
	# Remove blocos e efeitos, inclusive os que estavam no meio de uma animação.
	for child in _board_root.get_children() + _fx_layer.get_children():
		child.queue_free()
	_blocks.clear()
	_stage.position = Vector2.ZERO
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
	_layout()


func _restart() -> void:
	_start_level()


func _pause() -> void:
	if _result_overlay.visible:
		return
	get_tree().paused = true
	_pause_overlay.visible = true


func _resume() -> void:
	_pause_overlay.visible = false
	get_tree().paused = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:  # botão "voltar" do Android
			if _result_overlay.visible:
				GameState.go_to_level_select()
			elif _pause_overlay.visible:
				_resume()
			else:
				_pause()
		NOTIFICATION_APPLICATION_PAUSED:  # app foi para segundo plano
			if is_node_ready() and not _pause_overlay.visible:
				_pause()


# --- Layout e entrada ---------------------------------------------------------

func _layout() -> void:
	if _session == null:
		return
	var board = _session.board
	var avail := Vector2(size.x - MARGIN * 2, size.y - HUD_HEIGHT - MARGIN * 3)
	_cell = floorf(minf(avail.x / board.width, avail.y / board.height))
	var board_size := Vector2(board.width, board.height) * _cell
	_board_root.size = board_size
	_board_root.position = Vector2((size.x - board_size.x) / 2.0, HUD_HEIGHT + (avail.y - board_size.y) / 2.0 + MARGIN)
	_board_bg.position = _board_root.position - Vector2(10, 10)
	_board_bg.size = board_size + Vector2(20, 20)
	if not _busy:
		for p in _blocks:
			_place(_blocks[p], p)


func _place(block: Control, p: Vector2i) -> void:
	block.size = Vector2(_cell, _cell)
	block.pivot_offset = block.size / 2.0
	block.scale = Vector2.ONE
	block.position = _cell_pos(p)


func _cell_pos(p: Vector2i) -> Vector2:
	return Vector2(p) * _cell


## Centro de uma célula nas coordenadas do _fx_layer.
func _cell_center(p: Vector2i) -> Vector2:
	return _board_root.position + _cell_pos(p) + Vector2(_cell, _cell) / 2.0


func _on_board_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _busy or _session.status != GameSession.Status.PLAYING:
		return
	_hint_timer.start()  # reinicia a contagem da dica
	var cell := Vector2i((mb.position / _cell).floor())
	var result: Dictionary = _session.tap(cell.x, cell.y)
	if result.is_empty():
		_nudge(cell)
		return
	if _tutorial_label.text == TUTORIAL_TEXT:
		_hide_tip()
	_animate(result)


## Pequeno balanço quando o toque não forma grupo (feedback sem gastar jogada).
func _nudge(cell: Vector2i) -> void:
	var block: Control = _blocks.get(cell)
	if block == null:
		return
	Audio.play_sfx("thud")
	var t := create_tween()
	t.tween_property(block, "rotation", 0.15, 0.05)
	t.tween_property(block, "rotation", -0.15, 0.08)
	t.tween_property(block, "rotation", 0.0, 0.05)


func _animate(result: Dictionary) -> void:
	_busy = true
	var gen := _generation
	_update_hud()
	_play_effects(result)

	var removed: Array[Control] = []
	for p in result.removed:
		removed.append(_blocks[p])
		_blocks.erase(p)
	# Fase 1: todos incham juntos; fase 2: todos somem juntos.
	var pop := create_tween().set_parallel(true)
	for block in removed:
		pop.tween_property(block, "scale", Vector2.ONE * 1.25, POP_TIME * 0.4)
	pop.chain()
	for block in removed:
		pop.tween_property(block, "scale", Vector2.ZERO, POP_TIME * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await pop.finished
	if gen != _generation:
		return
	for block in removed:
		block.queue_free()

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
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		await fall.finished
		if gen != _generation:
			return

	_busy = false
	_layout()
	if _session.status != GameSession.Status.PLAYING:
		_finish()


# --- Efeitos ------------------------------------------------------------------

func _play_effects(result: Dictionary) -> void:
	var n: int = int(result.size)
	var is_explosion: bool = int(result.color) == BlockView.BOMB
	var col := BlockView.color_of(int(result.color))

	# Partículas na cor de cada bloco (numa explosão as cores são variadas).
	var center := Vector2.ZERO
	var count := 0
	for p in result.removed:
		var block = _blocks.get(p)
		var pos := _cell_center(p)
		center += pos
		count += 1
		_burst(pos, BlockView.color_of(block.color_index) if block else col, is_explosion or n >= COMBO_GREAT)
	if result.bomb != null:
		center += _cell_center(result.bomb)
		count += 1
	center /= maxi(count, 1)
	_float_text("+%d" % int(result.points), center, col, 40 + mini(n, 15) * 3)

	if is_explosion:
		Audio.play_sfx("boom")
		for b in result.exploded:
			_shockwave(_cell_center(b))
		_shake(18.0)
		GameState.vibrate(160)
		_combo_text("BUM!" if result.exploded.size() == 1 else "BUM x%d!" % result.exploded.size(), col)
		GameState.bomb_tip_seen = true
		if _tutorial_label.text == BOMB_TIP_TEXT:
			_hide_tip()
		return

	Audio.play_sfx("pop", 0.9 + minf(n, 15) * 0.04)
	if n >= COMBO_GREAT:
		Audio.play_sfx("boom")
		_shake(16.0 if n >= COMBO_AMAZING else 11.0)
		GameState.vibrate(140 if n >= COMBO_AMAZING else 90)
		_combo_text("Fantástico!" if n >= COMBO_AMAZING else "Incrível!", col)
	elif result.bomb != null:
		_shake(7.0)
		GameState.vibrate(60)
		_combo_text("Bomba!", BlockView.BOMB_COLOR)
	elif n >= COMBO_GOOD:
		Audio.play_sfx("combo")
		_shake(5.0)
		GameState.vibrate(35)
		_combo_text("Ótimo!", col)
	if result.bomb != null:
		_make_bomb(result.bomb)


## O bloco tocado se transforma em bomba (ele não está em "removed").
func _make_bomb(p: Vector2i) -> void:
	var block: Control = _blocks.get(p)
	if block == null:
		return
	block.color_index = BlockView.BOMB
	block.scale = Vector2.ONE * 0.4
	var t := create_tween()
	t.tween_property(block, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Audio.play_sfx("powerup")
	_burst(_cell_center(p), BlockView.BOMB_COLOR, false)
	if not GameState.bomb_tip_seen:
		_show_tip(BOMB_TIP_TEXT)


## Onda de choque: anel neon que se expande a partir da bomba.
func _shockwave(pos: Vector2) -> void:
	var ring := Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	var state := {"r": 0.0, "a": 1.0}
	ring.draw.connect(func():
		ring.draw_arc(pos, state.r, 0.0, TAU, 48, Color(BlockView.BOMB_COLOR, state.a), 3.0 + 9.0 * state.a, true))
	_fx_layer.add_child(ring)
	var t := create_tween()
	t.tween_method(func(v: float):
		state.r = v * _cell * 2.2
		state.a = 1.0 - v
		ring.queue_redraw(), 0.0, 1.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(ring.queue_free)


func _show_tip(text: String) -> void:
	if _tip_tween:
		_tip_tween.kill()
	_tutorial_label.text = text
	_tutorial_label.visible = true
	_tutorial_label.modulate.a = 1.0
	# Centraliza o balão na parte de baixo da tela, do tamanho do texto.
	var s := _tutorial_label.get_combined_minimum_size()
	_tutorial_label.offset_left = -s.x / 2.0
	_tutorial_label.offset_right = s.x / 2.0
	_tutorial_label.offset_bottom = -24.0
	_tutorial_label.offset_top = -24.0 - s.y


func _hide_tip() -> void:
	if not _tutorial_label.visible or _tutorial_label.modulate.a < 1.0:
		return
	_tip_tween = create_tween()
	_tip_tween.tween_property(_tutorial_label, "modulate:a", 0.0, 0.5)
	_tip_tween.tween_callback(func(): _tutorial_label.visible = false)


## Explosão de partículas brilhantes na cor do bloco.
func _burst(pos: Vector2, col: Color, big: bool) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 14 if big else 9
	p.lifetime = 0.75
	p.texture = Fx.dot_texture()
	p.material = Fx.additive_material()
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 420.0 if big else 300.0
	p.gravity = Vector2(0, 900)
	p.damping_min = 40.0
	p.damping_max = 80.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.9
	p.color = col.lightened(0.2)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	_fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0, false).timeout.connect(p.queue_free)


## Pontos que sobem e somem.
func _float_text(text: String, pos: Vector2, col: Color, font_size: int) -> void:
	var l := _make_label(_fx_layer, font_size, col.lightened(0.5))
	l.text = text
	Fx.glow_label(l, col, 14)
	l.reset_size()
	l.position = pos - l.size / 2.0
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 110.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	t.chain().tween_callback(l.queue_free)


## Texto grande de combinação no centro do tabuleiro.
func _combo_text(text: String, col: Color) -> void:
	var l := _make_label(_fx_layer, 92, col.lightened(0.55))
	l.text = text
	Fx.glow_label(l, col, 28)
	l.reset_size()
	l.position = _board_root.position + _board_root.size / 2.0 - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2.ONE * 0.3
	l.rotation = -0.08
	var t := create_tween()
	t.tween_property(l, "scale", Vector2.ONE * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector2.ONE, 0.12)
	t.tween_interval(0.45)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)


func _shake(strength: float) -> void:
	create_tween().tween_method(_apply_shake, strength, 0.0, 0.4)


func _apply_shake(strength: float) -> void:
	_stage.position = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))


## Se o jogador ficar parado, o maior grupo pisca para mostrar onde tocar.
func _show_hint() -> void:
	if _busy or _session.status != GameSession.Status.PLAYING:
		return
	var bombs: Array = _session.board.bombs()
	var targets: Array = [bombs[0]] if not bombs.is_empty() else _session.board.best_group()
	for p in targets:
		var block: Control = _blocks.get(p)
		if block == null:
			continue
		var t := create_tween()
		for i in 2:
			t.tween_property(block, "scale", Vector2.ONE * 1.15, 0.2).set_trans(Tween.TRANS_SINE)
			t.tween_property(block, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)


# --- HUD e resultado ----------------------------------------------------------

func _update_hud() -> void:
	_level_label.text = "Fase %d" % (GameState.current_index + 1)
	var is_color: bool = _session.goal_type() == "color"
	_goal_chip.visible = is_color
	if is_color:
		_goal_chip.color_index = int(_session.goal.get("color", 0))
		_goal_label.text = "Meta: %d / %d" % [mini(_session.goal_progress(), _session.goal_target()), _session.goal_target()]
	else:
		_goal_label.text = "Meta: %d pontos" % _session.goal_target()
	_score_label.text = "Pontos: %d" % _session.score
	_moves_label.text = "Jogadas: %d" % _session.moves_left
	var danger: bool = _session.moves_left <= 3
	_moves_label.add_theme_color_override("font_color", DANGER_COLOR if danger else MOVES_COLOR)
	Fx.glow_label(_moves_label, DANGER_COLOR if danger else MOVES_COLOR, 12 if danger else 6)


func _finish() -> void:
	_hint_timer.stop()
	var won: bool = _session.status == GameSession.Status.WON
	var stars: int = _session.stars()
	var title_color: Color = Color("#2BFF88") if won else Color("#FF4FD8")
	if won:
		GameState.complete_current_level(stars)
		_result_title.text = "Vitória!"
		Audio.play_sfx("win")
	else:
		_result_title.text = "Não foi dessa vez"
		Audio.play_sfx("lose")
	_result_title.add_theme_color_override("font_color", title_color.lightened(0.3))
	Fx.glow_label(_result_title, title_color, 22)
	_result_stars.count = 0
	_result_stars.visible = won
	_result_score.text = "Pontos: %d" % _session.score
	var next := GameState.current_index + 1
	var has_next: bool = won and GameState.has_next_level()
	_next_button.visible = has_next and GameState.is_unlocked(next)
	_update_gate_label(next, has_next)
	_pause_button.disabled = true
	_result_overlay.modulate.a = 0.0
	_result_overlay.visible = true
	var t := create_tween()
	t.tween_property(_result_overlay, "modulate:a", 1.0, 0.25)
	# Estrelas aparecem uma a uma, com som.
	for i in stars:
		t.tween_interval(0.3)
		t.tween_callback(func():
			_result_stars.count = i + 1
			Audio.play_sfx("star", 1.0 + i * 0.12))


## Se a próxima fase é um portão de estrelas, avisa se foi liberada ou quantas faltam.
func _update_gate_label(next: int, has_next: bool) -> void:
	var required: int = GameState.stars_required(next) if has_next else 0
	_gate_label.visible = required > 0
	if required == 0:
		return
	var missing: int = GameState.missing_stars(next)
	if missing == 0:
		_gate_label.text = "Fase %d liberada!" % (next + 1)
		_gate_label.add_theme_color_override("font_color", Color("#2BFF88"))
	else:
		_gate_label.text = "A fase %d exige %d estrelas. Faltam %d: jogue de novo as fases anteriores para conseguir mais estrelas." % [next + 1, required, missing]
		_gate_label.add_theme_color_override("font_color", Color("#FFE53D"))
