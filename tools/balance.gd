## Simulador de dificuldade: joga cada fase de data/levels.json várias vezes
## com dois jogadores automáticos e mostra a taxa de vitória.
##   - guloso: toca sempre o maior grupo (da cor-alvo, se a meta for de cor)
##   - aleatório: toca qualquer grupo válido
## Uso: godot --headless --path . -s tools/balance.gd [-- N_PARTIDAS]
extends SceneTree

const LevelLoader = preload("res://scripts/level_loader.gd")
const GameSession = preload("res://scripts/game_session.gd")


func _initialize() -> void:
	var runs := 200
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		runs = int(args[0])
	var levels := LevelLoader.load_levels()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	print("fase cores jog  meta              guloso  estrelas  aleatório  mediana(guloso)")
	for level in levels:
		var greedy_wins := 0
		var greedy_stars := 0
		var random_wins := 0
		var progress: Array[int] = []
		for i in runs:
			var s = _play(level, rng, true)
			progress.append(s.goal_progress())
			if s.status == GameSession.Status.WON:
				greedy_wins += 1
				greedy_stars += s.stars()
			if _play(level, rng, false).status == GameSession.Status.WON:
				random_wins += 1
		progress.sort()
		var goal: Dictionary = level.goal
		var goal_text := "%d pts" % int(goal.target) if goal.type == "score" else "%d cor %d" % [int(goal.count), int(goal.color)]
		print("%4d %5d %4d  %-16s %5.0f%%  %8.1f  %8.0f%%  %8d" % [
			int(level.id), int(level.colors), int(level.moves), goal_text,
			100.0 * greedy_wins / runs, float(greedy_stars) / max(greedy_wins, 1),
			100.0 * random_wins / runs, progress[runs / 2]])
	quit()


func _play(level: Dictionary, rng: RandomNumberGenerator, greedy: bool):
	var s = LevelLoader.build_session(level, rng)
	var target_color := int(level.goal.get("color", -1)) if level.goal.type == "color" else -1
	while s.status == GameSession.Status.PLAYING:
		var groups := _groups(s.board)
		var pick: Array
		if greedy:
			pick = groups[0]
			for g in groups:
				if _value(g, s.board, target_color) > _value(pick, s.board, target_color):
					pick = g
		else:
			pick = groups[rng.randi_range(0, groups.size() - 1)]
		s.tap(pick[0].x, pick[0].y)
	return s


func _value(group: Array, board, target_color: int) -> int:
	var bonus := 1000 if target_color >= 0 and board.get_cell(group[0].x, group[0].y) == target_color else 0
	return group.size() + bonus


## Lista todos os grupos válidos (2+ blocos) do tabuleiro.
func _groups(board) -> Array:
	var seen := {}
	var groups := []
	for y in board.height:
		for x in board.width:
			var p := Vector2i(x, y)
			if seen.has(p) or board.get_cell(x, y) < 0:
				continue
			var g: Array = board.find_group(x, y)
			for q in g:
				seen[q] = true
			if g.size() >= 2:
				groups.append(g)
	return groups
