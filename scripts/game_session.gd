## Estado de uma partida (uma fase): pontuação, jogadas, meta e estrelas.
## Também é lógica pura, sem interface.
extends RefCounted

enum Status { PLAYING, WON, LOST }

## Fração de jogadas que sobram para ganhar 2 e 3 estrelas.
const DEFAULT_STAR_THRESHOLDS := [0.20, 0.40]

var board  # board.gd
var score := 0
var max_moves := 0
var moves_left := 0
## {"type": "score", "target": int} ou {"type": "color", "color": int, "count": int}
var goal: Dictionary = {}
var removed_by_color: Dictionary = {}
var status: Status = Status.PLAYING
var star_thresholds: Array = DEFAULT_STAR_THRESHOLDS.duplicate()


func setup(p_board, p_max_moves: int, p_goal: Dictionary) -> void:
	board = p_board
	max_moves = p_max_moves
	moves_left = p_max_moves
	goal = p_goal
	score = 0
	removed_by_color = {}
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


## Jogadas extras (ex.: anúncio recompensado). Reabre a partida se ela
## tiver sido perdida só por falta de jogadas.
func add_moves(n: int) -> void:
	moves_left += n
	if status == Status.LOST and board.has_moves():
		status = Status.PLAYING


func _update_status() -> void:
	if is_goal_met():
		status = Status.WON
	elif moves_left <= 0 or not board.has_moves():
		status = Status.LOST
