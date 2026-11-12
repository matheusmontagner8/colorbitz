## Teste de fumaça da interface: percorre as telas, simula toques reais e
## salva capturas em docs/ (usadas no README). Não altera o save do jogador.
## Uso (precisa de janela, não use --headless):
##   godot --path . -s tools/screenshot.gd
extends SceneTree

const Progress = preload("res://scripts/progress.gd")

var _gs: Node


func _initialize() -> void:
	_gs = root.get_node("GameState")
	_gs.save_enabled = false
	await _frames(1)  # deixa o GameState terminar o _ready (que carrega o save real)
	# Progresso de demonstração (só em memória) para a tela de fases.
	var demo = Progress.new()
	# 9 fases vencidas, 18 estrelas: a fase 10 (portão de 20) aparece trancada.
	var demo_stars := [3, 2, 2, 3, 1, 2, 2, 2, 1]
	for i in demo_stars.size():
		demo.record_result(i + 1, demo_stars[i])
	_gs.progress = demo

	await _shot("res://scenes/main_menu.tscn", "res://docs/menu.png")
	await _shot("res://scenes/level_select.tscn", "res://docs/levels.png")
	await _shot("res://scenes/options.tscn", "res://docs/options.png")

	_gs.current_index = 7  # fase 8: meta alta o bastante para não vencer com poucos toques
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(5)
	var game = current_scene
	var taps := await _tap_groups(game, 3)
	print("jogo: %d toques válidos, pontos %d, jogadas %d" % [taps, game._session.score, game._session.moves_left])
	await _save("res://docs/screenshot.png")

	# Pausa no meio de uma animação e reinicia: não pode quebrar.
	_tap_groups(game, 1)
	await _frames(2)
	game._pause()
	await _frames(3)
	assert(paused, "jogo deveria estar pausado")
	await _save("res://docs/pause.png")
	game._restart()
	await create_timer(0.8).timeout
	assert(not paused and not game._busy, "reinício deve limpar pausa e animação")
	assert(game._board_root.get_child_count() == game._blocks.size(), "blocos órfãos após reiniciar")
	print("pausa/reinício durante animação: ok")

	# Bomba: tabuleiro montado com um grupo de 12 azuis (cor 0) no meio.
	game._session.goal = {"type": "score", "target": 99999}
	game._session.board.load_rows([
		"1234512",
		"2345123",
		"3451234",
		"4512345",
		"5123451",
		"1200002",
		"2300003",
		"3400004",
		"4512345",
	])
	game._rebuild_blocks()
	game._update_hud()
	await _frames(3)
	_tap(game, Vector2i(3, 6))  # grupo de 12: "Incrível!" e o bloco tocado vira bomba
	await create_timer(1.0).timeout
	var bombs: Array = game._session.board.bombs()
	assert(bombs == [Vector2i(3, 7)], "bomba deveria ter caído para (3, 7)")
	assert(game._blocks[Vector2i(3, 7)].color_index == game.BlockView.BOMB, "visual da bomba")
	await _save("res://docs/bomb.png")
	_tap(game, bombs[0])  # explode a área 3x3
	await create_timer(0.12).timeout
	await _save("res://docs/effects.png")
	await create_timer(1.2).timeout
	assert(not game._busy and game._session.board.bombs().is_empty(), "bomba usada")
	assert(game._board_root.get_child_count() == game._blocks.size(), "blocos órfãos após a explosão")
	assert(game._blocks.size() == game._session.board.count_blocks(), "visual e tabuleiro com o mesmo número de blocos")
	print("bomba criada e explodida: ok")

	# Poderes especiais: 18 estrelas de demonstração: ainda só os 3 iniciais (o próximo vem com 21).
	assert(_gs.power_count("hammer") == 3 and _gs.power_count("swap") == 3, "saldo inicial dos poderes")
	var moves: int = game._session.moves_left
	var blocks_before: int = game._session.board.count_blocks()
	game._toggle_power("hammer")
	await _frames(3)
	await _save("res://docs/powers.png")
	var b = game._session.board
	_tap(game, Vector2i(0, b.height - 1))
	await create_timer(0.9).timeout
	assert(b.count_blocks() == blocks_before - 1, "martelo destrói um bloco")
	assert(game._session.moves_left == moves, "martelo não gasta jogada")
	assert(_gs.power_count("hammer") == 2 and game._power == "", "martelo gasto e modo desligado")
	# Troca: dois blocos de cores diferentes.
	var a := Vector2i(0, b.height - 1)
	var c := Vector2i(b.width - 1, b.height - 1)
	for x in b.width:
		if b.get_cell(x, b.height - 1) != b.get_cell(a.x, a.y) and b.get_cell(x, b.height - 1) >= 0:
			c = Vector2i(x, b.height - 1)
	var color_a: int = b.get_cell(a.x, a.y)
	var color_c: int = b.get_cell(c.x, c.y)
	game._toggle_power("swap")
	_tap(game, a)
	await _frames(2)
	_tap(game, c)
	await create_timer(0.6).timeout
	assert(b.get_cell(a.x, a.y) == color_c and b.get_cell(c.x, c.y) == color_a, "troca no tabuleiro")
	assert(game._session.moves_left == moves and _gs.power_count("swap") == 2, "troca gasta o poder, não a jogada")
	for p in game._blocks:
		assert(game._blocks[p].color_index == b.get_cell(p.x, p.y), "visual diferente do tabuleiro em %s" % p)
	assert(game._board_root.get_child_count() == game._blocks.size(), "blocos órfãos após os poderes")
	print("martelo e troca: ok")

	# Tabuleiro travado (sem nenhum grupo): cada linha é a de cima deslocada.
	game._session.board.load_rows([
		"0123401", "1234012", "2340123", "3401234", "4012340",
		"0123401", "1234012", "2340123", "3401234",
	])
	game._rebuild_blocks()
	game._update_hud()
	await _frames(2)
	assert(game._session.is_stuck(), "tabuleiro de teste deveria estar travado")
	game._after_move()  # com poderes: a fase continua e pede para usar um
	await _frames(3)
	assert(game._session.status == game.GameSession.Status.PLAYING, "travado com poderes não perde")
	assert(game._tutorial_label.text == game.STUCK_TIP and game._tutorial_label.visible, "dica de travado")
	assert(game._shuffle_button.visible, "botão Embaralhar aparece quando trava")
	await create_timer(0.5).timeout
	await _save("res://docs/stuck.png")
	game._shuffle_button.pressed.emit()  # embaralha sem gastar poder
	await create_timer(1.0).timeout
	assert(not game._shuffle_button.visible and not game._session.is_stuck(), "botão embaralhou e sumiu")
	assert(_gs.power_count("hammer") == 2 and _gs.power_count("swap") == 2, "embaralhar não gasta poder")
	game._shuffle_button.pressed.emit()  # destravado: o botão não faz nada
	await _frames(2)
	assert(not game._busy, "embaralhar só funciona com o tabuleiro travado")
	# Trava de novo para testar o caminho sem poderes.
	game._session.board.load_rows([
		"0123401", "1234012", "2340123", "3401234", "4012340",
		"0123401", "1234012", "2340123", "3401234",
	])
	game._rebuild_blocks()
	await _frames(2)
	var saved_used: Dictionary = _gs.progress.powers_used.duplicate()
	_gs.progress.powers_used = {"hammer": 99, "swap": 99}  # sem poderes: embaralha sozinho
	game._after_move()
	await create_timer(1.0).timeout
	assert(not game._busy and not game._session.is_stuck(), "embaralhou e destravou")
	for p in game._blocks:
		assert(game._blocks[p].color_index == game._session.board.get_cell(p.x, p.y), "visual após embaralhar")
	_gs.progress.powers_used = saved_used
	print("tabuleiro travado (poderes e embaralhar): ok")

	# Fase 60: formato "janela", pedras e gelo grosso.
	_gs.current_index = 59
	game._start_level()
	await create_timer(0.6).timeout
	assert(game._session.board.count_color(game._session.board.HOLE) > 0, "fase 60 tem buracos")
	assert(game._goal_parts.size() == 2, "meta dupla mostra duas cores")
	await _save("res://docs/specials.png")
	# Joia e gelo num tabuleiro montado: o grupo de 1 embaixo da joia a leva ao fundo.
	game._session.goal = {"type": "drop", "count": 5}
	game._session.board.load_rows([
		"0123401", "1234012", "2W40123", "3401234", "4S12340",
		"0123401", "123G012", "2341123", "3401234",
	])
	game._session.board.set_ice(2, 8, 2)
	game._build_goal_row()
	game._rebuild_blocks()
	game._update_hud()
	await _frames(3)
	await _save("res://docs/gems.png")
	_tap(game, Vector2i(3, 8))
	await create_timer(1.3).timeout
	assert(game._session.gems_collected == 1, "joia coletada")
	assert(game._session.board.get_ice(2, 8) == 1 and game._blocks[Vector2i(2, 8)].ice == 1, "gelo rachou (visual e tabuleiro)")
	assert(game._blocks.size() == game._session.board.count_blocks(), "visual e tabuleiro após a joia")
	assert(game._board_root.get_child_count() == game._blocks.size(), "nó da joia liberado")
	print("especiais (formato, joia, gelo): ok")

	# Tela de resultado (vitória forçada), com o bônus das jogadas que sobraram.
	# Vence a fase 9 com 3 estrelas: 18 - 1 + 3 = 20, o que libera o portão da fase 10.
	_gs.current_index = 8
	game._session.status = game.GameSession.Status.WON
	game._session.moves_left = game._session.max_moves
	game._session.score = 1240
	var blocks_left: int = game._session.board.count_blocks()
	game._finish()
	await create_timer(1.3).timeout
	await _save("res://docs/bonus.png")
	await create_timer(3.0).timeout
	var popped: int = mini(game._session.max_moves, blocks_left)
	assert(game._session.end_bonus == popped * game.GameSession.END_BONUS_POINTS, "bônus = jogadas que sobraram")
	assert(game._blocks.size() == game._session.board.count_blocks(), "visual e tabuleiro após o bônus")
	assert(game._result_overlay.visible, "resultado aparece depois do bônus")
	print("bônus de fim de fase: ok")
	await _save("res://docs/result.png")
	print("captura concluída")
	quit()


func _shot(scene: String, out: String) -> void:
	change_scene_to_file(scene)
	await _frames(6)
	await _save(out)


func _save(out: String) -> void:
	await _frames(2)
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	img.save_png(out)
	print("salvo %s" % out)


## Toca em até n grupos válidos simulando clique real no tabuleiro.
func _tap_groups(game, n: int) -> int:
	var taps := 0
	var board = game._session.board
	for y in board.height:
		for x in board.width:
			if taps >= n:
				return taps
			if board.find_group(x, y).size() >= 2:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = true
				ev.position = (Vector2(x, y) + Vector2(0.5, 0.5)) * game._cell
				game._on_board_input(ev)
				taps += 1
				if n > 1:
					await create_timer(0.6).timeout
	return taps


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _tap(game, cell: Vector2i) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = (Vector2(cell) + Vector2(0.5, 0.5)) * game._cell
	game._on_board_input(ev)
