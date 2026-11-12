## HUD da fase: título, meta (texto, ícones e barra), pontos animados e
## jogadas (com aviso de última jogada). Lê o estado da GameSession.
extends VBoxContainer

const GameSession = preload("res://scripts/game_session.gd")
const BlockView = preload("res://scripts/block_view.gd")
const Fx = preload("res://scripts/fx.gd")

const NEON_CYAN := Color("#3DE0FF")
const MOVES_COLOR := Color("#FFE53D")
const DANGER_COLOR := Color("#FF3B3B")
const GOAL_DONE_COLOR := Color("#2BFF88")
const MARGIN := 16.0

## Com 1 jogada sobrando: posição global onde mostrar "Última jogada!".
signal last_move_warning(global_pos: Vector2)

var level_label: Label
## Meta com cores/joias: [{chip: BlockView, label: Label ou null, color: int}]
var goal_parts: Array = []
## Pontuação mostrada no placar (rola até a real).
var shown_score := 0.0

var _goal_row: HBoxContainer
var _goal_label: Label
var _goal_bar: ProgressBar
var _goal_fill: StyleBoxFlat
var _goal_tween: Tween
var _score_label: Label
var _moves_label: Label
var _score_tween: Tween
var _last_move_tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_left = MARGIN
	offset_right = -MARGIN
	offset_top = MARGIN * 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	level_label = Fx.make_label(self, 44, NEON_CYAN)
	level_label.custom_minimum_size.y = 88
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Fx.glow_label(level_label, NEON_CYAN, 14)

	_goal_row = HBoxContainer.new()
	_goal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_goal_row.add_theme_constant_override("separation", 10)
	_goal_row.custom_minimum_size.y = 52
	add_child(_goal_row)

	_goal_bar = ProgressBar.new()
	_goal_bar.show_percentage = false
	_goal_bar.custom_minimum_size = Vector2(440, 16)
	_goal_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.03, 0.05, 0.15, 0.9)
	bar_bg.border_color = Color(NEON_CYAN, 0.3)
	bar_bg.set_border_width_all(2)
	bar_bg.set_corner_radius_all(8)
	_goal_fill = StyleBoxFlat.new()
	_goal_fill.set_corner_radius_all(8)
	_goal_fill.shadow_size = 8
	_goal_bar.add_theme_stylebox_override("background", bar_bg)
	_goal_bar.add_theme_stylebox_override("fill", _goal_fill)
	add_child(_goal_bar)

	var row := HBoxContainer.new()
	add_child(row)
	_score_label = Fx.make_label(row, 36, Color.WHITE)
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_moves_label = Fx.make_label(row, 36, MOVES_COLOR)
	_moves_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## Nova fase: zera placar e barra e monta a linha da meta.
func reset(session) -> void:
	for t in [_score_tween, _goal_tween]:
		if t:
			t.kill()
	shown_score = 0.0
	_goal_bar.value = 0.0
	build_goal_row(session)


## Atualiza tudo a partir da sessão.
func refresh(session, title: String) -> void:
	level_label.text = title
	_update_goal_text(session)
	_update_goal_bar(session)
	_animate_score(session.score)
	set_moves(session.moves_left)
	_update_last_move_warning(session)
	var danger: bool = session.moves_left <= 3
	_moves_label.add_theme_color_override("font_color", DANGER_COLOR if danger else MOVES_COLOR)
	Fx.glow_label(_moves_label, DANGER_COLOR if danger else MOVES_COLOR, 12 if danger else 6)


func set_moves(moves: int) -> void:
	_moves_label.text = tr("Jogadas: %d") % moves


func set_shown_score(v: float) -> void:
	shown_score = v
	_score_label.text = tr("Pontos: %d") % roundi(v)


func stop_score_animation() -> void:
	if _score_tween:
		_score_tween.kill()


## Monta a linha da meta conforme o tipo: texto e, se for o caso, ícones
## das cores ou da joia.
func build_goal_row(session) -> void:
	for child in _goal_row.get_children():
		_goal_row.remove_child(child)
		child.queue_free()
	goal_parts.clear()
	_goal_label = Fx.make_label(_goal_row, 38, Color.WHITE)
	match session.goal_type():
		"color":
			_add_goal_part(int(session.goal.get("color", 0)), false)
		"drop":
			_add_goal_part(BlockView.GEM, false)
		"colors":
			var targets: Dictionary = session.color_targets()
			for c in targets:
				_add_goal_part(c, true)


func _add_goal_part(index: int, with_label: bool) -> void:
	var chip := BlockView.new()
	chip.color_index = index
	chip.custom_minimum_size = Vector2(52, 52)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_goal_row.add_child(chip)
	var label: Label = Fx.make_label(_goal_row, 38, Color.WHITE) if with_label else null
	goal_parts.append({"chip": chip, "label": label, "color": index})


func _update_goal_text(session) -> void:
	var progress := mini(session.goal_progress(), session.goal_target())
	match session.goal_type():
		"color", "drop":
			_goal_label.text = tr("Meta: %d / %d") % [progress, session.goal_target()]
		"colors":
			_goal_label.text = "Meta:"
			var targets: Dictionary = session.color_targets()
			for part in goal_parts:
				var need: int = targets[part.color]
				var done := mini(session.removed_of(part.color), need)
				part.label.text = "%d/%d" % [done, need]
				part.label.add_theme_color_override("font_color", GOAL_DONE_COLOR if done >= need else Color.WHITE)
		"clear":
			_goal_label.text = tr("Restam %d blocos (meta: %d)") % [session.board.count_blocks(), int(session.goal.get("max_left", 0))]
		_:
			_goal_label.text = tr("Meta: %d pontos") % session.goal_target()


## Barra de meta: enche suavemente; fica verde quando a meta é cumprida.
func _update_goal_bar(session) -> void:
	var target: float = maxf(session.goal_target(), 1)
	var frac: float = clampf(session.goal_progress() / target, 0.0, 1.0)
	var col: Color = NEON_CYAN
	if frac >= 1.0:
		col = GOAL_DONE_COLOR
	elif session.goal_type() == "color":
		col = BlockView.color_of(int(session.goal.get("color", 0)))
	elif session.goal_type() == "drop":
		col = BlockView.GEM_COLOR
	_goal_fill.bg_color = col
	_goal_fill.shadow_color = Color(col, 0.45)
	if _goal_tween:
		_goal_tween.kill()
	_goal_tween = create_tween()
	_goal_tween.tween_property(_goal_bar, "value", frac * 100.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## O placar "rola" do valor mostrado até a pontuação atual.
func _animate_score(score: int) -> void:
	stop_score_animation()
	if is_equal_approx(shown_score, score):
		set_shown_score(score)
		return
	_score_tween = create_tween()
	_score_tween.tween_method(set_shown_score, shown_score, float(score), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Com 1 jogada sobrando, o contador pulsa e aparece um aviso.
func _update_last_move_warning(session) -> void:
	var last: bool = session.moves_left == 1 and session.status == GameSession.Status.PLAYING
	if last and _last_move_tween == null:
		_moves_label.pivot_offset = Vector2(_moves_label.size.x, _moves_label.size.y / 2.0)
		_last_move_tween = create_tween().set_loops()
		_last_move_tween.tween_property(_moves_label, "scale", Vector2.ONE * 1.15, 0.35).set_trans(Tween.TRANS_SINE)
		_last_move_tween.tween_property(_moves_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
		last_move_warning.emit(_moves_label.global_position + Vector2(_moves_label.size.x - 130.0, _moves_label.size.y + 30.0))
	elif not last and _last_move_tween:
		_last_move_tween.kill()
		_last_move_tween = null
		_moves_label.scale = Vector2.ONE
