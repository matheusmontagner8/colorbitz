## Fase diária e recompensa diária. Tudo é calculado a partir do número do
## dia no horário de Brasília (UTC-3 fixo, sem horário de verão desde 2019),
## por isso a fase do dia é a mesma para todos os jogadores.
## Lógica pura, sem interface.
extends RefCounted

const UTC_OFFSET_SECONDS := -3 * 3600
const SECONDS_PER_DAY := 86400
## A sequência de dias seguidos recomeça a cada 7 dias; o 7º vale mais.
const STREAK_CYCLE := 7
## Primeira vitória do dia na fase diária.
const DAILY_WIN_REWARD := {"hammer": 1, "swap": 1}

## Um modelo por dia da semana (o dia escolhe o modelo; a semente, o tabuleiro).
## Balanceados com: godot --headless --path . -s tools/balance.gd -- 300 daily
const TEMPLATES := [
	{"name": "Pedras", "colors": 5, "moves": 15, "goal": {"type": "score", "target": 1250}, "stones": 3},
	{"name": "Coringas", "colors": 6, "moves": 14, "goal": {"type": "score", "target": 1250}, "wilds": 2},
	{"name": "Gelo", "colors": 6, "moves": 14, "goal": {"type": "score", "target": 1000}, "ice": 6},
	{"name": "Joias", "colors": 5, "moves": 20, "goal": {"type": "drop", "count": 2}, "gems": 2},
	{"name": "Ampulheta", "colors": 6, "moves": 14, "goal": {"type": "score", "target": 850}, "mask": "ampulheta"},
	{"name": "Meta dupla", "colors": 6, "moves": 14, "goal": {"type": "colors", "targets": {"0": 5, "3": 5}}, "wilds": 1},
	{"name": "Limpeza", "colors": 6, "moves": 12, "goal": {"type": "clear", "max_left": 30}},
]


## Número do dia (dias desde 01/01/1970) no horário de Brasília.
static func day_number(unix_time: float = -1.0) -> int:
	if unix_time < 0.0:
		unix_time = Time.get_unix_time_from_system()
	return floori((unix_time + UTC_OFFSET_SECONDS) / SECONDS_PER_DAY)


## "12/11/2026"
static func date_text(day: int) -> String:
	var d := Time.get_date_dict_from_unix_time(day * SECONDS_PER_DAY)
	return "%02d/%02d/%d" % [d.day, d.month, d.year]


## Posição (1..7) do dia dentro do ciclo da sequência.
static func cycle_day(streak: int) -> int:
	return (maxi(streak, 1) - 1) % STREAK_CYCLE + 1


## Prêmio do 7º dia seguido (os outros dias só contam a sequência).
const STREAK_REWARD := {"hammer": 2, "swap": 2}


## Recompensa por abrir o jogo no dia [param streak] da sequência:
## só o 7º dia do ciclo dá prêmio ({} nos outros).
static func reward_for_streak(streak: int) -> Dictionary:
	return STREAK_REWARD.duplicate() if cycle_day(streak) == STREAK_CYCLE else {}


## Fase diária do dia: modelo pelo dia da semana e semente fixa pela data.
static func level_for(day: int) -> Dictionary:
	var level: Dictionary = TEMPLATES[posmod(day, TEMPLATES.size())].duplicate(true)
	level["id"] = "daily"
	level["width"] = 7
	level["height"] = 9
	level["seed"] = posmod(day * 7919 + 104729, 2147483647)
	return level


## Texto de uma recompensa: "+1 Martelo e +1 Troca".
static func reward_text(reward: Dictionary) -> String:
	var parts := []
	if int(reward.get("hammer", 0)) > 0:
		parts.append("+%d Martelo" % int(reward.hammer))
	if int(reward.get("swap", 0)) > 0:
		parts.append("+%d Troca" % int(reward.swap))
	return " e ".join(parts)
