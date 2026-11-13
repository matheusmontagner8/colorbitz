extends "res://tests/test_case.gd"

const Board = preload("res://scripts/board.gd")
const GameSession = preload("res://scripts/game_session.gd")


func _session(rows: Array, moves: int, goal: Dictionary) -> GameSession:
	var b := Board.new()
	b.load_rows(rows)
	var s := GameSession.new()
	s.setup(b, moves, goal)
	return s


func test_valid_tap_spends_move_and_scores() -> void:
	var s := _session(["1122", "3344"], 5, {"type": "score", "target": 9999})
	var r := s.tap(0, 0)
	assert_false(r.is_empty())
	assert_eq(s.moves_left, 4)
	assert_eq(s.score, 40)
	assert_eq(s.status, GameSession.Status.PLAYING)


func test_invalid_tap_is_free() -> void:
	var s := _session(["1122", "3456"], 5, {"type": "score", "target": 9999})
	assert_true(s.tap(0, 1).is_empty())
	assert_eq(s.moves_left, 5)
	assert_eq(s.score, 0)


func test_win_by_score() -> void:
	var s := _session(["11", "22"], 5, {"type": "score", "target": 40})
	s.tap(0, 0)
	assert_eq(s.status, GameSession.Status.WON)
	assert_eq(s.stars(), 3)


func test_win_by_color_goal() -> void:
	var s := _session(["11", "22", "11"], 5, {"type": "color", "color": 2, "count": 2})
	s.tap(0, 0)
	assert_eq(s.status, GameSession.Status.PLAYING, "remover a cor errada não vence")
	assert_eq(s.goal_progress(), 0)
	s.tap(0, 1)
	assert_eq(s.goal_progress(), 2)
	assert_eq(s.status, GameSession.Status.WON)


func test_bomb_spends_move_and_counts_for_color_goal() -> void:
	var s := _session([
		"0123",
		"1B21",
		"3210",
	], 5, {"type": "color", "color": 2, "count": 3})
	s.tap(1, 1)
	assert_eq(s.moves_left, 4, "usar a bomba gasta uma jogada")
	assert_eq(s.goal_progress(), 3, "blocos destruídos pela bomba contam para a meta de cor")
	assert_eq(s.status, GameSession.Status.WON)


func test_game_not_lost_while_bomb_available() -> void:
	var s := _session(["11111111", "23232323"], 10, {"type": "score", "target": 99999})
	s.tap(0, 0)  # grupo de 8 vira bomba; restam blocos sem grupo
	assert_eq(s.status, GameSession.Status.PLAYING, "ainda dá para usar a bomba")
	assert_eq(s.board.to_rows(), ["B.......", "23232323"])
	s.tap(0, 0)
	assert_true(s.is_stuck(), "sem bomba e sem grupos: travado, mas não perdido")


func test_color_goal_from_json_floats() -> void:
	var s := _session(["11", "22"], 5, {"type": "color", "color": 2.0, "count": 2.0})
	s.tap(0, 1)
	assert_eq(s.status, GameSession.Status.WON, "JSON devolve números como float")


func test_lose_when_out_of_moves() -> void:
	var s := _session(["1122", "3344"], 1, {"type": "score", "target": 1000})
	s.tap(0, 0)
	assert_eq(s.moves_left, 0)
	assert_eq(s.status, GameSession.Status.LOST)
	assert_true(s.tap(2, 1).is_empty(), "sem jogadas após o fim")


func test_no_groups_left_is_stuck_not_lost() -> void:
	var s := _session(["112", "343"], 10, {"type": "score", "target": 1000})
	s.tap(0, 0)
	assert_false(s.board.has_moves())
	assert_eq(s.status, GameSession.Status.PLAYING, "dá para usar um poder ou embaralhar")
	assert_true(s.is_stuck())
	assert_eq(s.moves_left, 9)


func test_shuffle_unsticks_board() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := _session(["11", "23", "32"], 10, {"type": "score", "target": 1000})
	s.tap(0, 0)
	assert_true(s.is_stuck())
	assert_true(s.shuffle(rng))
	assert_false(s.is_stuck())
	assert_eq(s.status, GameSession.Status.PLAYING)
	assert_eq(s.board.count_color(2), 2, "embaralhar não muda as cores, só a ordem")
	assert_false(s.shuffle(rng), "só embaralha se estiver travado")


func test_shuffle_impossible_loses() -> void:
	var s := _session(["11", "23"], 10, {"type": "score", "target": 1000})
	s.tap(0, 0)
	assert_true(s.is_stuck())
	assert_false(s.shuffle(RandomNumberGenerator.new()))
	assert_eq(s.status, GameSession.Status.LOST, "cores 2 e 3 sozinhas: sem saída")


func test_hammer_can_unstick_board() -> void:
	var s := _session(["1121", "3432"], 10, {"type": "score", "target": 1000})
	s.tap(0, 0)
	assert_true(s.is_stuck())
	s.use_hammer(1, 1)  # sem o 4, os dois 3 ficam lado a lado
	assert_false(s.is_stuck())


func test_end_bonus_pops_one_block_per_move_left() -> void:
	var rng := RandomNumberGenerator.new()
	var s := _session(["11", "23", "45"], 10, {"type": "score", "target": 40})
	s.tap(0, 0)
	assert_eq(s.status, GameSession.Status.WON)
	var stars := s.stars()
	var cells := s.play_end_bonus(rng)
	assert_eq(cells.size(), 4, "9 jogadas sobrando, mas só 4 blocos")
	assert_eq(s.board.count_blocks(), 0)
	assert_eq(s.end_bonus, 4 * GameSession.END_BONUS_POINTS)
	assert_eq(s.score, 40 + s.end_bonus)
	assert_eq(s.stars(), stars, "bônus não muda as estrelas")
	assert_eq(s.play_end_bonus(rng), [], "só uma vez")


func test_stars_by_moves_left() -> void:
	var s := _session(["11"], 10, {"type": "score", "target": 1000})
	s.status = GameSession.Status.WON
	s.moves_left = 4
	assert_eq(s.stars(), 3, "40% sobrando")
	s.moves_left = 3
	assert_eq(s.stars(), 2)
	s.moves_left = 2
	assert_eq(s.stars(), 2, "20% sobrando")
	s.moves_left = 1
	assert_eq(s.stars(), 1)
	s.moves_left = 0
	assert_eq(s.stars(), 1)
	s.status = GameSession.Status.LOST
	assert_eq(s.stars(), 0)


func test_add_moves_reopens_lost_session() -> void:
	var s := _session(["1122", "3344"], 1, {"type": "score", "target": 1000})
	s.tap(0, 0)
	assert_eq(s.status, GameSession.Status.LOST)
	s.add_moves(5)
	assert_eq(s.status, GameSession.Status.PLAYING)
	assert_eq(s.moves_left, 5)


func test_hammer_is_free_and_counts_for_goals() -> void:
	var s := _session(["11", "23"], 5, {"type": "color", "color": 2, "count": 1})
	var r := s.use_hammer(0, 1)
	assert_eq(r.power, "hammer")
	assert_eq(s.moves_left, 5, "poder não gasta jogada")
	assert_eq(s.score, 50)
	assert_eq(s.status, GameSession.Status.WON, "bloco destruído conta para a meta de cor")
	assert_true(s.use_hammer(1, 1).is_empty(), "partida encerrada")


func test_swap_is_free_and_can_create_a_group() -> void:
	var s := _session(["12", "21"], 5, {"type": "score", "target": 9999})
	assert_true(s.is_stuck(), "xadrez: sem jogadas")
	assert_true(s.use_swap(Vector2i(0, 0), Vector2i(1, 0)), "troca destrava o tabuleiro")
	assert_false(s.is_stuck())
	s = _session(["12", "13", "44"], 5, {"type": "score", "target": 9999})
	assert_true(s.use_swap(Vector2i(1, 0), Vector2i(1, 1)))
	assert_eq(s.board.to_rows(), ["13", "12", "44"])
	assert_eq(s.moves_left, 5)
	assert_false(s.use_swap(Vector2i(0, 0), Vector2i(0, 0)))


func test_colors_goal_needs_every_color() -> void:
	var s := _session(["1122", "1133", "4433"], 10, {"type": "colors", "targets": {"1": 4, "3": 2}})
	assert_eq(s.goal_target(), 6)
	s.tap(0, 0)
	assert_eq(s.goal_progress(), 4)
	assert_eq(s.status, GameSession.Status.PLAYING, "falta a cor 3")
	s.tap(2, 2)  # 4 blocos da cor 3: conta só 2 (o que a meta pede)
	assert_eq(s.goal_progress(), 6)
	assert_eq(s.status, GameSession.Status.WON)


func test_clear_goal() -> void:
	var s := _session(["112", "334"], 10, {"type": "clear", "max_left": 2})
	assert_eq(s.goal_target(), 4)
	s.tap(0, 0)
	assert_eq(s.status, GameSession.Status.PLAYING)
	s.tap(0, 1)
	assert_eq(s.board.count_blocks(), 2)
	assert_eq(s.status, GameSession.Status.WON, "sobraram 2 blocos")


func test_drop_goal_counts_gems() -> void:
	var s := _session(["G2", "12", "13"], 10, {"type": "drop", "count": 1})
	s.tap(0, 1)
	assert_eq(s.gems_collected, 1)
	assert_eq(s.status, GameSession.Status.WON)


func test_end_bonus_skips_gems_and_holes() -> void:
	var s := _session(["11", "Gx", "23"], 10, {"type": "score", "target": 40})
	s.tap(0, 0)
	var cells := s.play_end_bonus(RandomNumberGenerator.new())
	assert_eq(cells.size(), 2, "só os dois blocos coloridos")
	assert_eq(s.board.count_color(s.board.GEM), 1)


func test_stats_for_achievements() -> void:
	var s := _session(["1122", "1133"], 5, {"type": "score", "target": 200})
	s.tap(0, 0)
	var st := s.take_stats()
	assert_eq(st.get("blocks"), 4)
	assert_eq(st.get("best_group"), 4)
	assert_true(s.take_stats().is_empty(), "take_stats zera o acumulador")
	s.tap(0, 0)  # as colunas vazias fecharam: o 22 está na coluna 0
	st = s.take_stats()
	assert_eq(st.get("wins"), 1)
	assert_eq(st.get("wins_no_power"), 1)


func test_power_win_does_not_count_as_no_power() -> void:
	var s := _session(["11S2", "1132"], 5, {"type": "score", "target": 60})
	var r := s.use_hammer(2, 0)
	assert_eq(r.get("stones"), 1, "martelo quebrou uma pedra")
	s.tap(0, 0)
	var st := s.take_stats()
	assert_eq(st.get("powers"), 1)
	assert_eq(st.get("stones"), 1)
	assert_eq(st.get("wins"), 1)
	assert_false(st.has("wins_no_power"))


func test_shortfall_score() -> void:
	var s := _session(["1122", "3344"], 1, {"type": "score", "target": 100})
	s.tap(0, 0)
	var sf := s.shortfall()
	assert_eq(sf.parts, [{"icon": GameSession.NO_ICON, "missing": 60}])
	assert_true(is_equal_approx(sf.fraction, 0.4), "fez 40 de 100")


func test_shortfall_colors_lists_only_missing() -> void:
	var s := _session(["1122", "1133", "4433"], 1, {"type": "colors", "targets": {"1": 4, "3": 6}})
	s.tap(0, 0)  # 4 da cor 1: cumprida
	assert_eq(s.status, GameSession.Status.LOST)
	assert_eq(s.shortfall().parts, [{"icon": 3, "missing": 6}])


func test_shortfall_gems_and_clear() -> void:
	var s := _session(["G2", "12", "13"], 5, {"type": "drop", "count": 2})
	assert_eq(s.shortfall().parts, [{"icon": Board.GEM, "missing": 2}])
	var c := _session(["112", "334"], 5, {"type": "clear", "max_left": 2})
	c.tap(0, 0)
	assert_eq(c.shortfall().parts, [{"icon": GameSession.NO_ICON, "missing": 2}], "4 blocos, pode sobrar 2")
