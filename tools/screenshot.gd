## Teste de fumaça da interface: percorre as telas, simula toques reais e
## salva capturas em docs/ (usadas no README). Não altera o save do jogador.
## Uso (precisa de janela, não use --headless):
##   godot --path . -s tools/screenshot.gd
extends SceneTree

const Progress = preload("res://scripts/progress.gd")
const Intros = preload("res://scripts/intros.gd")
const BlockView = preload("res://scripts/block_view.gd")
## Dia fixo (12/11/2026) para as capturas da fase diária saírem sempre iguais.
const DEMO_DAY := 20769

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
	_gs.day_override = DEMO_DAY
	demo.daily_claim_day = DEMO_DAY  # recompensa de hoje já resgatada: menu sem o popup
	demo.daily_streak = 2
	demo.stats = {"bombs_created": 1, "best_group": 11, "blocks": 420, "ice": 12, "powers": 4, "wins_no_power": 6, "wins": 9}
	demo.achievements = {"primeira_bomba": true}
	demo.tutorials = {"powers": true}  # tutorial dos poderes e cartões têm cenário próprio
	for id in Intros.CARDS:
		Intros.mark_seen(id, demo)
	demo.language = "pt"  # capturas sempre em português (há um cenário em inglês no fim)
	TranslationServer.set_locale("pt")
	_gs.progress = demo

	await _shot("res://scenes/main_menu.tscn", "res://docs/menu.png")
	await _shot("res://scenes/level_select.tscn", "res://docs/levels.png")
	await _shot("res://scenes/options.tscn", "res://docs/options.png")

	# Rolagem da tela de fases: arrastar começando em cima de um botão rola
	# (sem abrir a fase); um toque simples abre a fase.
	change_scene_to_file("res://scenes/level_select.tscn")
	await _frames(6)
	var select = current_scene
	var scroll: ScrollContainer = select.get_node("%Scroll")
	scroll.scroll_vertical = 0
	await _frames(2)
	var first_button: Button = select.get_node("%Grid").get_child(0)
	var start: Vector2 = first_button.get_global_rect().get_center()
	_mouse_button(start, true)
	for i in 12:
		await _frames(1)
		_mouse_move(start + Vector2(0, -40 * (i + 1)), Vector2(0, -40))
	_mouse_button(start + Vector2(0, -480), false)
	await create_timer(0.6).timeout
	assert(current_scene == select, "arrastar não abre a fase")
	assert(scroll.scroll_vertical >= 400, "arrastar em cima dos botões rola a grade (%d)" % scroll.scroll_vertical)
	scroll.scroll_vertical = 0
	await _frames(3)
	var tap_at: Vector2 = first_button.get_global_rect().get_center()
	_mouse_button(tap_at, true)
	await _frames(1)
	_mouse_button(tap_at, false)
	await _frames(4)
	assert(current_scene != select and _gs.current_index == 0, "toque simples abre a fase 1")
	print("rolagem da tela de fases: ok")

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
	assert(game._blocks[Vector2i(3, 7)].color_index == BlockView.BOMB, "visual da bomba")
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
	var h0: int = _gs.power_count("hammer")
	var s0: int = _gs.power_count("swap")
	assert(h0 >= 3 and s0 >= 3, "saldo inicial dos poderes")
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
	assert(_gs.power_count("hammer") == h0 - 1 and game._power == "", "martelo gasto e modo desligado")
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
	assert(game._session.moves_left == moves and _gs.power_count("swap") == s0 - 1, "troca gasta o poder, não a jogada")
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
	assert(game._tip.is_showing(game.STUCK_TIP), "dica de travado")
	assert(game._power_bar.shuffle_button.visible, "botão Embaralhar aparece quando trava")
	await create_timer(0.5).timeout
	await _save("res://docs/stuck.png")
	game._power_bar.shuffle_button.pressed.emit()  # embaralha sem gastar poder
	await create_timer(1.0).timeout
	assert(not game._power_bar.shuffle_button.visible and not game._session.is_stuck(), "botão embaralhou e sumiu")
	assert(_gs.power_count("hammer") == h0 - 1 and _gs.power_count("swap") == s0 - 1, "embaralhar não gasta poder")
	game._power_bar.shuffle_button.pressed.emit()  # destravado: o botão não faz nada
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
	assert(game._hud.goal_parts.size() == 2, "meta dupla mostra duas cores")
	await _save("res://docs/specials.png")
	# Joia e gelo num tabuleiro montado: o grupo de 1 embaixo da joia a leva ao fundo.
	game._session.goal = {"type": "drop", "count": 5}
	game._session.board.load_rows([
		"0123401", "1234012", "2W40123", "3401234", "4S12340",
		"0123401", "123G012", "2341123", "3401234",
	])
	game._session.board.set_ice(2, 8, 2)
	game._hud.build_goal_row(game._session)
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

	# Tutorial dos poderes (jogador novo na fase 2): só o alvo destacado aceita
	# toque e os usos são grátis.
	_gs.progress.tutorials.erase("powers")
	_gs.current_index = 1
	game._start_level()
	await create_timer(0.6).timeout
	var tut = game._tutorial
	assert(tut != null and tut.step == tut.Step.HAMMER_BUTTON, "tutorial começa no Martelo")
	var hammers0: int = _gs.power_count("hammer")
	var swaps0: int = _gs.power_count("swap")
	game._power_bar.buttons["swap"].pressed.emit()  # fora de ordem: ignorado
	await _frames(2)
	assert(game._power == "", "só o botão destacado responde")
	await _save("res://docs/tutorial_hammer.png")
	game._power_bar.buttons["hammer"].pressed.emit()
	await _frames(2)
	assert(tut.step == tut.Step.HAMMER_CELL, "passo do bloco")
	var other := Vector2i(0, 0) if tut.hammer_cell != Vector2i(0, 0) else Vector2i(1, 0)
	var blocks0: int = game._session.board.count_blocks()
	_tap(game, other)  # bloco errado: não faz nada
	await _frames(2)
	assert(game._session.board.count_blocks() == blocks0, "bloco fora do destaque é ignorado")
	await _save("res://docs/tutorial_cell.png")
	_tap(game, tut.hammer_cell)
	await create_timer(1.0).timeout
	assert(tut.step == tut.Step.SWAP_BUTTON and tut.swap_cells.size() == 2, "passo da Troca")
	game._power_bar.buttons["swap"].pressed.emit()
	await _frames(3)
	await _save("res://docs/tutorial_swap_pair.png")
	_tap(game, tut.swap_cells[0])
	await _frames(2)
	assert(tut.step == tut.Step.SWAP_SECOND, "segundo bloco da troca")
	await _save("res://docs/tutorial_swap.png")
	_tap(game, tut.swap_cells[1])
	await create_timer(0.8).timeout
	assert(game._tutorial == null and _gs.progress.tutorials.has("powers"), "tutorial concluído e salvo")
	assert(_gs.power_count("hammer") == hammers0 and _gs.power_count("swap") == swaps0, "tutorial não gasta poderes")
	assert(game._session.moves_left == game._session.max_moves, "nem jogadas")
	await create_timer(4.0).timeout
	assert(not is_instance_valid(tut), "balão final some sozinho")
	game._start_level()
	await _frames(3)
	assert(game._tutorial == null, "não repete depois de concluído")
	print("tutorial dos poderes: ok")

	# Cartões de apresentação: primeira fase de meta de cor (fase 3) e primeira bomba.
	_gs.progress.tutorials.erase(Intros.key("goal_color"))
	_gs.progress.tutorials.erase(Intros.key("bomb"))
	_gs.current_index = 2
	game._start_level()
	await create_timer(0.5).timeout
	assert(game._intro.visible and game._intro.id == "goal_color", "cartão da meta de cor")
	var blocks_before_tap: int = game._session.board.count_blocks()
	_tap(game, Vector2i(3, 8))  # o cartão bloqueia o jogo até fechar
	game._power_bar.buttons["hammer"].pressed.emit()
	await _frames(2)
	assert(game._session.board.count_blocks() == blocks_before_tap and game._power == "", "jogo bloqueado com o cartão aberto")
	await _save("res://docs/intro_color.png")
	game._intro.find_children("*", "Button", true, false)[0].pressed.emit()
	await _frames(2)
	assert(not game._intro.visible and _gs.progress.tutorials.has(Intros.key("goal_color")), "fechou e ficou salvo")
	game._session.board.load_rows(["1234512", "2345123", "3451234", "4512345", "5123451", "1200002", "2300003", "3400004", "4512345"])
	game._rebuild_blocks()
	await _frames(2)
	_tap(game, Vector2i(3, 6))  # grupo de 12: vira bomba e o cartão explica
	await create_timer(1.0).timeout
	assert(game._intro.visible and game._intro.id == "bomb", "cartão da primeira bomba")
	assert(game._intro.text_label.text.contains("%d blocos" % game._session.board.bomb_group_size), "texto com o tamanho do grupo")
	await _save("res://docs/intro_bomb.png")
	game._intro.find_children("*", "Button", true, false)[0].pressed.emit()
	await _frames(2)
	game._start_level()
	await _frames(3)
	assert(not game._intro.visible, "não repete o que já foi visto")
	print("cartões de apresentação: ok")

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
	assert(game._result.visible, "resultado aparece depois do bônus")
	print("bônus de fim de fase: ok")
	await _save("res://docs/result.png")

	# Derrota: mostra quanto faltou. Meta dupla (fase 32) com uma cor cumprida
	# e outra pela metade: só a que falta aparece.
	_gs.current_index = 31
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(6)
	game = current_scene
	var targets: Dictionary = game._session.color_targets()
	var goal_colors: Array = targets.keys()
	game._session.removed_by_color = {goal_colors[0]: targets[goal_colors[0]], goal_colors[1]: targets[goal_colors[1]] / 2}
	game._session.moves_left = 0
	game._session.status = game.GameSession.Status.LOST
	game._finish()
	await create_timer(1.3).timeout
	var near = game._result.near_miss
	assert(near.visible and not game._result.stars.visible, "derrota mostra quanto faltou, sem estrelas")
	assert(near.header.text == "Faltou:", "longe da meta: sem 'quase'")
	assert(near.row.get_child_count() == 3, "só a cor que falta: título + bloco + número")
	await _save("res://docs/lose_colors.png")
	# Meta de pontos, perdendo por pouco (90%): "Quase!".
	_gs.current_index = 7
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(6)
	game = current_scene
	game._session.score = roundi(game._session.goal_target() * 0.9)
	game._session.moves_left = 0
	game._session.status = game.GameSession.Status.LOST
	game._finish()
	await create_timer(1.3).timeout
	near = game._result.near_miss
	assert(near.header.text == "Quase! Faltou:", "perto da meta")
	assert(near.bar.value > 85.0, "barra mostra 90%% da meta (%.1f)" % near.bar.value)
	await _save("res://docs/lose_close.png")
	print("derrota mostra quanto faltou: ok")

	# Modo daltônico: paleta segura e símbolos brancos maiores (fase com 6 cores).
	_gs.progress.colorblind = true
	_gs.apply_settings()
	_gs.current_index = 40
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(6)
	game = current_scene
	assert(BlockView.colorblind and BlockView.palette() == BlockView.COLORBLIND_COLORS, "paleta daltônica ativa")
	await _save("res://docs/colorblind.png")
	change_scene_to_file("res://scenes/options.tscn")
	await _frames(6)
	assert(current_scene.get_node("%ColorblindButton").text == "Daltonismo: ligado", "opção mostra ligado")
	await _save("res://docs/options_colorblind.png")
	current_scene.get_node("%ColorblindButton").pressed.emit()
	await _frames(2)
	assert(not _gs.progress.colorblind and not BlockView.colorblind, "desliga pelas opções")
	print("modo daltônico: ok")

	# Fase diária: mesmo tabuleiro para todos no dia; vencer dá +1 de cada poder
	# e libera a conquista "Desafio do dia" (aviso no topo).
	var progress = _gs.progress
	_gs.start_daily()
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(5)
	game = current_scene
	assert(game._hud.level_label.text == "Fase diária", "título da fase diária")
	assert(game._session.board.to_rows() == game.LevelLoader.build_session(_gs.current_level()).board.to_rows(), "tabuleiro do dia é fixo")
	await _save("res://docs/daily.png")
	var swaps: int = _gs.power_count("swap")
	game._session.status = game.GameSession.Status.WON
	game._session.score = 1300
	game._finish()
	await _frames(2)
	assert(progress.daily_won_today(DEMO_DAY) and progress.has_achievement("desafio_do_dia"), "vitória diária registrada")
	assert(_gs._toast_layer.get_child_count() == 1, "aviso da conquista")
	assert(_gs.power_count("swap") == swaps + 2, "+1 Troca da vitória e +1 da conquista")
	await create_timer(1.2).timeout
	await _save("res://docs/toast.png")
	await create_timer(3.5).timeout
	assert(game._result.visible and not game._result.next_button.visible, "sem próxima fase na diária")
	assert(game._result.back_button.text == "Menu" and game._result.info_label.text.begins_with("Recorde de hoje"), "resultado da diária")
	assert(progress.daily_best_today(DEMO_DAY) == game._session.score, "recorde inclui o bônus")
	await _save("res://docs/daily_result.png")
	print("fase diária: ok")

	# Recompensa diária: abriu o jogo no dia seguinte, 3º dia seguido.
	await create_timer(0.5).timeout
	_gs.day_override = DEMO_DAY + 1
	var hammers: int = _gs.power_count("hammer")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(6)
	var menu = current_scene
	assert(menu.reward_overlay != null, "popup da recompensa diária")
	assert(menu.get_node("%DailyButton").text.begins_with("Fase diária: "), "nova fase diária no dia seguinte")
	await _save("res://docs/daily_reward.png")
	menu._claim_reward()
	await create_timer(0.5).timeout
	assert(_gs.power_count("hammer") == hammers and progress.daily_streak == 3, "dia 3: só conta a sequência")
	assert(not progress.can_claim_daily(DEMO_DAY + 1), "só uma vez por dia")
	# 7º dia seguido: prêmio de 2 de cada.
	_gs.day_override = DEMO_DAY + 5
	progress.daily_streak = 6
	progress.daily_claim_day = DEMO_DAY + 4
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(6)
	menu = current_scene
	await _save("res://docs/daily_reward_7.png")
	menu._claim_reward()
	await create_timer(0.5).timeout
	assert(progress.daily_streak == 7 and progress.has_achievement("toda_semana"), "7 dias seguidos")
	assert(_gs.power_count("hammer") == hammers + 3, "prêmio do 7º dia (+2) e conquista Toda semana (+1)")
	print("recompensa diária: ok")

	change_scene_to_file("res://scenes/achievements.tscn")
	await _frames(6)
	assert(current_scene.get_node("%List").get_child_count() == current_scene.Achievements.LIST.size(), "lista de conquistas")
	await _save("res://docs/achievements.png")
	print("conquistas: ok")

	# Letras de "MODO INFINITO": a fase 10 (vencida pela 1ª vez) revela o "O".
	_gs.daily_mode = false  # o cenário da fase diária deixou o modo ligado
	_gs.current_index = 9
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(6)
	game = current_scene
	game._session.status = game.GameSession.Status.WON
	game._finish()
	await create_timer(4.5).timeout
	assert(game._result.info_label.text == "Nova letra: O!", "aviso da letra nova")
	assert(game._result.letters.visible and _gs.letters_revealed() == 2, "palavra com 2 letras (M, O)")
	await _save("res://docs/letters_result.png")
	change_scene_to_file("res://scenes/level_select.tscn")
	await _frames(6)
	await _save("res://docs/letters_levels.png")
	print("letras do modo infinito: ok")

	# Modo infinito: vencer a fase 60 libera fases sem fim a partir da 61.
	for i in 59:
		progress.record_result(i + 1, 2)
	_gs.daily_mode = false  # o cenário da fase diária deixou o modo ligado
	_gs.current_index = 59
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(6)
	game = current_scene
	game._session.status = game.GameSession.Status.WON
	game._finish()
	await create_timer(4.5).timeout
	assert(game._result.info_label.text.begins_with("Modo infinito liberado"), "aviso do modo infinito")
	assert(game._result.next_button.visible, "próxima fase (61) disponível")
	assert(game._result.letters.visible and _gs.letters_revealed() == 12, "palavra completa")
	await _save("res://docs/endless_unlocked.png")
	change_scene_to_file("res://scenes/level_select.tscn")
	await _frames(6)
	var endless_button: Button = null
	for child in current_scene.find_children("*", "Button", true, false):
		if child.text.begins_with("Modo infinito"):
			endless_button = child
	assert(endless_button != null and endless_button.text == "Modo infinito: fase 61" and not endless_button.disabled, "botão do modo infinito")
	await _save("res://docs/endless_levels.png")
	endless_button.pressed.emit()
	await _frames(6)
	game = current_scene
	assert(_gs.current_index == 60 and game._hud.level_label.text == "Fase 61", "fase 61 em jogo")
	await _save("res://docs/endless.png")
	game._session.status = game.GameSession.Status.WON
	game._finish()
	await create_timer(4.5).timeout
	assert(game._result.next_button.visible and _gs.endless_next_index() == 61, "depois da 61 vem a 62")
	print("modo infinito: ok")

	# Chefe (fase 70): borda dourada; vencer dá prêmio, patente Bronze e enche o baú.
	for n in range(62, 70):
		progress.record_result(n, 3)
	_gs.current_index = 69
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(6)
	game = current_scene
	assert(game._hud.level_label.text == "Chefe · Fase 70", "título do chefe (%s)" % game._hud.level_label.text)
	assert(game._board_style.border_color.is_equal_approx(Color(game.BOSS_COLOR, 0.9)), "borda dourada")
	await _save("res://docs/boss.png")
	game._intro.open("endless_goals")
	await create_timer(0.5).timeout
	await _save("res://docs/intro_endless_goals.png")
	game._intro.visible = false
	game._session.status = game.GameSession.Status.WON
	game._session.moves_left = game._session.max_moves
	game._finish()
	await create_timer(5.0).timeout
	assert(game._result.power_label.text.contains("Chefe derrotado!"), "prêmio do chefe")
	assert(game._result.power_label.text.contains("Nova patente: Bronze!"), "patente nova")
	assert(game._result.rank_row.visible and game._result.chest.visible, "medalha e baú no resultado")
	assert(_gs.rank_index() == 0, "patente Bronze")
	await _save("res://docs/boss_result.png")
	change_scene_to_file("res://scenes/level_select.tscn")
	await _frames(6)
	var texts := current_scene.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert("Patente Bronze" in texts and "Chefe: fase 80" in texts, "patente e próximo chefe na tela de fases")
	await _save("res://docs/endless_status.png")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(6)
	assert(current_scene.find_child("RankBadge", true, false) != null, "selo da patente no menu")
	await _save("res://docs/menu_rank.png")
	print("chefe, patente e baú: ok")

	# Opções: trocar o idioma pela tela muda os textos na hora.
	change_scene_to_file("res://scenes/options.tscn")
	await _frames(6)
	var options = current_scene
	options.get_node("%LanguageButton").pressed.emit()
	await _frames(3)
	assert(progress.language == "en" and TranslationServer.get_locale() == "en", "idioma trocado")
	assert(options.get_node("%LanguageButton").text == "Language: English", "botão em inglês")
	await _save("res://docs/en_options.png")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(6)
	await _save("res://docs/en_menu.png")
	_gs.daily_mode = false
	_gs.current_index = 31  # fase 32: meta dupla
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(6)
	assert(current_scene._hud.level_label.text == "Level 32", "HUD em inglês")
	await _save("res://docs/en_game.png")
	print("inglês: ok")

	# Apagar progresso: pede confirmação, zera tudo e mantém as opções.
	change_scene_to_file("res://scenes/options.tscn")
	await _frames(6)
	options = current_scene
	options.get_node("%ResetButton").pressed.emit()
	await _frames(3)
	assert(options.confirm != null and options.confirm.visible, "confirmação aparece")
	await _save("res://docs/en_reset.png")
	options._do_reset()
	await _frames(2)
	assert(_gs.progress.total_stars() == 0 and _gs.progress.achievements.is_empty(), "progresso zerado")
	assert(_gs.progress.language == "en", "opções mantidas")
	print("apagar progresso: ok")
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


## Eventos de mouse/toque "de verdade" (passam pelo _input e pela interface).
func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(ev, true)


func _mouse_move(pos: Vector2, relative: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = relative
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(ev, true)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _tap(game, cell: Vector2i) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = (Vector2(cell) + Vector2(0.5, 0.5)) * game._cell
	game._on_board_input(ev)
