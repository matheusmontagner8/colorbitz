## Tela de jogo: coordena tabuleiro, entrada, animações, poderes e fim de fase.
## A regra do jogo fica em board.gd / game_session.gd; as partes visuais ficam
## em componentes de scripts/ui/ (HUD, barra de poderes, efeitos, balão de
## dica, pausa e resultado).
extends Control

const GameSession = preload("res://scripts/game_session.gd")
const LevelLoader = preload("res://scripts/level_loader.gd")
const BlockView = preload("res://scripts/block_view.gd")
const PowerButton = preload("res://scripts/ui/power_button.gd")
const PowerTutorial = preload("res://scripts/ui/power_tutorial.gd")
const GameHud = preload("res://scripts/ui/game_hud.gd")
const PowerBar = preload("res://scripts/ui/power_bar.gd")
const BoardFx = preload("res://scripts/ui/board_fx.gd")
const TipBalloon = preload("res://scripts/ui/tip_balloon.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const ResultPanel = preload("res://scripts/ui/result_panel.gd")
const Endless = preload("res://scripts/endless.gd")
const Intros = preload("res://scripts/intros.gd")
const IntroCard = preload("res://scripts/ui/intro_card.gd")
const Daily = preload("res://scripts/daily.gd")

const NEON_CYAN := Color("#3DE0FF")
const MOVES_COLOR := Color("#FFE53D")
## Fase chefe do modo infinito: borda dourada no tabuleiro e no título.
const BOSS_COLOR := Color("#FFD54A")
const DANGER_COLOR := Color("#FF3B3B")
const HUD_HEIGHT := 252.0
const POWER_BAR_HEIGHT := 150.0
const SWAP_TIME := 0.25
const MARGIN := 16.0
const POP_TIME := 0.15
const FALL_TIME := 0.22
const HINT_DELAY := 6.0
## Tamanhos de grupo que disparam os efeitos de combinação.
const COMBO_GOOD := 6
const COMBO_GREAT := 9
const COMBO_AMAZING := 13
const TUTORIAL_TEXT := "Toque em 2 ou mais blocos iguais\nencostados para estourá-los!"
const STUCK_TIP := "Sem jogadas! Use um poder\nou embaralhe o tabuleiro."
const POWER_TIPS := {
	"hammer": "Martelo: toque no bloco\nque quer destruir.",
	"swap": "Troca: toque em dois blocos\npara trocá-los de lugar.",
}

var _session  # game_session.gd
var _blocks := {}  # Vector2i -> BlockView
var _cell := 64.0
var _busy := false
## Incrementado a cada (re)início; animações antigas param ao perceber a mudança.
var _generation := 0
var _rng := RandomNumberGenerator.new()

# Componentes
var _hud: GameHud
var _power_bar: PowerBar
var _fx: BoardFx
var _tip: TipBalloon
var _pause_menu: PauseMenu
var _result: ResultPanel
var _pause_button: Button

# Tabuleiro
var _stage: Control  # tabuleiro + efeitos (é ele que treme)
var _board_root: Control
var _board_bg: Panel
var _board_style: StyleBoxFlat
var _holes_layer: Control
var _hint_timer: Timer

## Cartão de apresentação (primeira vez de cada meta/peça) e a fila deles.
var _intro: IntroCard
var _intro_queue: Array = []
## Poder escolhido esperando o toque no tabuleiro ("" = toque normal).
var _power := ""
var _swap_first = null  # Vector2i do primeiro bloco da troca, ou null
var _select_tween: Tween
## Tutorial dos poderes (só na primeira vez; null quando não está rodando).
var _tutorial: Control


func _ready() -> void:
	Audio.play_music("level")
	_build_ui()
	resized.connect(_layout)
	_start_level()


# --- Construção da interface -------------------------------------------------

func _build_ui() -> void:
	_hud = GameHud.new()
	_hud.last_move_warning.connect(func(pos: Vector2):
		_fx.float_text("Última jogada!", pos - _fx.global_position, DANGER_COLOR, 34))
	add_child(_hud)

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
	_board_style = sb
	_board_bg.add_theme_stylebox_override("panel", sb)
	_board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_board_bg)

	# Buracos dos tabuleiros com formato: "recortes" escuros sob os blocos.
	_holes_layer = Control.new()
	_holes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holes_layer.draw.connect(_draw_holes)
	_stage.add_child(_holes_layer)

	_board_root = Control.new()
	_board_root.gui_input.connect(_on_board_input)
	_stage.add_child(_board_root)

	_power_bar = PowerBar.new(POWER_BAR_HEIGHT, MARGIN)
	_power_bar.power_pressed.connect(_toggle_power)
	_power_bar.shuffle_pressed.connect(_on_shuffle_pressed)
	add_child(_power_bar)

	_fx = BoardFx.new()
	_fx.reduced = GameState.progress.reduce_effects
	_stage.add_child(_fx)

	_tip = TipBalloon.new()
	_tip.bottom_margin = POWER_BAR_HEIGHT + 8.0
	add_child(_tip)

	_intro = IntroCard.new()
	_intro.closed.connect(_on_intro_closed)
	add_child(_intro)

	_hint_timer = Timer.new()
	_hint_timer.wait_time = HINT_DELAY
	_hint_timer.timeout.connect(_show_hint)
	add_child(_hint_timer)

	_pause_menu = PauseMenu.new()
	_pause_menu.resume_pressed.connect(_resume)
	_pause_menu.restart_pressed.connect(_restart)
	_pause_menu.menu_pressed.connect(GameState.go_to_menu)
	add_child(_pause_menu)

	_result = ResultPanel.new()
	_result.next_pressed.connect(func(): GameState.play_level(GameState.current_index + 1))
	_result.retry_pressed.connect(_restart)
	_result.back_pressed.connect(_leave)
	add_child(_result)


## Sai da tela de resultado: fase diária volta ao menu; as outras, às fases.
func _leave() -> void:
	if GameState.daily_mode:
		GameState.go_to_menu()
	else:
		GameState.go_to_level_select()


# --- Ciclo da fase ------------------------------------------------------------

func _start_level() -> void:
	_generation += 1
	_busy = false
	get_tree().paused = false
	_session = LevelLoader.build_session(GameState.current_level())
	_power = ""
	_swap_first = null
	_rng.randomize()
	_hud.reset(_session)
	_set_boss_look(_is_boss())
	_power_bar.hide_shuffle()
	_rebuild_blocks()
	_pause_menu.visible = false
	_result.visible = false
	_pause_button.disabled = false
	if GameState.current_index == 0 and not GameState.daily_mode:
		_tip.show_tip(TUTORIAL_TEXT)
	else:
		_tip.clear()
	_layout()
	_update_hud()
	_hint_timer.start()
	if _tutorial:
		_tutorial.queue_free()
		_tutorial = null
	# Novidades desta fase (meta, peças, modo) que o jogador ainda não viu:
	# um cartão para cada; depois deles, o tutorial dos poderes (se for a vez).
	_intro.visible = false
	_intro_queue = Intros.unseen(Intros.concepts_for(GameState.current_level(), _session.board, GameState.daily_mode), GameState.progress)
	_show_next_intro()


# --- Cartões de apresentação -----------------------------------------------------

## Põe um cartão na fila (se ainda não foi visto) e mostra se nada estiver aberto.
func _queue_intro(id: String) -> void:
	if GameState.progress.tutorials.has(Intros.key(id)) or id in _intro_queue or (_intro.visible and _intro.id == id):
		return
	_intro_queue.append(id)
	if not _intro.visible:
		_show_next_intro()


func _show_next_intro() -> void:
	if _intro_queue.is_empty():
		_hint_timer.start()
		_maybe_start_tutorial()
		return
	_hint_timer.stop()
	var id: String = _intro_queue.pop_front()
	_intro.open(id, _goal_colors(), _session.board.bomb_group_size)


func _on_intro_closed(id: String) -> void:
	Intros.mark_seen(id, GameState.progress)
	GameState.save()
	_show_next_intro()


## Cores pedidas pela meta (para o desenho do cartão).
func _goal_colors() -> Array:
	match _session.goal_type():
		"color":
			return [int(_session.goal.get("color", 0))]
		"colors":
			return _session.color_targets().keys()
	return []


## Tutorial dos poderes: na primeira fase jogada a partir da 2 (fora a diária).
func _maybe_start_tutorial() -> void:
	if _tutorial or _session.status != GameSession.Status.PLAYING:
		return
	if GameState.daily_mode or GameState.current_index < 1 or GameState.progress.tutorials.has("powers"):
		return
	_tip.clear()
	_tutorial = PowerTutorial.new(self)
	add_child(_tutorial)
	move_child(_tutorial, _pause_menu.get_index())  # pausa e resultado ficam por cima
	_tutorial.finished.connect(_on_tutorial_finished)


func _on_tutorial_finished() -> void:
	GameState.progress.tutorials["powers"] = true
	GameState.save()
	_tutorial = null
	_update_hud()
	_hint_timer.start()


## Durante o tutorial os poderes são grátis.
func _tutorial_free() -> bool:
	return _tutorial != null and _tutorial.is_free()


## Recria os nós visuais a partir do estado atual do tabuleiro.
func _rebuild_blocks() -> void:
	# Remove blocos e efeitos, inclusive os que estavam no meio de uma animação.
	for child in _board_root.get_children():
		child.queue_free()
	_fx.clear()
	_blocks.clear()
	_stage.position = Vector2.ZERO
	var board = _session.board
	for y in board.height:
		for x in board.width:
			var c: int = board.get_cell(x, y)
			if c < 0:  # vazio ou buraco
				continue
			var block := BlockView.new()
			block.color_index = c
			block.ice = board.get_ice(x, y)
			_board_root.add_child(block)
			_blocks[Vector2i(x, y)] = block
	_layout()


func _restart() -> void:
	_start_level()


func _pause() -> void:
	if _result.visible:
		return
	get_tree().paused = true
	_pause_menu.visible = true


func _resume() -> void:
	_pause_menu.visible = false
	get_tree().paused = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:  # botão "voltar" do Android
			if _result.visible:
				_leave()
			elif _pause_menu.visible:
				_resume()
			else:
				_pause()
		NOTIFICATION_APPLICATION_PAUSED:  # app foi para segundo plano
			if is_node_ready() and not _pause_menu.visible:
				_pause()


# --- Layout e entrada ---------------------------------------------------------

func _layout() -> void:
	if _session == null:
		return
	var board = _session.board
	var avail := Vector2(size.x - MARGIN * 2, size.y - HUD_HEIGHT - POWER_BAR_HEIGHT - MARGIN * 2)
	_cell = floorf(minf(avail.x / board.width, avail.y / board.height))
	var board_size := Vector2(board.width, board.height) * _cell
	_board_root.size = board_size
	_board_root.position = Vector2((size.x - board_size.x) / 2.0, HUD_HEIGHT + (avail.y - board_size.y) / 2.0 + MARGIN)
	_holes_layer.position = _board_root.position
	_holes_layer.size = board_size
	_holes_layer.queue_redraw()
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


## Centro de uma célula nas coordenadas da camada de efeitos.
func _cell_center(p: Vector2i) -> Vector2:
	return _board_root.position + _cell_pos(p) + Vector2(_cell, _cell) / 2.0


func _board_center() -> Vector2:
	return _board_root.position + _board_root.size / 2.0


func _on_board_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _busy or _intro.visible or _session.status != GameSession.Status.PLAYING:
		return
	_hint_timer.start()  # reinicia a contagem da dica
	var cell := Vector2i((mb.position / _cell).floor())
	if _tutorial and not _tutorial.allows_cell(cell):
		_nudge(cell)
		return
	if _power == "hammer":
		_use_hammer(cell)
		return
	if _power == "swap":
		_pick_swap(cell)
		return
	var result: Dictionary = _session.tap(cell.x, cell.y)
	if result.is_empty():
		_nudge(cell)
		return
	if _tip.is_showing(TUTORIAL_TEXT):
		_tip.hide_tip()
	_animate(result)


## Fim de qualquer jogada (toque, bomba ou poder): encerra a fase ou trata o
## tabuleiro travado.
func _after_move() -> void:
	_busy = false
	if _tutorial:
		_tutorial.on_move_finished()
	# Estatísticas das conquistas: soma a cada jogada; no fim da fase, salva.
	GameState.record_stats(_session.take_stats(), _session.status != GameSession.Status.PLAYING)
	_power_bar.hide_shuffle()
	for p in _blocks:
		_blocks[p].ice = _session.board.get_ice(p.x, p.y)
	_layout()
	if _session.status != GameSession.Status.PLAYING:
		_finish()
	elif _session.is_stuck():
		_handle_stuck()


# --- Tabuleiro travado ---------------------------------------------------------

## Sem grupos: com poderes, o jogador escolhe usar um; sem poderes, embaralha de graça.
func _handle_stuck() -> void:
	if _power_bar.pulse_available():
		Audio.play_sfx("thud")
		_tip.show_tip(STUCK_TIP, true)
		_power_bar.show_shuffle()
	else:
		_shuffle_board()


## Botão "Embaralhar": alternativa grátis aos poderes quando o tabuleiro trava.
func _on_shuffle_pressed() -> void:
	if _busy or not _session.is_stuck():
		return
	_set_power("")
	_shuffle_board()


func _shuffle_board() -> void:
	_power_bar.hide_shuffle()
	if not _session.shuffle(_rng):
		_finish()  # nem embaralhando dá: fase perdida
		return
	if _tip.is_showing(STUCK_TIP):
		_tip.hide_tip()
	_busy = true
	var gen := _generation
	_fx.combo_text("Embaralhando!", NEON_CYAN, _board_center())
	Audio.play_sfx("powerup")
	var out := create_tween().set_parallel(true)
	for p in _blocks:
		out.tween_property(_blocks[p], "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await out.finished
	if gen != _generation:
		return
	for p in _blocks:
		_blocks[p].color_index = _session.board.get_cell(p.x, p.y)
	var back := create_tween().set_parallel(true)
	for p in _blocks:
		back.tween_property(_blocks[p], "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await back.finished
	if gen != _generation:
		return
	_busy = false
	_layout()


# --- Poderes especiais ------------------------------------------------------------

## Liga/desliga o modo do poder. O poder só é gasto quando o jogador o usa.
func _toggle_power(power: String) -> void:
	if _busy or _intro.visible or _session.status != GameSession.Status.PLAYING:
		return
	if _tutorial and not _tutorial.allows_power(power):
		return
	_set_power("" if _power == power else power)
	if _tutorial:
		_tutorial.on_power_selected(power)


func _set_power(power: String) -> void:
	_clear_swap_selection()
	_power = power
	_power_bar.set_active(power)
	if power != "" and _tutorial:
		pass  # o tutorial mostra as próprias explicações
	elif power != "":
		_tip.show_tip(POWER_TIPS[power], true)
	elif _session.is_stuck():
		_tip.show_tip(STUCK_TIP, true)
	elif _tip.visible and (_tip.text in POWER_TIPS.values() or _tip.text == STUCK_TIP):
		_tip.hide_tip()


func _use_hammer(cell: Vector2i) -> void:
	var result: Dictionary = _session.use_hammer(cell.x, cell.y)
	if result.is_empty():
		_nudge(cell)  # joia (ou célula vazia): o Martelo não quebra
		return
	if not _tutorial_free():
		GameState.use_power("hammer")
	_set_power("")
	if _tutorial:
		_tutorial.on_hammer_used()
	_animate(result)


func _pick_swap(cell: Vector2i) -> void:
	if not _blocks.has(cell):
		return
	if _session.board.get_cell(cell.x, cell.y) == _session.board.GEM:
		_nudge(cell)  # joias não trocam de lugar
		return
	if _swap_first == null:
		_swap_first = cell
		var block: Control = _blocks[cell]
		_select_tween = create_tween().set_loops()
		_select_tween.tween_property(block, "scale", Vector2.ONE * 1.15, 0.3).set_trans(Tween.TRANS_SINE)
		_select_tween.tween_property(block, "scale", Vector2.ONE * 0.95, 0.3).set_trans(Tween.TRANS_SINE)
		Audio.play_sfx("click")
		if _tutorial:
			_tutorial.on_swap_first()
		return
	var first: Vector2i = _swap_first
	if cell == first:
		_clear_swap_selection()
		return
	if not _session.use_swap(first, cell):
		return
	if not _tutorial_free():
		GameState.use_power("swap")
	_set_power("")
	if _tutorial:
		_tutorial.on_swap_done()
	_animate_swap(first, cell)


func _clear_swap_selection() -> void:
	if _select_tween:
		_select_tween.kill()
		_select_tween = null
	if _swap_first != null and _blocks.has(_swap_first):
		_blocks[_swap_first].scale = Vector2.ONE
	_swap_first = null


func _animate_swap(a: Vector2i, b: Vector2i) -> void:
	_busy = true
	var gen := _generation
	_update_hud()
	var block_a: Control = _blocks[a]
	var block_b: Control = _blocks[b]
	_blocks[a] = block_b
	_blocks[b] = block_a
	Audio.play_sfx("powerup")
	GameState.vibrate(30)
	var t := create_tween().set_parallel(true)
	for pair in [[block_a, b], [block_b, a]]:
		var block: Control = pair[0]
		block.z_index = 1
		t.tween_property(block, "position", _cell_pos(pair[1]), SWAP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(block, "scale", Vector2.ONE, SWAP_TIME)
	await t.finished
	if gen != _generation:
		return
	block_a.z_index = 0
	block_b.z_index = 0
	for p in [a, b]:
		_fx.burst(_cell_center(p), PowerButton.COLORS.swap, false)
	_after_move()


# --- Animação das jogadas --------------------------------------------------------

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

	# Joias coletadas: caem até o fundo junto com os outros e depois somem.
	var gems: Array = []  # [[bloco, posição de coleta]]
	for g in result.get("gems", []):
		gems.append([_blocks[g.from], g.to])
		_blocks.erase(g.from)
	if not result.moves.is_empty() or not gems.is_empty():
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
		for g in gems:
			fall.tween_property(g[0], "position", _cell_pos(g[1]), FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await fall.finished
		if gen != _generation:
			return
		for g in gems:
			_collect_gem(g[0], g[1])

	_after_move()


## Joia chegou ao fundo: brilha, sobe um pouco e some.
func _collect_gem(block: Control, p: Vector2i) -> void:
	var col := BlockView.GEM_COLOR
	_fx.burst(_cell_center(p), col, true)
	_fx.float_text("Joia!", _cell_center(p) + Vector2(0, -20), col, 40)
	Audio.play_sfx("star", 1.2)
	GameState.vibrate(40)
	var t := create_tween().set_parallel(true)
	t.tween_property(block, "scale", Vector2.ONE * 1.5, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(block, "position:y", block.position.y - _cell * 0.6, 0.3)
	t.tween_property(block, "modulate:a", 0.0, 0.3).set_delay(0.1)
	t.chain().tween_callback(block.queue_free)


func _draw_holes() -> void:
	if _session == null:
		return
	var board = _session.board
	for y in board.height:
		for x in board.width:
			if board.get_cell(x, y) != board.HOLE:
				continue
			var r := Rect2(Vector2(x, y) * _cell, Vector2(_cell, _cell))
			_holes_layer.draw_rect(r.grow(1.0), Color(0.008, 0.012, 0.035))
			_holes_layer.draw_rect(r.grow(-_cell * 0.12), Color(NEON_CYAN, 0.08), false, 2.0)


## Partículas, pontos, sons, tremor e vibração conforme o tipo de jogada.
func _play_effects(result: Dictionary) -> void:
	# Gelo rachado: o bloco ainda está na posição antiga (antes da gravidade).
	for p in result.get("iced", []):
		var frozen = _blocks.get(p)
		if frozen:
			frozen.ice = maxi(0, frozen.ice - 1)
		_fx.burst(_cell_center(p), BlockView.ICE_COLOR, false)
	if not result.get("iced", []).is_empty():
		Audio.play_sfx("thud", 1.5)
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
		_fx.burst(pos, BlockView.color_of(block.color_index) if block else col, is_explosion or n >= COMBO_GREAT)
	if result.bomb != null:
		center += _cell_center(result.bomb)
		count += 1
	center /= maxi(count, 1)
	_fx.float_text("+%d" % int(result.points), center, col, 40 + mini(n, 15) * 3)

	if is_explosion:
		Audio.play_sfx("boom")
		for b in result.exploded:
			_fx.shockwave(_cell_center(b), _cell * 2.2, BlockView.BOMB_COLOR)
		_shake(18.0)
		GameState.vibrate(160)
		_fx.combo_text("BUM!" if result.exploded.size() == 1 else tr("BUM x%d!") % result.exploded.size(), col, _board_center())
		return

	if result.get("power") == "hammer":
		Audio.play_sfx("thud")
		Audio.play_sfx("pop", 0.8)
		_fx.shockwave(center, _cell * 2.2, BlockView.BOMB_COLOR)
		_shake(8.0)
		GameState.vibrate(50)
		return
	Audio.play_sfx("pop", 0.9 + minf(n, 15) * 0.04)
	if n >= COMBO_GREAT:
		Audio.play_sfx("boom")
		_shake(16.0 if n >= COMBO_AMAZING else 11.0)
		GameState.vibrate(140 if n >= COMBO_AMAZING else 90)
		_fx.combo_text("Fantástico!" if n >= COMBO_AMAZING else "Incrível!", col, _board_center())
	elif result.bomb != null:
		_shake(7.0)
		GameState.vibrate(60)
		_fx.combo_text("Bomba!", BlockView.BOMB_COLOR, _board_center())
	elif n >= COMBO_GOOD:
		Audio.play_sfx("combo")
		_shake(5.0)
		GameState.vibrate(35)
		_fx.combo_text("Ótimo!", col, _board_center())
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
	_fx.burst(_cell_center(p), BlockView.BOMB_COLOR, false)
	_queue_intro("bomb")  # primeira bomba: explica como usar


func _shake(strength: float) -> void:
	if GameState.progress.reduce_effects:
		return
	create_tween().tween_method(_apply_shake, strength, 0.0, 0.4)


func _apply_shake(strength: float) -> void:
	_stage.position = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))


## Se o jogador ficar parado, o maior grupo pisca para mostrar onde tocar.
func _show_hint() -> void:
	if _busy or _power != "" or _tutorial or _session.status != GameSession.Status.PLAYING:
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


# --- HUD e fim de fase -------------------------------------------------------------

func _update_hud() -> void:
	var title := tr("Fase %d") % (GameState.current_index + 1)
	if GameState.daily_mode:
		title = tr("Fase diária")
	elif _is_boss():
		title = tr("Chefe · Fase %d") % (GameState.current_index + 1)
	_hud.refresh(_session, title)
	_power_bar.refresh(_session.status == GameSession.Status.PLAYING)


## Bônus de vitória: cada jogada que sobrou estoura um bloco (+100), com som
## subindo de tom. As estrelas já foram calculadas antes.
func _play_end_bonus() -> void:
	var moves: int = _session.moves_left
	var cells: Array[Vector2i] = _session.play_end_bonus(_rng)
	if cells.is_empty():
		return
	var gen := _generation
	_hud.stop_score_animation()
	_hud.set_shown_score(_session.score - _session.end_bonus)
	_fx.combo_text("Bônus!", MOVES_COLOR, _board_center())
	await get_tree().create_timer(0.7, false).timeout
	for i in cells.size():
		if gen != _generation:
			return
		var p: Vector2i = cells[i]
		var block: Control = _blocks.get(p)
		_blocks.erase(p)
		if block:
			_fx.burst(_cell_center(p), BlockView.color_of(block.color_index), false)
			var t := create_tween()
			t.tween_property(block, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.tween_callback(block.queue_free)
		_fx.float_text("+%d" % GameSession.END_BONUS_POINTS, _cell_center(p), MOVES_COLOR, 34)
		Audio.play_sfx("pop", minf(0.9 + i * 0.06, 1.8))
		moves -= 1
		_hud.set_moves(moves)
		_hud.set_shown_score(_hud.shown_score + GameSession.END_BONUS_POINTS)
		await get_tree().create_timer(0.11, false).timeout
	_hud.set_shown_score(_session.score)
	await get_tree().create_timer(0.5, false).timeout


func _finish() -> void:
	_hint_timer.stop()
	var gen := _generation
	var won: bool = _session.status == GameSession.Status.WON
	var stars: int = _session.stars()
	_set_power("")
	_power_bar.hide_shuffle()
	_pause_button.disabled = true
	var power_text := ""
	# Primeira vitória numa fase múltipla de 5 da campanha: revela uma letra.
	var level_number := GameState.current_index + 1
	var new_letter: bool = won and not GameState.daily_mode and Endless.gives_letter(level_number) \
		and GameState.progress.stars_for(level_number) == 0
	var endless: bool = GameState.is_endless()
	var chest_before: int = GameState.chest_stars()
	var rewards: Array = []
	if won:
		var gained := GameState.complete_current_level(stars, _session.score)  # salva antes da animação do bônus
		if gained > 0:
			power_text = tr("+%d Martelo e +%d Troca!") % [gained, gained]
		rewards = GameState.last_rewards
		var extra := _endless_reward_text(rewards)
		if extra != "":
			power_text = extra if power_text == "" else power_text + "\n" + extra
		_power_bar.disable_all()
		_busy = true
		await _play_end_bonus()
		if gen != _generation:
			return
		if GameState.daily_mode:
			GameState.update_daily_best(_session.score)  # recorde do dia já com o bônus
		Audio.play_sfx("win")
	else:
		Audio.play_sfx("lose")
	var score_text := tr("Pontos: %d") % _session.score
	if _session.end_bonus > 0:
		score_text += tr("  (bônus +%d)") % _session.end_bonus
	var next := GameState.current_index + 1
	var has_next: bool = won and GameState.has_next_level()
	var info: Array = _daily_info() if GameState.daily_mode else _gate_info(next, has_next)
	var phrase := tr("MODO INFINITO")
	var revealed: int = GameState.letters_revealed()
	if new_letter and info[0] == "":
		info = [tr("Nova letra: %s!") % phrase.replace(" ", "")[revealed - 1], Color("#2BFF88")]
	_result.set_texts(won, score_text, power_text, info[0], info[1])
	_result.next_button.visible = has_next and GameState.is_unlocked(next)
	_result.back_button.text = "Menu" if GameState.daily_mode else "Fases"
	if not won:
		_result.show_shortfall(_session.shortfall())
	_result.present(stars)
	if endless:
		var opened := rewards.any(func(r): return r.kind == "chest")
		_result.show_chest(chest_before, GameState.chest_stars(), opened)
	for r in rewards:
		if r.kind == "rank":
			var rank: Dictionary = Endless.RANKS[int(r.rank)]
			_result.show_rank(tr(rank.name), Color(rank.color))
	if new_letter:
		_result.show_letters(phrase, revealed)


func _is_boss() -> bool:
	return bool(GameState.current_level().get("boss", false))


## Fase chefe: borda dourada e mais grossa no tabuleiro e título dourado.
func _set_boss_look(boss: bool) -> void:
	var col := BOSS_COLOR if boss else NEON_CYAN
	_board_style.border_color = Color(col, 0.9 if boss else 0.35)
	_board_style.set_border_width_all(5 if boss else 2)
	_board_style.shadow_color = Color(col, 0.3 if boss else 0.12)
	_hud.set_title_color(col)


## Prêmios do modo infinito (chefe, patente, baú) em linhas para a tela de resultado.
func _endless_reward_text(rewards: Array) -> String:
	var lines := []
	for r in rewards:
		var prize := Daily.reward_text(r.reward)
		match String(r.kind):
			"boss":
				lines.append(tr("Chefe derrotado! %s") % prize)
			"rank":
				lines.append(tr("Nova patente: %s! %s") % [tr(Endless.RANKS[int(r.rank)].name), prize])
			"chest":
				lines.append(tr("Baú aberto! %s") % prize)
	return "\n".join(lines)


## Fase diária: recorde do dia e se o prêmio já foi ganho. [texto, cor]
func _daily_info() -> Array:
	var progress = GameState.progress
	var day: int = GameState.today()
	if progress.daily_won_today(day):
		return [tr("Recorde de hoje: %d pontos.\nAmanhã tem uma fase nova!") % progress.daily_best_today(day), Color("#FFE53D")]
	return [tr("Vença a fase diária para ganhar\n+1 Martelo e +1 Troca."), Color("#FFE53D")]


## Se a próxima fase é um portão de estrelas, avisa se foi liberada ou
## quantas estrelas faltam. [texto, cor] (texto vazio = sem aviso)
func _gate_info(next: int, has_next: bool) -> Array:
	if has_next and next == GameState.levels.size():
		return [tr("Modo infinito liberado! As fases
agora continuam sem fim."), Color("#2BFF88")]
	var required: int = GameState.stars_required(next) if has_next else 0
	if required == 0:
		return ["", Color.WHITE]
	var missing: int = GameState.missing_stars(next)
	if missing == 0:
		return [tr("Fase %d liberada!") % (next + 1), Color("#2BFF88")]
	return [tr("A fase %d exige %d estrelas. Faltam %d: jogue de novo as fases anteriores para conseguir mais estrelas.") % [next + 1, required, missing], Color("#FFE53D")]
