extends "res://tests/test_case.gd"

const LevelLoader = preload("res://scripts/level_loader.gd")
const GameSession = preload("res://scripts/game_session.gd")


func test_levels_file_is_valid() -> void:
	var levels := LevelLoader.load_levels()
	assert_true(levels.size() > 0, "levels.json deve ter fases")
	for name in LevelLoader.SHAPES:
		var shape: Array = LevelLoader.SHAPES[name]
		assert_eq(shape.size(), 9, "formato %s: 9 linhas" % name)
		for row in shape:
			assert_eq(String(row).length(), 7, "formato %s: 7 colunas" % name)
	for level in levels:
		var id := str(level.get("id", "?"))
		for key in ["id", "width", "height", "colors", "moves", "goal"]:
			assert_true(level.has(key), "fase %s sem '%s'" % [id, key])
		var colors := int(level.get("colors", 0))
		assert_true(colors >= 2 and colors <= 6, "fase %s: cores entre 2 e 6" % id)
		var goal: Dictionary = level.get("goal", {})
		assert_true(goal.get("type") in ["score", "color", "colors", "clear", "drop"], "fase %s: tipo de meta" % id)
		if goal.get("type") == "color":
			assert_true(int(goal.get("color", -1)) < colors, "fase %s: cor da meta existe" % id)
		if goal.get("type") == "colors":
			for c in goal.get("targets", {}):
				assert_true(int(c) < colors, "fase %s: cor %s da meta existe" % [id, c])
		if goal.get("type") == "drop":
			assert_true(int(level.get("gems", 0)) >= int(goal.get("count", 0)), "fase %s: joias suficientes" % id)
		if level.get("mask") is String:
			assert_true(LevelLoader.SHAPES.has(level.mask), "fase %s: formato %s existe" % [id, level.mask])


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


func test_build_session_with_specials_and_shape() -> void:
	var level := {"width": 7, "height": 9, "colors": 5, "moves": 10, "seed": 4, "mask": "ampulheta",
		"stones": 2, "ice": 3, "ice_hits": 2, "wilds": 1, "gems": 2, "goal": {"type": "drop", "count": 2}}
	var s = LevelLoader.build_session(level)
	var b = s.board
	assert_eq(b.get_cell(0, 3), b.HOLE, "formato ampulheta")
	assert_false(b.collapse_columns)
	assert_eq(b.count_color(b.STONE), 2)
	assert_eq(b.count_color(b.GEM), 2)
	assert_eq(b.count_color(b.WILD), 1)
	assert_true(b.has_moves())
	assert_eq(s.initial_blocks, 63 - 16, "16 buracos na ampulheta")


## Não caem blocos novos: o tabuleiro tem que começar com blocos suficientes
## da(s) cor(es) pedida(s), senão a fase seria impossível.
func test_color_goals_always_have_enough_blocks() -> void:
	var levels: Array = LevelLoader.load_levels()
	for t in preload("res://scripts/daily.gd").TEMPLATES:
		levels.append(t)
	var rng := RandomNumberGenerator.new()
	for level in levels:
		var minimums := LevelLoader.color_minimums(level.goal)
		if minimums.is_empty():
			continue
		for i in 150:
			rng.seed = i
			var s = LevelLoader.build_session(level, rng)
			for c in minimums:
				assert_true(s.board.count_color(c) >= minimums[c],
					"fase %s semente %d: cor %d tem %d de %d" % [level.get("id", level.get("name")), i, c, s.board.count_color(c), minimums[c]])
			assert_true(s.board.has_moves(), "fase %s semente %d sem jogadas" % [level.get("id", level.get("name")), i])


## Modo infinito: fases geradas válidas, iguais para o mesmo número e jogáveis.
func test_endless_levels() -> void:
	var Endless = preload("res://scripts/endless.gd")
	assert_eq(Endless.level_for(75), Endless.level_for(75), "mesmo número, mesma fase")
	var kinds := {}
	for n in range(61, 400):
		var level: Dictionary = Endless.level_for(n)
		assert_eq(int(level.id), n)
		assert_true(int(level["moves"]) >= 10, "fase %d com jogadas" % n)
		kinds[level["goal"]["type"]] = true
		var s = LevelLoader.build_session(level)
		assert_true(s.board.has_moves(), "fase %d jogável" % n)
		assert_true(s.goal_target() > 0, "fase %d com meta" % n)
		if n > 61:
			assert_true(Endless.level_for(n - 1)["goal"] != level["goal"] or Endless.level_for(n - 1).get("mask") != level.get("mask"), "fase %d diferente da anterior" % n)
	assert_eq(kinds.size(), 5, "usa os tipos de meta (score, color, colors, clear, drop)")
	assert_eq(Endless.difficulty(61), 0.0)
	assert_eq(Endless.difficulty(5000), 1.0, "a dificuldade tem teto")


## "MODO INFINITO": uma letra a cada fase múltipla de 5 até a 60.
func test_endless_letters() -> void:
	var Endless = preload("res://scripts/endless.gd")
	var Progress = preload("res://scripts/progress.gd")
	var givers := []
	for n in range(1, 80):
		if Endless.gives_letter(n):
			givers.append(n)
	assert_eq(givers, [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60])
	assert_eq("MODO INFINITO".replace(" ", "").length(), Endless.LETTER_COUNT)
	var p = Progress.new()
	assert_eq(Endless.letters_revealed(p), 0)
	for n in range(1, 13):
		p.record_result(n, 1)
	assert_eq(Endless.letters_revealed(p), 2, "fases 5 e 10")
	for n in range(13, 61):
		p.record_result(n, 1)
	assert_eq(Endless.letters_revealed(p), 12, "palavra completa com a fase 60")
	p.record_result(65, 3)
	assert_eq(Endless.letters_revealed(p), 12, "o modo infinito não dá letras")
