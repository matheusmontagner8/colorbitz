## Carrega as fases de data/levels.json e monta uma GameSession a partir delas.
extends RefCounted

const Board = preload("res://scripts/board.gd")
const GameSession = preload("res://scripts/game_session.gd")

const LEVELS_PATH := "res://data/levels.json"
## Formatos de tabuleiro 7x9 usados em "mask" (pelo nome). "#" célula, "." buraco.
const SHAPES := {
	"ampulheta": ["#######", "#######", ".#####.", "..###..", "..###..", "..###..", ".#####.", "#######", "#######"],
	"pilares": ["#######", "#######", "#######", "#######", "#.#.#.#", "#.#.#.#", "#######", "#######", "#######"],
	"cantos": ["..###..", ".#####.", "#######", "#######", "#######", "#######", "#######", ".#####.", "..###.."],
	"janela": ["#######", "#######", "##...##", "##...##", "#######", "#######", "##...##", "##...##", "#######"],
}
## Chaves do levels.json com os especiais da fase (veja Board.place_specials).
const SPECIAL_KEYS := ["gems", "stones", "wilds", "ice", "ice_hits"]
## Metas de cor: blocos a mais que a meta, garantidos no tabuleiro (para
## compensar blocos que fiquem isolados).
const COLOR_GOAL_MARGIN := 2


static func load_levels(path: String = LEVELS_PATH) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Não foi possível abrir %s" % path)
		return []
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("levels"):
		push_error("Formato inválido em %s" % path)
		return []
	return data["levels"]


## Quantos blocos de cada cor o tabuleiro precisa ter para a meta ser possível:
## {cor: meta + COLOR_GOAL_MARGIN} nas metas "color" e "colors"; {} nas outras.
static func color_minimums(goal: Dictionary) -> Dictionary:
	match String(goal.get("type", "")):
		"color":
			return {int(goal.color): int(goal.count) + COLOR_GOAL_MARGIN}
		"colors":
			var result := {}
			for c in goal.targets:
				result[int(c)] = int(goal.targets[c]) + COLOR_GOAL_MARGIN
			return result
	return {}


## Cria a sessão da fase. Se a fase tiver "seed", o tabuleiro é sempre o mesmo.
static func build_session(level: Dictionary, rng: RandomNumberGenerator = null):
	if rng == null:
		rng = RandomNumberGenerator.new()
		if level.has("seed"):
			rng.seed = int(level["seed"])
		else:
			rng.randomize()
	var board = Board.new(int(level.get("width", 7)), int(level.get("height", 9)))
	var colors := int(level.get("colors", 4))
	var mask = level.get("mask")
	if mask is String:
		mask = SHAPES.get(mask)
	if mask is Array:
		board.apply_mask(mask)
	board.fill_random(colors, rng)
	var spec := {}
	for key in SPECIAL_KEYS:
		if level.has(key):
			spec[key] = int(level[key])
	if not spec.is_empty():
		board.place_specials(spec, rng)
	var minimums := color_minimums(level.get("goal", {}))
	if not minimums.is_empty():
		board.ensure_colors(minimums, rng)
	# "bomb_group" opcional no levels.json; senão, depende do número de cores.
	board.bomb_group_size = int(level.get("bomb_group", Board.bomb_size_for_colors(colors)))
	var session = GameSession.new()
	session.setup(board, int(level.get("moves", 20)), level.get("goal", {"type": "score", "target": 500}))
	if level.has("stars"):
		session.star_thresholds = level["stars"]
	return session
