extends "res://tests/test_case.gd"

const LevelLoader = preload("res://scripts/level_loader.gd")
const GameSession = preload("res://scripts/game_session.gd")


func test_levels_file_is_valid() -> void:
	var levels := LevelLoader.load_levels()
	assert_true(levels.size() > 0, "levels.json deve ter fases")
	for level in levels:
		var id := str(level.get("id", "?"))
		for key in ["id", "width", "height", "colors", "moves", "goal"]:
			assert_true(level.has(key), "fase %s sem '%s'" % [id, key])
		var colors := int(level.get("colors", 0))
		assert_true(colors >= 2 and colors <= 6, "fase %s: cores entre 2 e 6" % id)
		var goal: Dictionary = level.get("goal", {})
		assert_true(goal.get("type") in ["score", "color"], "fase %s: tipo de meta" % id)
		if goal.get("type") == "color":
			assert_true(int(goal.get("color", -1)) < colors, "fase %s: cor da meta existe" % id)


func test_star_gates_are_reachable_and_increasing() -> void:
	var levels := LevelLoader.load_levels()
	var last_required := 0
	for i in levels.size():
		var required := int(levels[i].get("stars_required", 0))
		if required == 0:
			continue
		assert_true(required <= i * 3, "fase %d exige %d estrelas, mas só há %d possíveis antes dela" % [i + 1, required, i * 3])
		assert_true(required > last_required, "fase %d: portões devem exigir cada vez mais estrelas" % (i + 1))
		last_required = required


func test_bomb_size_depends_on_colors() -> void:
	var base := {"width": 7, "height": 9, "moves": 10, "seed": 1, "goal": {"type": "score", "target": 100}}
	var expected := {3: 8, 4: 8, 5: 7, 6: 6}
	for colors in expected:
		var level := base.duplicate()
		level["colors"] = colors
		assert_eq(LevelLoader.build_session(level).board.bomb_group_size, expected[colors], "%d cores" % colors)
	var custom := base.duplicate()
	custom["colors"] = 6
	custom["bomb_group"] = 10
	assert_eq(LevelLoader.build_session(custom).board.bomb_group_size, 10, "bomb_group no JSON tem prioridade")


func test_ids_are_unique_and_sequential() -> void:
	var levels := LevelLoader.load_levels()
	for i in levels.size():
		assert_eq(int(levels[i].get("id", 0)), i + 1, "id da fase na posição %d" % i)


func test_build_session_from_level() -> void:
	var level := {"width": 5, "height": 6, "colors": 3, "moves": 7, "seed": 1,
		"goal": {"type": "score", "target": 100}}
	var s = LevelLoader.build_session(level)
	assert_eq(s.board.width, 5)
	assert_eq(s.board.height, 6)
	assert_eq(s.moves_left, 7)
	assert_eq(s.status, GameSession.Status.PLAYING)
	var again = LevelLoader.build_session(level)
	assert_eq(s.board.to_rows(), again.board.to_rows(), "seed gera o mesmo tabuleiro")
