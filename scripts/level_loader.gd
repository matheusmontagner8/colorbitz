## Carrega as fases de data/levels.json e monta uma GameSession a partir delas.
extends RefCounted

const Board = preload("res://scripts/board.gd")
const GameSession = preload("res://scripts/game_session.gd")

const LEVELS_PATH := "res://data/levels.json"


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
	board.fill_random(colors, rng)
	# "bomb_group" opcional no levels.json; senão, depende do número de cores.
	board.bomb_group_size = int(level.get("bomb_group", Board.bomb_size_for_colors(colors)))
	var session = GameSession.new()
	session.setup(board, int(level.get("moves", 20)), level.get("goal", {"type": "score", "target": 500}))
	if level.has("stars"):
		session.star_thresholds = level["stars"]
	return session
