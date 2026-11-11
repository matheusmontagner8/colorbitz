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


func test_points_for() -> void:
	assert_eq(Board.points_for(2), 40)
	assert_eq(Board.points_for(5), 250)
