extends "res://tests/test_case.gd"

const Board = preload("res://scripts/board.gd")


func _board(rows: Array) -> Board:
	var b := Board.new()
	b.load_rows(rows)
	return b


func test_load_and_to_rows_roundtrip() -> void:
	var rows := ["01.", "234"]
	var b := _board(rows)
	assert_eq(b.width, 3)
	assert_eq(b.height, 2)
	assert_eq(b.to_rows(), rows)
	assert_eq(b.get_cell(2, 0), Board.EMPTY)
	assert_eq(b.get_cell(-1, 0), Board.EMPTY, "fora do tabuleiro é vazio")


func test_find_group_follows_only_orthogonal_neighbors() -> void:
	var b := _board([
		"110",
		"010",
		"101",
	])
	var group := b.find_group(0, 0)
	assert_eq(group.size(), 3, "L de 3 blocos (diagonais não contam)")
	assert_true(group.has(Vector2i(1, 1)))
	assert_false(group.has(Vector2i(0, 2)))


func test_find_group_on_empty_cell_is_empty() -> void:
	var b := _board([".1"])
	assert_eq(b.find_group(0, 0).size(), 0)


func test_tap_isolated_block_does_nothing() -> void:
	var b := _board(["01", "10"])
	var result := b.tap(0, 0)
	assert_true(result.is_empty())
	assert_eq(b.to_rows(), ["01", "10"], "tabuleiro não muda")


func test_tap_removes_group_and_scores_n_squared_times_10() -> void:
	var b := _board([
		"2..",
		"11.",
		".1.",
	])
	var result := b.tap(0, 1)
	assert_eq(result.color, 1)
	assert_eq(result.removed.size(), 3)
	assert_eq(result.points, 90)
	assert_eq(b.count_color(1), 0)


func test_gravity_drops_blocks() -> void:
	var b := _board([
		"2..",
		"11.",
		"01.",
	])
	var result := b.tap(0, 1)
	assert_eq(b.to_rows(), [
		"...",
		"2..",
		"0..",
	])
	assert_eq(result.moves, [{"from": Vector2i(0, 0), "to": Vector2i(0, 1)}])


func test_empty_columns_collapse_left() -> void:
	var b := _board([
		"1.2",
		"1.3",
	])
	var result := b.tap(0, 0)
	assert_eq(b.to_rows(), ["2..", "3.."])
	assert_eq(result.moves, [
		{"from": Vector2i(2, 1), "to": Vector2i(0, 1)},
		{"from": Vector2i(2, 0), "to": Vector2i(0, 0)},
	])


func test_columns_stay_when_collapse_disabled() -> void:
	var b := _board([
		"1.2",
		"1.3",
	])
	b.collapse_columns = false
	var result := b.tap(0, 0)
	assert_eq(b.to_rows(), ["..2", "..3"])
	assert_eq(result.moves, [])


func test_gravity_and_collapse_together() -> void:
	var b := _board([
		"3.4",
		"1.5",
		"1.5",
	])
	b.tap(0, 1)
	assert_eq(b.to_rows(), [
		".4.",
		".5.",
		"35.",
	])


func test_has_moves() -> void:
	assert_true(_board(["01", "02"]).has_moves(), "vertical")
	assert_true(_board(["00", "12"]).has_moves(), "horizontal")
	assert_false(_board(["01", "10"]).has_moves(), "xadrez")
	assert_false(_board(["..", ".."]).has_moves(), "vazio")


func test_fill_random_is_deterministic_and_playable() -> void:
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 42
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var a := Board.new(7, 9)
	var b := Board.new(7, 9)
	a.fill_random(5, rng1)
	b.fill_random(5, rng2)
	assert_eq(a.to_rows(), b.to_rows(), "mesma seed, mesmo tabuleiro")
	assert_eq(a.count_blocks(), 63)
	assert_true(a.has_moves())
	for y in a.height:
		for x in a.width:
			var c := a.get_cell(x, y)
			assert_true(c >= 0 and c < 5, "cor fora do intervalo em %d,%d" % [x, y])


func test_all_groups_and_best_group() -> void:
	var b := _board([
		"0012",
		"0332",
		"4.33",
	])
	var sizes := []
	for g in b.all_groups():
		sizes.append(g.size())
	sizes.sort()
	assert_eq(sizes, [2, 3, 4], "grupos 2 (cor 2), 3 (cor 0) e 4 (cor 3); isolados fora")
	assert_eq(b.best_group().size(), 4)
	assert_eq(_board(["01", "10"]).best_group(), [])


func test_group_of_8_leaves_bomb_where_tapped() -> void:
	var b := _board([
		"1111",
		"1111",
		"2323",
	])
	var r := b.tap(1, 1)
	assert_eq(r.size, 8)
	assert_eq(r.points, 640, "pontos contam o grupo inteiro")
	assert_eq(r.bomb, Vector2i(1, 1))
	assert_eq(r.removed.size(), 7, "o bloco tocado não some: vira bomba")
	assert_eq(r.removed_colors, {1: 8})
	assert_eq(b.to_rows(), [
		"....",
		".B..",
		"2323",
	], "a bomba fica onde o bloco foi tocado e cai com a gravidade")


func test_bomb_falls_with_gravity() -> void:
	var b := _board([
		"11112",
		"11112",
		"23232",
	])
	b.tap(0, 0)
	assert_eq(b.to_rows(), [
		"....2",
		"B...2",
		"23232",
	])


func test_group_of_7_does_not_make_bomb() -> void:
	var b := _board(["1111", "1112"])
	var r := b.tap(0, 0)
	assert_eq(r.bomb, null)
	assert_eq(b.count_color(Board.BOMB), 0)


func test_bomb_group_size_is_configurable() -> void:
	var b := _board(["111111", "234523"])
	b.bomb_group_size = 6
	assert_true(b.tap(0, 0).bomb != null, "com limite 6, um grupo de 6 vira bomba")


func test_bomb_destroys_3x3_area() -> void:
	var b := _board([
		"01234",
		"12B40",
		"23401",
		"34012",
	])
	var r := b.tap(2, 1)
	assert_eq(r.color, Board.BOMB)
	assert_eq(r.size, 8, "8 blocos coloridos em volta")
	assert_eq(r.points, 8 * Board.BOMB_POINTS_PER_BLOCK)
	assert_eq(r.removed.size(), 9, "8 blocos + a própria bomba")
	assert_eq(r.removed_colors, {0: 1, 1: 1, 2: 2, 3: 2, 4: 2})
	assert_eq(r.exploded, [Vector2i(2, 1)])
	assert_eq(b.to_rows(), [
		"0...4",
		"1...0",
		"2...1",
		"34012",
	], "colunas 0 e 4 intactas; nas do meio, só a linha de baixo sobra")


func test_bomb_at_corner_only_hits_inside_board() -> void:
	var b := _board(["B1", "23"])
	var r := b.tap(0, 0)
	assert_eq(r.size, 3)
	assert_eq(b.count_blocks(), 0)


func test_bomb_chain_reaction() -> void:
	var rows := [
		"B1111",
		"2B222",
		"33333",
	]
	var b := _board(rows)
	var r := b.tap(0, 0)
	assert_eq(r.exploded.size(), 2, "a primeira bomba detona a segunda (na diagonal)")
	assert_eq(b.to_rows(), ["11...", "22...", "33..."], "a segunda alcança as colunas 0 a 2")
	assert_eq(r.removed_colors, {1: 2, 2: 2, 3: 3})
	b = _board(rows)
	b.set_cell(1, 1, 2)  # sem a segunda bomba, a área é só 2x2
	b.tap(0, 0)
	assert_eq(b.count_blocks(), 11)


func test_bombs_count_as_moves_but_not_as_groups() -> void:
	var b := _board(["B1", "23"])
	assert_true(b.has_moves(), "uma bomba sempre pode ser tocada")
	assert_eq(b.all_groups(), [])
	var two := _board(["BB", "12"])
	assert_eq(two.all_groups(), [], "duas bombas juntas não formam grupo")
	assert_eq(two.bombs(), [Vector2i(0, 0), Vector2i(1, 0)])


func test_points_for() -> void:
	assert_eq(Board.points_for(2), 40)
	assert_eq(Board.points_for(5), 250)


func test_smash_removes_single_block_and_applies_gravity() -> void:
	var b := _board([
		"2.",
		"1.",
		"03",
	])
	var r := b.smash(0, 1)
	assert_eq(r.size, 1)
	assert_eq(r.removed, [Vector2i(0, 1)])
	assert_eq(r.removed_colors, {1: 1})
	assert_eq(r.points, Board.BOMB_POINTS_PER_BLOCK)
	assert_eq(b.to_rows(), ["..", "2.", "03"], "o bloco de cima cai")
	assert_true(b.smash(1, 0).is_empty(), "célula vazia não faz nada")


func test_smash_on_bomb_explodes_it() -> void:
	var b := _board(["B1", "23"])
	var r := b.smash(0, 0)
	assert_eq(r.color, Board.BOMB)
	assert_eq(b.count_blocks(), 0)


func test_swap_exchanges_two_blocks() -> void:
	var b := _board(["12.", "B34"])
	assert_true(b.swap(Vector2i(0, 0), Vector2i(2, 1)))
	assert_eq(b.to_rows(), ["42.", "B31"])
	assert_true(b.swap(Vector2i(0, 1), Vector2i(1, 1)), "bombas também trocam")
	assert_eq(b.to_rows(), ["42.", "3B1"])
	assert_false(b.swap(Vector2i(0, 0), Vector2i(2, 0)), "não troca com vazio")
	assert_false(b.swap(Vector2i(1, 0), Vector2i(1, 0)), "nem consigo mesmo")
	assert_false(b.swap(Vector2i(0, 0), Vector2i(5, 5)), "nem fora do tabuleiro")
	assert_eq(b.to_rows(), ["42.", "3B1"])


func test_shuffle_keeps_colors_and_creates_a_move() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in 50:
		rng.seed = seed
		var b := _board([
			"0123.",
			"1230.",
			"2301.",
		])
		assert_false(b.has_moves())
		assert_true(b.shuffle(rng), "seed %d" % seed)
		assert_true(b.has_moves(), "seed %d" % seed)
		for c in 4:
			assert_eq(b.count_color(c), 3, "seed %d: cor %d" % [seed, c])
		assert_eq(b.get_cell(4, 0), Board.EMPTY, "vazios continuam vazios")


func test_shuffle_forces_pair_when_luck_fails() -> void:
	# Só 2 blocos da cor 0 entre 8: o embaralhamento aleatório raramente acerta.
	var rng := RandomNumberGenerator.new()
	for seed in 30:
		rng.seed = seed
		var b := _board(["01234", "56701"])
		assert_true(b.shuffle(rng) and b.has_moves(), "seed %d" % seed)


func test_shuffle_impossible() -> void:
	var b := _board(["01", "23"])
	assert_false(b.shuffle(RandomNumberGenerator.new()))
	assert_eq(b.to_rows(), ["01", "23"], "nada muda")


# --- Especiais: pedra, coringa, gelo, joia e buracos ---------------------------

func test_stone_is_not_tappable_and_falls() -> void:
	var b := _board(["S", "1", "1"])
	assert_true(b.tap(0, 0).is_empty(), "pedra não estoura")
	assert_false(_board(["S1", "S2"]).has_moves(), "pedras não formam grupo")
	var r := b.tap(0, 1)
	assert_eq(r.removed_colors, {1: 2})
	assert_eq(b.to_rows(), [".", ".", "S"], "pedra cai com a gravidade")


func test_bomb_and_hammer_break_stones() -> void:
	var b := _board(["SBS", "111"])
	var r := b.tap(1, 0)
	assert_eq(r.size, 5, "2 pedras + 3 blocos")
	assert_eq(r.removed_colors, {1: 3}, "pedra não conta como cor")
	var h := _board(["S1", "21"])
	var hr := h.smash(0, 0)
	assert_eq(hr.removed_colors, {})
	assert_eq(h.count_blocks(), 3)


func test_wild_joins_any_color() -> void:
	var b := _board(["1W1", "234"])
	var r := b.tap(0, 0)
	assert_eq(r.size, 3, "o coringa liga os dois 1")
	assert_eq(r.removed_colors, {1: 3}, "coringa conta como a cor do grupo")
	assert_true(_board(["1W", "23"]).has_moves(), "cor + coringa é jogada")
	assert_true(_board(["WW", "1."]).has_moves())


func test_tapping_wild_picks_biggest_neighbor_color() -> void:
	var b := _board(["1W22", "3456"])
	var r := b.tap(1, 0)
	assert_eq(r.color, 2)
	assert_eq(r.size, 3)
	assert_eq(b.to_rows(), ["1...", "3456"])
	assert_true(_board(["WW", "12"]).find_group(0, 0).size() == 3, "W W + o 1 de baixo")
	assert_eq(_board(["W", "3"]).tap(0, 0).size, 2)
	assert_true(_board(["WW"]).tap(0, 0).is_empty(), "só coringas não formam grupo")


func test_ice_blocks_until_cracked() -> void:
	var b := _board(["11", "22"])
	b.set_ice(0, 1, 1)
	assert_true(b.tap(0, 1).is_empty(), "bloco congelado não pode ser tocado")
	assert_eq(b.find_group(1, 1).size(), 1, "nem entra em grupo")
	var r := b.tap(0, 0)
	assert_eq(r.iced, [Vector2i(0, 1)], "o estouro ao lado racha o gelo")
	assert_false(b.is_frozen(0, 1))
	assert_eq(b.find_group(1, 1).size(), 2, "solto, volta a formar grupo")


func test_strong_ice_needs_two_hits_and_falls_with_block() -> void:
	var b := _board(["2", "1", "1"])
	b.set_ice(0, 0, 2)
	b.tap(0, 1)
	assert_eq(b.to_rows(), [".", ".", "2"])
	assert_eq(b.get_ice(0, 2), 1, "o gelo cai junto com o bloco")
	assert_eq(b.get_ice(0, 0), 0)


func test_bomb_destroys_frozen_blocks() -> void:
	var b := _board(["B2", "33"])
	b.set_ice(1, 0, 2)
	var r := b.tap(0, 0)
	assert_eq(r.removed_colors, {2: 1, 3: 2})
	assert_eq(b.count_blocks(), 0)
	assert_eq(b.get_ice(1, 0), 0)


func test_gem_is_collected_at_the_bottom() -> void:
	var b := _board(["G2", "12", "13"])
	assert_true(b.tap(0, 0).is_empty(), "joia não estoura")
	var r := b.tap(0, 1)
	assert_eq(r.gems, [{"from": Vector2i(0, 0), "to": Vector2i(0, 2)}])
	assert_eq(r.points, Board.points_for(2) + Board.GEM_POINTS)
	assert_eq(b.to_rows(), ["2.", "2.", "3."], "joia sai e a coluna vazia fecha")
	assert_eq(r.moves, [{"from": Vector2i(1, 2), "to": Vector2i(0, 2)}, {"from": Vector2i(1, 1), "to": Vector2i(0, 1)}, {"from": Vector2i(1, 0), "to": Vector2i(0, 0)}])


func test_bomb_and_hammer_spare_gems() -> void:
	var b := _board(["GB", "11"])
	var r := b.tap(1, 0)
	assert_eq(r.gems.size(), 1, "explosão abre caminho e a joia chega ao fundo")
	assert_eq(b.count_blocks(), 0)
	assert_true(_board(["G1", "21"]).smash(0, 0).is_empty(), "martelo não quebra joia")
	assert_false(_board(["G1", "21"]).swap(Vector2i(0, 0), Vector2i(1, 0)), "troca não move joia")


func test_holes_are_skipped_by_gravity() -> void:
	var b := _board(["2", "x", "1", "1"])
	var r := b.tap(0, 2)
	assert_eq(b.to_rows(), [".", "x", ".", "2"], "o bloco atravessa o buraco")
	assert_eq(r.moves, [{"from": Vector2i(0, 0), "to": Vector2i(0, 3)}])
	assert_true(b.tap(0, 1).is_empty())


func test_apply_mask_and_fill() -> void:
	var b := Board.new(3, 3)
	b.apply_mask(["#.#", "###", "#.#"])
	assert_false(b.collapse_columns, "buracos desligam o fechamento de colunas")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	b.fill_random(3, rng)
	assert_eq(b.get_cell(1, 0), Board.HOLE)
	assert_eq(b.count_blocks(), 7, "buraco não conta como bloco")


func test_place_specials() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in 20:
		rng.seed = seed
		var b := Board.new(7, 9)
		b.fill_random(5, rng)
		b.place_specials({"gems": 2, "stones": 3, "wilds": 2, "ice": 4, "ice_hits": 2}, rng)
		assert_eq(b.count_color(Board.GEM), 2)
		assert_eq(b.count_color(Board.STONE), 3)
		assert_eq(b.count_color(Board.WILD), 2)
		var frozen := 0
		for y in 9:
			for x in 7:
				if b.get_cell(x, y) == Board.GEM:
					assert_eq(y, 9 - 1 - Board.GEM_START_DEPTH, "joia começa no meio da coluna")
				if b.get_cell(x, y) == Board.STONE:
					assert_true(y >= 2, "pedra longe do topo")
				if b.is_frozen(x, y):
					frozen += 1
					assert_eq(b.get_ice(x, y), 2)
					assert_true(Board.is_color(b.get_cell(x, y)), "gelo só em bloco colorido")
		assert_eq(frozen, 4)
		assert_true(b.has_moves(), "seed %d" % seed)


func test_swap_carries_ice_and_shuffle_keeps_specials() -> void:
	var b := _board(["1S", "23"])
	b.set_ice(0, 0, 1)
	assert_true(b.swap(Vector2i(0, 0), Vector2i(1, 1)))
	assert_eq(b.get_ice(1, 1), 1)
	assert_eq(b.get_ice(0, 0), 0)
	var s := _board(["0S12", "3W45", "6789"])
	s.set_ice(3, 2, 1)
	assert_true(s.shuffle(RandomNumberGenerator.new()), "coringa no meio sempre gera jogada")
	assert_eq(s.get_cell(1, 0), Board.STONE)
	assert_eq(s.get_cell(1, 1), Board.WILD)
	assert_eq(s.get_cell(3, 2), 9, "congelado fica no lugar")
