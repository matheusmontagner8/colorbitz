extends "res://tests/test_case.gd"

const Board = preload("res://scripts/board.gd")
const PowerTutorial = preload("res://scripts/ui/power_tutorial.gd")


func test_hammer_target_prefers_lonely_block_at_bottom() -> void:
	var b := Board.new()
	b.load_rows(["1123", "2244", "1133"])
	# Embaixo: 1,1 grupo; 3,3 grupo. Sozinhos: (2,0) e (3,0) no topo.
	assert_eq(PowerTutorial.hammer_target(b), Vector2i(2, 0))
	b.load_rows(["1122", "3344", "1123"])
	assert_eq(PowerTutorial.hammer_target(b), Vector2i(2, 2), "o mais baixo")


func test_hammer_target_without_lonely_blocks() -> void:
	var b := Board.new()
	b.load_rows(["11", "22"])
	assert_eq(PowerTutorial.hammer_target(b), Vector2i(0, 1), "qualquer bloco serve")


func test_swap_targets_make_a_group_and_restore_board() -> void:
	var b := Board.new()
	b.load_rows(["1213", "3434"])
	var before := b.to_rows()
	var pair := PowerTutorial.swap_targets(b)
	assert_eq(pair.size(), 2)
	assert_eq(b.to_rows(), before, "a busca não altera o tabuleiro")
	b.swap(pair[0], pair[1])
	assert_true(b.find_group(pair[0].x, pair[0].y).size() >= 2 or b.find_group(pair[1].x, pair[1].y).size() >= 2, "a troca forma grupo")


func test_swap_targets_empty_when_nothing_helps() -> void:
	var b := Board.new()
	b.load_rows(["11"])
	assert_eq(PowerTutorial.swap_targets(b), [])
