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


func test_lose_when_no_groups_left() -> void:
	var s := _session(["112", "343"], 10, {"type": "score", "target": 1000})
	s.tap(0, 0)
	assert_false(s.board.has_moves())
	assert_eq(s.status, GameSession.Status.LOST)
	assert_eq(s.moves_left, 9)


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
