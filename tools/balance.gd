## Simulador de dificuldade: joga cada fase de data/levels.json várias vezes
## com dois jogadores automáticos e mostra a taxa de vitória.
##   - guloso: toca sempre o maior grupo (da cor-alvo, se a meta for de cor)
##   - aleatório: toca qualquer grupo válido
## Uso: godot --headless --path . -s tools/balance.gd [-- N_PARTIDAS [arquivo.json]]
extends SceneTree

const LevelLoader = preload("res://scripts/level_loader.gd")
const GameSession = preload("res://scripts/game_session.gd")


func _initialize() -> void:
	var runs := 200
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		runs = int(args[0])
	var levels := LevelLoader.load_levels(args[1] if args.size() > 1 else LevelLoader.LEVELS_PATH)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	print("fase cores jog  meta              guloso  estrelas  aleatório  mediana(guloso)  3★ guloso")
	var star_dists := []  # por fase: quantas partidas terminaram com 0, 1, 2 e 3 estrelas
	for level in levels:
		var greedy_wins := 0
		var greedy_stars := 0
		var three_stars := 0
		var random_wins := 0
		var progress: Array[int] = []
		var dist := [0, 0, 0, 0]
		for i in runs:
			var s = _play(level, rng, true)
			progress.append(s.goal_progress())
			dist[s.stars()] += 1
			if s.status == GameSession.Status.WON:
				greedy_wins += 1
				greedy_stars += s.stars()
				if s.stars() == 3:
					three_stars += 1
			if _play(level, rng, false).status == GameSession.Status.WON:
				random_wins += 1
		progress.sort()
		var goal: Dictionary = level.goal
		var goal_text := "%d pts" % int(goal.target) if goal.type == "score" else "%d cor %d" % [int(goal.count), int(goal.color)]
		print("%4d %5d %4d  %-16s %5.0f%%  %8.1f  %8.0f%%  %8d  %8.0f%%" % [
			int(level.id), int(level.colors), int(level.moves), goal_text,
			100.0 * greedy_wins / runs, float(greedy_stars) / max(greedy_wins, 1),
			100.0 * random_wins / runs, progress[runs / 2], 100.0 * three_stars / runs])
		star_dists.append(dist)
	_print_gates(levels, star_dists, runs)
	quit()


## Para cada portão: estrelas esperadas nas fases anteriores para um jogador
## (guloso) que joga cada fase k vezes e fica com o melhor resultado.
## E[max de k] = soma, para s = 1..3, de 1 - (1 - P(estrelas >= s))^k
func _print_gates(levels: Array, star_dists: Array, runs: int) -> void:
	print("\nportão  exige   1 tentativa  3 tentativas  5 tentativas  (estrelas esperadas antes do portão)")
	for gi in levels.size():
		var required := int(levels[gi].get("stars_required", 0))
		if required == 0:
			continue
		var line := "%5d  %5d" % [gi + 1, required]
		for k in [1, 3, 5]:
			var expected := 0.0
			for li in gi:
				var d: Array = star_dists[li]
				for s in range(1, 4):
					var p_at_least := 0.0
					for t in range(s, 4):
						p_at_least += float(d[t]) / runs
					expected += 1.0 - pow(1.0 - p_at_least, k)
			line += "  %9.1f %s" % [expected, "ok " if expected >= required else "NÃO"]
		print(line)


func _play(level: Dictionary, rng: RandomNumberGenerator, greedy: bool):
	var s = LevelLoader.build_session(level, rng)
	var target_color := int(level.goal.get("color", -1)) if level.goal.type == "color" else -1
	while s.status == GameSession.Status.PLAYING:
		var groups: Array = s.board.all_groups()
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

