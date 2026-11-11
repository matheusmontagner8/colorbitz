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
	for i in 7:
		demo.record_result(i + 1, [3, 3, 2, 3, 1, 2, 3][i])
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

	# Efeitos de combinação grande (só visual: o tabuleiro não muda).
	var group: Array = game._session.board.best_group()
	var fake := []
	while fake.size() < 13:
		fake.append_array(group)
	game._play_effects({"removed": fake.slice(0, 13), "color": game._session.board.get_cell(group[0].x, group[0].y), "points": 1690})
	await create_timer(0.14).timeout
	await _save("res://docs/effects.png")
	await create_timer(1.2).timeout

	# Tela de resultado (vitória forçada).
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
