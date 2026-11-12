## Progresso do jogador (estrelas por fase e opções), salvo em JSON.
## Lógica pura: não depende de cenas, por isso é testável.
extends RefCounted

const Daily = preload("res://scripts/daily.gd")
const Achievements = preload("res://scripts/achievements.gd")

const SAVE_VERSION := 1

## id da fase (String) -> melhor número de estrelas (1..3)
var stars: Dictionary = {}
var sound_on := true
var music_on := true
var vibration_on := true
## Acessibilidade: sem tremor de tela nem ondas de choque, menos partículas.
var reduce_effects := false
## Idioma escolhido ("" = o do aparelho; veja I18n.resolve).
var language := ""

## Poderes especiais que o jogador usa quando quiser (decisão de design):
## começa com POWER_START de cada e ganha +1 de cada a cada POWER_STARS_STEP
## estrelas. Guardamos só quantos foram usados; o saldo é calculado.
const POWERS := ["hammer", "swap"]
const POWER_START := 3
const POWER_STARS_STEP := 21
var powers_used: Dictionary = {}
## Poderes extras ganhos fora das estrelas (recompensa diária, fase diária, conquistas).
var powers_bonus: Dictionary = {}

## Recompensa diária: último dia resgatado (Daily.day_number) e dias seguidos.
var daily_claim_day := -1
var daily_streak := 0
## Fase diária: dia da última vitória e melhor pontuação do dia.
var daily_won_day := -1
var daily_best_day := -1
var daily_best_score := 0

## Contadores para as conquistas (veja [method add_stats]).
var stats: Dictionary = {}
## id da conquista -> true
var achievements: Dictionary = {}
## Tutoriais já concluídos (ex.: "powers" -> true).
var tutorials: Dictionary = {}


## Normaliza o id da fase: o JSON devolve números como float (1.0) e
## str(1.0) seria "1.0", diferente de "1".
static func _key(level_id) -> String:
	if typeof(level_id) == TYPE_FLOAT or typeof(level_id) == TYPE_INT:
		return str(int(level_id))
	return str(level_id)


func stars_for(level_id) -> int:
	return int(stars.get(_key(level_id), 0))


## Registra o resultado de uma vitória. Só guarda se for melhor que o anterior.
## Retorna true se houve melhora.
func record_result(level_id, earned_stars: int) -> bool:
	earned_stars = clampi(earned_stars, 0, 3)
	if earned_stars <= stars_for(level_id):
		return false
	stars[_key(level_id)] = earned_stars
	return true


## Uma fase é liberada quando:
##  1. a fase anterior foi vencida (a primeira está sempre liberada), e
##  2. se a fase tiver "stars_required" (fases-portão: 10, 20, 30...), o jogador
##     soma pelo menos essa quantidade de estrelas nas fases anteriores a ela.
func is_unlocked(index: int, levels: Array) -> bool:
	if index < 0 or index >= levels.size():
		return false
	if index > 0 and stars_for(levels[index - 1].get("id", index)) <= 0:
		return false
	return missing_stars(index, levels) == 0


## Estrelas exigidas para liberar a fase (0 se ela não for um portão).
static func stars_required(index: int, levels: Array) -> int:
	if index < 0 or index >= levels.size():
		return 0
	return int(levels[index].get("stars_required", 0))


## Soma das melhores estrelas nas fases antes de [param index].
func stars_before(index: int, levels: Array) -> int:
	var total := 0
	for i in mini(index, levels.size()):
		total += stars_for(levels[i].get("id", i + 1))
	return total


## Quantas estrelas ainda faltam para o portão da fase (0 = nenhuma).
func missing_stars(index: int, levels: Array) -> int:
	return maxi(0, stars_required(index, levels) - stars_before(index, levels))


func total_stars() -> int:
	var total := 0
	for v in stars.values():
		total += int(v)
	return total


## Quantos de cada poder o jogador já ganhou no total (iniciais + estrelas).
func powers_granted() -> int:
	return POWER_START + total_stars() / POWER_STARS_STEP


## Saldo atual do poder (nunca negativo).
func power_count(power: String) -> int:
	return maxi(0, powers_granted() + int(powers_bonus.get(power, 0)) - int(powers_used.get(power, 0)))


## Soma poderes extras, ex.: {"hammer": 1, "swap": 2}.
func add_powers(reward: Dictionary) -> void:
	for power in reward:
		if power in POWERS:
			powers_bonus[power] = int(powers_bonus.get(power, 0)) + int(reward[power])


## Gasta um poder. Retorna false se o saldo for zero.
func use_power(power: String) -> bool:
	if power_count(power) <= 0:
		return false
	powers_used[power] = int(powers_used.get(power, 0)) + 1
	return true


## Estrelas que faltam para ganhar o próximo poder de cada.
func stars_to_next_power() -> int:
	return POWER_STARS_STEP - total_stars() % POWER_STARS_STEP


# --- Recompensa e fase diária -------------------------------------------------

## Pode resgatar a recompensa de hoje? (Relógio voltado para trás não ganha.)
func can_claim_daily(day: int) -> bool:
	return day > daily_claim_day


## Streak que o jogador terá ao resgatar hoje (para mostrar antes de resgatar).
func streak_if_claimed(day: int) -> int:
	return daily_streak + 1 if day == daily_claim_day + 1 else 1


## Marca o dia na sequência. Retorna os poderes ganhos ({} se já marcou hoje
## ou se não for o 7º dia).
func claim_daily(day: int) -> Dictionary:
	if not can_claim_daily(day):
		return {}
	daily_streak = streak_if_claimed(day)
	daily_claim_day = day
	add_stats({"best_streak": daily_streak})
	var reward := Daily.reward_for_streak(daily_streak)
	add_powers(reward)
	return reward


func daily_won_today(day: int) -> bool:
	return daily_won_day == day


## Melhor pontuação na fase diária de hoje (0 se ainda não jogou).
func daily_best_today(day: int) -> int:
	return daily_best_score if daily_best_day == day else 0


func update_daily_best(day: int, score: int) -> void:
	if daily_best_day != day:
		daily_best_day = day
		daily_best_score = 0
	daily_best_score = maxi(daily_best_score, score)


## Registra uma vitória na fase diária. Só a primeira do dia dá recompensa.
## Retorna quantos de cada poder o jogador ganhou.
func record_daily_win(day: int, score: int) -> int:
	update_daily_best(day, score)
	if daily_won_day == day:
		return 0
	daily_won_day = day
	add_stats({"daily_wins": 1})
	add_powers(Daily.DAILY_WIN_REWARD)
	return int(Daily.DAILY_WIN_REWARD.hammer)


# --- Estatísticas e conquistas -------------------------------------------------

## Soma contadores; chaves que começam com "best_" guardam o maior valor.
func add_stats(delta: Dictionary) -> void:
	for key in delta:
		var v := int(delta[key])
		if String(key).begins_with("best_"):
			stats[key] = maxi(int(stats.get(key, 0)), v)
		else:
			stats[key] = int(stats.get(key, 0)) + v


## Valor usado pelas conquistas: contadores salvos ou calculados do progresso.
func stat_value(stat: String) -> int:
	match stat:
		"three_stars":
			var n := 0
			for v in stars.values():
				n += 1 if int(v) == 3 else 0
			return n
		"max_level":
			var best := 0
			for key in stars:
				if int(stars[key]) > 0 and String(key).is_valid_int():
					best = maxi(best, int(key))
			return best
		"streak":  # maior sequência de dias seguidos já alcançada
			return int(stats.get("best_streak", 0))
	return int(stats.get(stat, 0))


func has_achievement(id: String) -> bool:
	return achievements.has(id)


## Libera as conquistas cumpridas (e dá os poderes de cada uma).
## Retorna as recém-liberadas, na ordem de Achievements.LIST.
func check_achievements() -> Array:
	var unlocked := []
	for a in Achievements.LIST:
		if not achievements.has(a.id) and stat_value(a.stat) >= int(a.goal):
			achievements[a.id] = true
			add_powers(a.reward)
			unlocked.append(a)
	return unlocked


## Novo progresso zerado que mantém só as opções (som, música, vibração...).
func reset_keeping_settings():
	var fresh = get_script().new()
	fresh.from_dict({"settings": to_dict().settings})
	return fresh


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"stars": stars.duplicate(),
		"powers_used": powers_used.duplicate(),
		"powers_bonus": powers_bonus.duplicate(),
		"daily": {
			"claim_day": daily_claim_day, "streak": daily_streak, "won_day": daily_won_day,
			"best_day": daily_best_day, "best_score": daily_best_score,
		},
		"stats": stats.duplicate(),
		"achievements": achievements.keys(),
		"tutorials": tutorials.keys(),
		"settings": {"sound": sound_on, "music": music_on, "vibration": vibration_on, "reduce_effects": reduce_effects, "language": language},
	}


func from_dict(data: Dictionary) -> void:
	stars = {}
	var saved_stars = data.get("stars", {})
	if typeof(saved_stars) == TYPE_DICTIONARY:
		for key in saved_stars:
			stars[str(key)] = clampi(int(saved_stars[key]), 0, 3)
	powers_used = {}
	var used = data.get("powers_used", {})
	if typeof(used) == TYPE_DICTIONARY:
		for key in used:
			if str(key) in POWERS:
				powers_used[str(key)] = maxi(0, int(used[key]))
	powers_bonus = {}
	var bonus = data.get("powers_bonus", {})
	if typeof(bonus) == TYPE_DICTIONARY:
		for key in bonus:
			if str(key) in POWERS:
				powers_bonus[str(key)] = maxi(0, int(bonus[key]))
	var daily = data.get("daily", {})
	if typeof(daily) != TYPE_DICTIONARY:
		daily = {}
	daily_claim_day = int(daily.get("claim_day", -1))
	daily_streak = maxi(0, int(daily.get("streak", 0)))
	daily_won_day = int(daily.get("won_day", -1))
	daily_best_day = int(daily.get("best_day", -1))
	daily_best_score = maxi(0, int(daily.get("best_score", 0)))
	stats = {}
	var saved_stats = data.get("stats", {})
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for key in saved_stats:
			stats[str(key)] = maxi(0, int(saved_stats[key]))
	achievements = {}
	var saved_ach = data.get("achievements", [])
	if typeof(saved_ach) == TYPE_ARRAY:
		for id in saved_ach:
			if not Achievements.find(str(id)).is_empty():
				achievements[str(id)] = true
	tutorials = {}
	var saved_tut = data.get("tutorials", [])
	if typeof(saved_tut) == TYPE_ARRAY:
		for id in saved_tut:
			tutorials[str(id)] = true
	var settings = data.get("settings", {})
	if typeof(settings) == TYPE_DICTIONARY:
		sound_on = bool(settings.get("sound", true))
		music_on = bool(settings.get("music", true))
		vibration_on = bool(settings.get("vibration", true))
		reduce_effects = bool(settings.get("reduce_effects", false))
		language = str(settings.get("language", ""))


## Grava primeiro em um arquivo temporário e depois troca, para não
## corromper o save se o app for fechado no meio da gravação.
func save_to(path: String) -> Error:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return DirAccess.rename_absolute(tmp, path)


## Carrega o save. Se não existir ou estiver corrompido, começa do zero.
## Retorna true se carregou um save válido.
func load_from(path: String) -> bool:
	from_dict({})
	if not FileAccess.file_exists(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Save corrompido em %s; começando do zero." % path)
		return false
	from_dict(data)
	return true
