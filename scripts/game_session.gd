## Estado de uma partida (uma fase): pontuação, jogadas, meta e estrelas.
## Também é lógica pura, sem interface.
extends RefCounted

enum Status { PLAYING, WON, LOST }

## Fração de jogadas que sobram para ganhar 2 e 3 estrelas.
const DEFAULT_STAR_THRESHOLDS := [0.20, 0.40]
## Bônus de fim de fase: cada jogada que sobrou estoura um bloco e vale isto.
const END_BONUS_POINTS := 100

var board  # board.gd
var score := 0
var max_moves := 0
var moves_left := 0
## {"type": "score", "target": int} ou {"type": "color", "color": int, "count": int}
var goal: Dictionary = {}
var removed_by_color: Dictionary = {}
var status: Status = Status.PLAYING
var star_thresholds: Array = DEFAULT_STAR_THRESHOLDS.duplicate()
## Pontos ganhos no bônus de fim de fase (já somados em score).
var end_bonus := 0


func setup(p_board, p_max_moves: int, p_goal: Dictionary) -> void:
	board = p_board
	max_moves = p_max_moves
	moves_left = p_max_moves
	goal = p_goal
	score = 0
	removed_by_color = {}
	end_bonus = 0
	status = Status.PLAYING
	_update_status()


## Toque do jogador. Toques inválidos retornam {} e não gastam jogada.
## Toques válidos retornam o resultado de board.tap() com "status" adicionado.
func tap(x: int, y: int) -> Dictionary:
	if status != Status.PLAYING:
		return {}
	var result: Dictionary = board.tap(x, y)
	if result.is_empty():
		return result
	moves_left -= 1
	return _apply(result)


## Poder "Martelo": destrói um bloco. Não gasta jogada.
func use_hammer(x: int, y: int) -> Dictionary:
	if status != Status.PLAYING:
		return {}
	var result: Dictionary = board.smash(x, y)
	if result.is_empty():
		return result
	result["power"] = "hammer"
	return _apply(result)


## Poder "Troca": troca dois blocos de lugar. Não gasta jogada.
func use_swap(a: Vector2i, b: Vector2i) -> bool:
	if status != Status.PLAYING or not board.swap(a, b):
		return false
	_update_status()
	return true


func _apply(result: Dictionary) -> Dictionary:
	score += int(result.points)
	var colors: Dictionary = result.removed_colors
	for color in colors:
		removed_by_color[int(color)] = int(removed_by_color.get(int(color), 0)) + int(colors[color])
	_update_status()
	result["status"] = status
	return result


func goal_type() -> String:
	return String(goal.get("type", "score"))


## Valor atual em direção à meta (pontos ou blocos removidos da cor-alvo).
func goal_progress() -> int:
	if goal_type() == "color":
		return int(removed_by_color.get(int(goal.get("color", 0)), 0))
	return score


func goal_target() -> int:
	if goal_type() == "color":
		return int(goal.get("count", 0))
	return int(goal.get("target", 0))


func is_goal_met() -> bool:
	return goal_progress() >= goal_target()


## Estrelas conforme jogadas que sobraram (0 se não venceu).
func stars() -> int:
	if status != Status.WON:
		return 0
	var frac := float(moves_left) / float(max(max_moves, 1))
	if frac >= float(star_thresholds[1]):
		return 3
	if frac >= float(star_thresholds[0]):
		return 2
	return 1


## Sem nenhum grupo nem bomba, mas ainda com jogadas: a partida NÃO acaba
## (decisão de design). A interface deixa o jogador usar um poder ou chama
## [method shuffle].
func is_stuck() -> bool:
	return status == Status.PLAYING and not board.has_moves()


## Embaralha o tabuleiro travado (grátis). Se for impossível criar uma
## jogada (ex.: só sobraram blocos de cores diferentes), a fase é perdida.
func shuffle(rng: RandomNumberGenerator) -> bool:
	if not is_stuck():
		return false
	if board.shuffle(rng):
		return true
	status = Status.LOST
	return false


## Bônus de vitória: para cada jogada que sobrou, estoura um bloco aleatório
## (sem gravidade, só visual) e soma END_BONUS_POINTS. Não altera moves_left,
## então as estrelas continuam as mesmas. Retorna as células estouradas.
func play_end_bonus(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if status != Status.WON or end_bonus > 0:
		return cells
	for y in board.height:
		for x in board.width:
			if board.get_cell(x, y) != board.EMPTY:
				cells.append(Vector2i(x, y))
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	cells = cells.slice(0, mini(moves_left, cells.size()))
	for p in cells:
		board.set_cell(p.x, p.y, board.EMPTY)
	end_bonus = cells.size() * END_BONUS_POINTS
	score += end_bonus
	return cells


## Jogadas extras (ex.: anúncio recompensado). Reabre a partida se ela
## tiver sido perdida só por falta de jogadas.
func add_moves(n: int) -> void:
	moves_left += n
	if status == Status.LOST and moves_left > 0 and board.has_moves():
		status = Status.PLAYING


func _update_status() -> void:
	if is_goal_met():
		status = Status.WON
	elif moves_left <= 0:
		status = Status.LOST
