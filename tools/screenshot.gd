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

	# Tela de resultado (vitória forçada).
	# Vence a fase 9 com 3 estrelas: 18 - 1 + 3 = 20, o que libera o portão da fase 10.
	_gs.current_index = 8
	game._session.status = game.GameSession.Status.WON
	game._session.moves_left = game._session.max_moves
	game._session.score = 1240
	game._finish()
	await create_timer(1.6).timeout
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
