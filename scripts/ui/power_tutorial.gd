## Tutorial guiado dos poderes (Martelo e Troca). Aparece uma vez, na primeira
## fase a partir da 2: escurece a tela, destaca o botão ou o bloco que o jogador
## deve tocar e explica cada passo. Os usos durante o tutorial são grátis.
## A tela de jogo (game_view.gd) consulta allows_power()/allows_cell() antes de
## aceitar um toque e avisa os eventos com on_*().
extends Control

signal finished

enum Step { HAMMER_BUTTON, HAMMER_CELL, AFTER_HAMMER, SWAP_BUTTON, SWAP_FIRST, SWAP_SECOND, AFTER_SWAP, DONE }

const DIM := Color(0.0, 0.0, 0.03, 0.72)
const RING := Color("#FFE53D")
## Borda do outro bloco do par da Troca (não é o que deve ser tocado agora).
const RING_PAIR := Color("#3DE0FF")
const DONE_TIME := 3.2
const TEXTS := {
	Step.HAMMER_BUTTON: "Este é o Martelo! Ele destrói\nqualquer bloco sem gastar jogada.\nToque nele.",
	Step.HAMMER_CELL: "Este bloco está sozinho e não\nestoura com um toque normal.\nUse o Martelo nele!",
	Step.SWAP_BUTTON: "Agora a Troca: ela muda dois blocos\nde lugar, também sem gastar jogada.\nToque nela.",
	Step.SWAP_FIRST: "Estes dois vão trocar de lugar.\nToque no de borda amarela...",
	Step.SWAP_SECOND: "...e agora neste. Eles trocam\nde lugar e formam um grupo!",
}

var step: Step = Step.HAMMER_BUTTON
var hammer_cell := Vector2i(-1, -1)
var swap_cells: Array = []  # [a, b]

var _view  # game_view.gd
var _label: Label
var _pulse := 0.0
var _pulse_tween: Tween


func _init(view) -> void:
	_view = view
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 32)
	_label.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.13, 0.96)
	style.border_color = RING
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(RING, 0.3)
	style.shadow_size = 14
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_label.add_theme_stylebox_override("normal", style)
	add_child(_label)


func _ready() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "_pulse", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(self, "_pulse", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	hammer_cell = hammer_target(_view._session.board)
	_go(Step.HAMMER_BUTTON)


func _process(_delta: float) -> void:
	queue_redraw()
	_place_label()


# --- Regras: o que o jogador pode tocar em cada passo --------------------------

func is_active() -> bool:
	return step != Step.DONE


## Durante o tutorial os poderes não são descontados do saldo.
func is_free() -> bool:
	return step != Step.DONE


func allows_power(power: String) -> bool:
	return (step == Step.HAMMER_BUTTON and power == "hammer") or (step == Step.SWAP_BUTTON and power == "swap")


func allows_cell(cell: Vector2i) -> bool:
	match step:
		Step.HAMMER_CELL:
			return cell == hammer_cell
		Step.SWAP_FIRST:
			return cell == swap_cells[0]
		Step.SWAP_SECOND:
			return cell == swap_cells[1]
	return false


# --- Eventos vindos da tela de jogo --------------------------------------------

func on_power_selected(power: String) -> void:
	if step == Step.HAMMER_BUTTON and power == "hammer":
		_go(Step.HAMMER_CELL)
	elif step == Step.SWAP_BUTTON and power == "swap":
		_go(Step.SWAP_FIRST)


func on_hammer_used() -> void:
	if step == Step.HAMMER_CELL:
		_go(Step.AFTER_HAMMER)


func on_swap_first() -> void:
	if step == Step.SWAP_FIRST:
		_go(Step.SWAP_SECOND)


func on_swap_done() -> void:
	if step == Step.SWAP_SECOND:
		_go(Step.AFTER_SWAP)


## Fim da animação de uma jogada: o tabuleiro já está estável.
func on_move_finished() -> void:
	if step == Step.AFTER_HAMMER:
		swap_cells = swap_targets(_view._session.board)
		if swap_cells.is_empty():
			_finish()  # sem troca que forme grupo (raro): encerra por aqui
		else:
			_go(Step.SWAP_BUTTON)
	elif step == Step.AFTER_SWAP:
		_finish()


func _go(s: Step) -> void:
	step = s
	_label.visible = TEXTS.has(s)
	if _label.visible:
		_label.text = TEXTS[s]
		_label.reset_size()
	queue_redraw()


func _finish() -> void:
	step = Step.DONE
	var gs = _view.get_node("/root/GameState")
	_label.text = "Pronto! Você tem %d Martelos e %d Trocas.\nGanhe mais com estrelas e conquistas." % [
		gs.power_count("hammer"), gs.power_count("swap")]
	_label.visible = true
	_label.reset_size()
	finished.emit()
	var t := create_tween()
	t.tween_interval(DONE_TIME)
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)


# --- Escolha dos alvos (estático: testável sem interface) ----------------------

## Bloco para o Martelo: de preferência um bloco sozinho (que não estoura com
## toque), o mais baixo possível. Vector2i(-1, -1) se não houver bloco colorido.
static func hammer_target(board) -> Vector2i:
	var fallback := Vector2i(-1, -1)
	for y in range(board.height - 1, -1, -1):
		for x in board.width:
			if not board.is_color(board.get_cell(x, y)) or board.is_frozen(x, y):
				continue
			if board.find_group(x, y).size() < 2:
				return Vector2i(x, y)
			if fallback.x < 0:
				fallback = Vector2i(x, y)
	return fallback


## Dois blocos que, trocados, formam o maior grupo novo. [] se nenhuma troca ajuda.
static func swap_targets(board) -> Array:
	var cells: Array = []
	for y in board.height:
		for x in board.width:
			if board.is_color(board.get_cell(x, y)) and not board.is_frozen(x, y):
				cells.append(Vector2i(x, y))
	var best: Array = []
	var best_gain := 0
	for i in cells.size():
		for j in range(i + 1, cells.size()):
			var a: Vector2i = cells[i]
			var b: Vector2i = cells[j]
			if board.get_cell(a.x, a.y) == board.get_cell(b.x, b.y):
				continue
			var before := _group_size(board, a) + _group_size(board, b)
			board.swap(a, b)
			var gain := _group_size(board, a) + _group_size(board, b) - before
			board.swap(a, b)
			if gain > best_gain:
				best_gain = gain
				best = [a, b]
	return best


static func _group_size(board, p: Vector2i) -> int:
	var n: int = board.find_group(p.x, p.y).size()
	return n if n >= 2 else 0


# --- Desenho ---------------------------------------------------------------------

## Retângulo destacado no passo atual (coordenadas deste nó).
func _target_rect() -> Rect2:
	match step:
		Step.HAMMER_BUTTON:
			return _local(_view._power_bar.buttons["hammer"].get_global_rect())
		Step.SWAP_BUTTON:
			return _local(_view._power_bar.buttons["swap"].get_global_rect())
		Step.HAMMER_CELL:
			return _cell_rect(hammer_cell)
		Step.SWAP_FIRST:
			return _cell_rect(swap_cells[0])
		Step.SWAP_SECOND:
			return _cell_rect(swap_cells[1])
	return Rect2()


func _local(r: Rect2) -> Rect2:
	return Rect2(r.position - get_global_rect().position, r.size)


func _cell_rect(cell: Vector2i) -> Rect2:
	var c: float = _view._cell
	return _local(Rect2(_view._board_root.global_position + Vector2(cell) * c, Vector2(c, c)))


## O outro bloco do par da Troca, mostrado junto (Rect2() se não houver).
func _pair_rect() -> Rect2:
	match step:
		Step.SWAP_FIRST:
			return _cell_rect(swap_cells[1])
		Step.SWAP_SECOND:
			return _cell_rect(swap_cells[0])
	return Rect2()


func _draw() -> void:
	var r := _target_rect()
	if r.size == Vector2.ZERO:
		return
	var holes: Array = [r.grow(10.0)]
	var pair := _pair_rect()
	if pair.size != Vector2.ZERO:
		holes.append(pair.grow(10.0))
	_draw_dim(holes)
	if pair.size != Vector2.ZERO:
		_draw_ring(pair.grow(10.0), RING_PAIR, 0.3)
	_draw_ring(r.grow(10.0 + 4.0 * _pulse), RING, 0.35 + 0.35 * _pulse)


## Escurece a tela inteira menos os retângulos [param holes], em faixas
## horizontais (cada faixa é cortada onde passa um buraco).
func _draw_dim(holes: Array) -> void:
	var ys := [0.0, size.y]
	for h in holes:
		ys.append(clampf(h.position.y, 0.0, size.y))
		ys.append(clampf(h.end.y, 0.0, size.y))
	ys.sort()
	for i in ys.size() - 1:
		var y0: float = ys[i]
		var y1: float = ys[i + 1]
		if y1 <= y0:
			continue
		var cuts := []
		for h in holes:
			if h.position.y <= y0 and h.end.y >= y1:
				cuts.append(h)
		cuts.sort_custom(func(a, b): return a.position.x < b.position.x)
		var x := 0.0
		for h in cuts:
			if h.position.x > x:
				draw_rect(Rect2(x, y0, h.position.x - x, y1 - y0), DIM)
			x = maxf(x, h.end.x)
		if x < size.x:
			draw_rect(Rect2(x, y0, size.x - x, y1 - y0), DIM)


func _draw_ring(r: Rect2, col: Color, glow: float) -> void:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(5)
	ring.set_corner_radius_all(20)
	ring.border_color = col
	ring.shadow_color = Color(col, glow)
	ring.shadow_size = int(10 + 12 * _pulse)
	ring.anti_aliasing = true
	draw_style_box(ring, r)


## Balão acima do destaque (ou abaixo, se o destaque estiver no alto da tela).
func _place_label() -> void:
	if not _label.visible:
		return
	var s := _label.get_combined_minimum_size()
	var r := _target_rect()
	var y: float
	if r.size == Vector2.ZERO:
		y = size.y * 0.4
	else:
		var pair := _pair_rect()
		if pair.size != Vector2.ZERO:
			r = r.merge(pair)  # o balão não cobre nenhum dos dois blocos
		if r.get_center().y > size.y * 0.45:
			y = r.position.y - s.y - 40.0
		else:
			y = r.end.y + 40.0
	_label.size = s
	_label.position = Vector2((size.x - s.x) / 2.0, clampf(y, 16.0, size.y - s.y - 16.0))
