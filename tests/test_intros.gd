extends "res://tests/test_case.gd"

const Intros = preload("res://scripts/intros.gd")
const Board = preload("res://scripts/board.gd")
const LevelLoader = preload("res://scripts/level_loader.gd")
const Progress = preload("res://scripts/progress.gd")


func _board(rows: Array):
	var b := Board.new()
	b.load_rows(rows)
	return b


func test_cards_are_complete() -> void:
	for id in Intros.CARDS:
		var c: Dictionary = Intros.CARDS[id]
		assert_true(c.title != "" and c.text != "" and not c.icon.is_empty(), "cartão %s" % id)
		assert_true(id in Intros.ORDER or id == "bomb", "%s está na ordem" % id)
		for line in String(c.text).split("\n"):
			assert_true(line.length() <= 40, "linha longa demais no cartão %s: %s" % [id, line])


func test_concepts_from_goal_and_board() -> void:
	var b = _board(["1W2S", "1122"])
	b.set_ice(3, 1, 2)
	var level := {"goal": {"type": "color", "color": 1, "count": 5}}
	assert_eq(Intros.concepts_for(level, b), ["goal_color", "stone", "wild", "ice2"])
	assert_eq(Intros.concepts_for({}, _board(["11"])), ["goal_score"], "sem meta = pontos")
	assert_eq(Intros.concepts_for({"goal": {"type": "drop"}, "endless": true}, _board(["1x"]), true),
		["daily", "endless", "endless_goals", "goal_drop", "holes"])
	assert_eq(Intros.concepts_for({"goal": {"type": "score"}, "endless": true, "boss": true}, _board(["11"])),
		["endless", "endless_goals", "boss", "goal_score"], "fase chefe")


func test_each_card_only_once() -> void:
	var p := Progress.new()
	var ids := ["goal_score", "wild"]
	assert_eq(Intros.unseen(ids, p), ids)
	Intros.mark_seen("wild", p)
	assert_eq(Intros.unseen(ids, p), ["goal_score"])
	var q := Progress.new()
	q.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_eq(Intros.unseen(ids, q), ["goal_score"], "fica salvo")


## Jogando a campanha em ordem, cada novidade aparece na fase em que estreia.
func test_campaign_introduces_everything() -> void:
	var p := Progress.new()
	var first := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for level in LevelLoader.load_levels():
		var s = LevelLoader.build_session(level, rng)
		for id in Intros.unseen(Intros.concepts_for(level, s.board), p):
			first[id] = int(level.id)
			Intros.mark_seen(id, p)
	assert_eq(first.get("goal_score"), 1)
	assert_eq(first.get("goal_color"), 3, "primeira meta de cor")
	assert_eq(first.get("stone"), 13)
	assert_eq(first.get("wild"), 16, "primeiro coringa")
	assert_eq(first.get("ice"), 23)
	assert_eq(first.get("goal_drop"), 26, "primeira fase com joias")
	assert_eq(first.get("goal_colors"), 32)
	assert_eq(first.get("holes"), 33)
	assert_eq(first.get("goal_clear"), 36)
	assert_eq(first.get("ice2"), 38)
