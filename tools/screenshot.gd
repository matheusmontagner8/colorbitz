## Abre a cena de jogo, simula alguns toques e salva uma captura de tela.
## Serve como teste de fumaça da interface e para gerar imagens do README.
## Uso (precisa de janela, não use --headless):
##   godot --path . -s tools/screenshot.gd -- docs/screenshot.png
extends SceneTree


func _initialize() -> void:
	var out := "res://docs/screenshot.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var game: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await _frames(5)

	# Toca em até 3 grupos válidos, simulando clique real no tabuleiro.
	var taps := 0
	var board = game._session.board
	for y in board.height:
		for x in board.width:
			if taps >= 3:
				break
			if board.find_group(x, y).size() >= 2:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = true
				ev.position = (Vector2(x, y) + Vector2(0.5, 0.5)) * game._cell
				game._on_board_input(ev)
				await create_timer(0.6).timeout
				taps += 1
	print("toques válidos: %d, pontos: %d, jogadas: %d" % [taps, game._session.score, game._session.moves_left])

	await _frames(3)
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	img.save_png(out)
	print("captura salva em %s" % out)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
