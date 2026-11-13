## Modo infinito: fases geradas a partir da 61, depois de vencer as 60 da
## campanha. O número da fase define o desafio (tipo de meta, especiais,
## formato e dificuldade), sempre igual para o mesmo número; o tabuleiro em
## si é sorteado a cada tentativa, como nas fases normais.
## A dificuldade sobe devagar e para num teto (RAMP_LEVELS fases depois da 61).
## Lógica pura, sem interface. Balanceado com:
##   godot --headless --path . -s tools/balance.gd -- 200 endless
extends RefCounted

const LevelLoader = preload("res://scripts/level_loader.gd")

const FIRST_LEVEL := 61
## Fases até a dificuldade máxima.
const RAMP_LEVELS := 60
## Os tipos se revezam nesta ordem (nunca o mesmo duas vezes seguidas).
const KINDS := ["score", "color", "drop", "colors", "shape", "clear"]
## Na campanha, cada fase múltipla de LETTER_EVERY revela uma letra de
## "MODO INFINITO" (12 letras: fases 5, 10, ..., 60).
const LETTER_EVERY := 5
const LETTER_COUNT := 12

## Fase chefe a cada BOSS_EVERY fases (70, 80, ...): desafio mais duro, com
## borda dourada, e prêmio na primeira vitória. Os desafios se revezam.
const BOSS_EVERY := 10
const BOSS_REWARD := {"hammer": 2, "swap": 2}
const BOSS_KINDS := ["colors3", "fortress", "treasure"]

## Patentes: liberadas ao vencer a fase indicada (todas são chefes).
## O nome é a chave de tradução; a cor pinta a medalha.
const RANKS := [
	{"name": "Bronze", "level": 70, "color": "#E08A4A", "reward": {"hammer": 1, "swap": 1}},
	{"name": "Prata", "level": 80, "color": "#C8D4E8", "reward": {"hammer": 1, "swap": 1}},
	{"name": "Ouro", "level": 100, "color": "#FFD54A", "reward": {"hammer": 2, "swap": 2}},
	{"name": "Platina", "level": 130, "color": "#8FF5E0", "reward": {"hammer": 2, "swap": 2}},
	{"name": "Diamante", "level": 160, "color": "#7DC8FF", "reward": {"hammer": 3, "swap": 3}},
	{"name": "Neon", "level": 200, "color": "#FF4FD8", "reward": {"hammer": 3, "swap": 3}},
]

## Baú de estrelas: as estrelas do modo infinito enchem o baú, que abre a
## cada CHEST_STARS com um prêmio sorteado (às vezes em dobro).
const CHEST_STARS := 30
const CHEST_PRIZES := [
	{"weight": 35, "reward": {"hammer": 1}},
	{"weight": 35, "reward": {"swap": 1}},
	{"weight": 22, "reward": {"hammer": 1, "swap": 1}},
	{"weight": 8, "reward": {"hammer": 2, "swap": 2}},
]


## A fase revela uma letra da palavra ao ser vencida pela primeira vez?
static func gives_letter(level_number: int) -> bool:
	return level_number % LETTER_EVERY == 0 and level_number / LETTER_EVERY in range(1, LETTER_COUNT + 1)


## Quantas letras o jogador já revelou (fases múltiplas de 5 vencidas).
static func letters_revealed(progress) -> int:
	var n := 0
	for k in range(1, LETTER_COUNT + 1):
		if progress.stars_for(k * LETTER_EVERY) > 0:
			n += 1
	return n


static func is_boss(level_number: int) -> bool:
	return level_number > FIRST_LEVEL and level_number % BOSS_EVERY == 0


## Primeiro chefe a partir da fase [param level_number] (ela mesma, se for chefe).
static func next_boss(level_number: int) -> int:
	var n := maxi(level_number, FIRST_LEVEL + 1)
	return ceili(float(n) / BOSS_EVERY) * BOSS_EVERY


## Índice em RANKS da patente de quem venceu até a fase [param best_level] (-1 = nenhuma).
static func rank_index(best_level: int) -> int:
	var found := -1
	for i in RANKS.size():
		if best_level >= int(RANKS[i].level):
			found = i
	return found


## Estrelas ganhas no modo infinito (fases depois da campanha).
static func stars_total(progress, campaign_size: int) -> int:
	var total := 0
	for key in progress.stars:
		if String(key).is_valid_int() and int(key) > campaign_size:
			total += int(progress.stars[key])
	return total


## Prêmio do baú número [param chest_number] (1, 2, ...). Sorteio fixo por
## número: sair e voltar não troca o prêmio.
static func chest_prize(chest_number: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = chest_number * 104729 + 7
	var total := 0
	for p in CHEST_PRIZES:
		total += int(p.weight)
	var roll := rng.randi_range(1, total)
	for p in CHEST_PRIZES:
		roll -= int(p.weight)
		if roll <= 0:
			return p.reward.duplicate()
	return CHEST_PRIZES[0].reward.duplicate()


## Dificuldade de 0 (fase 61) a 1 (teto).
static func difficulty(level_number: int) -> float:
	return clampf(float(level_number - FIRST_LEVEL) / RAMP_LEVELS, 0.0, 1.0)


## Fase [param level_number] (61, 62, ...) no mesmo formato do levels.json.
static func level_for(level_number: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_number * 7919 + 31337
	var d := difficulty(level_number)
	var kind := _kind(level_number)
	var level := {"id": level_number, "width": 7, "height": 9, "colors": 6, "endless": true}
	if is_boss(level_number):
		_boss(level, level_number, rng, d)
		return level
	match kind:
		"score":
			level["moves"] = _lerp_i(12, 11, d)
			level["goal"] = {"type": "score", "target": _round10(lerpf(1000, 1100, d))}
			_extras(level, rng, d)
		"color":
			level["moves"] = _lerp_i(12, 10, d)
			level["goal"] = {"type": "color", "color": rng.randi_range(0, 5), "count": _lerp_i(7, 8, d)}
			_extras(level, rng, d)
		"colors":
			var a := rng.randi_range(0, 5)
			var b := (a + rng.randi_range(1, 5)) % 6
			var n := _lerp_i(5, 6, d)
			level["moves"] = _lerp_i(13, 12, d)
			level["goal"] = {"type": "colors", "targets": {str(a): n, str(b): n}}
			_extras(level, rng, d)
		"clear":
			level["moves"] = _lerp_i(12, 11, d)
			level["goal"] = {"type": "clear", "max_left": _lerp_i(30, 28, d)}
			if rng.randf() < 0.5:
				level["stones"] = rng.randi_range(1, 3)
		"drop":
			level["colors"] = 5
			level["moves"] = _lerp_i(19, 18, d)
			level["goal"] = {"type": "drop", "count": 2 if d < 0.6 else 3}
			level["gems"] = level["goal"]["count"]
		"shape":
			var shapes: Array = LevelLoader.SHAPES.keys()
			level["mask"] = shapes[rng.randi_range(0, shapes.size() - 1)]
			level["moves"] = _lerp_i(13, 11, d)
			level["goal"] = {"type": "score", "target": _round10(lerpf(850, 950, d))}
	return level


## Fase chefe: três desafios que se revezam (fase 70 = fortaleza, 80 = tesouro, 90 = três cores...).
static func _boss(level: Dictionary, level_number: int, rng: RandomNumberGenerator, d: float) -> void:
	level["boss"] = true
	match _boss_kind(level_number):
		"colors3":  # três cores ao mesmo tempo
			var colors := [0, 1, 2, 3, 4, 5]
			_shuffle(colors, rng)
			var n := 6
			level["moves"] = _lerp_i(14, 13, d)
			level["goal"] = {"type": "colors", "targets": {str(colors[0]): n, str(colors[1]): n, str(colors[2]): n}}
		"fortress":  # pontos com pedras e gelo
			level["moves"] = _lerp_i(13, 12, d)
			level["goal"] = {"type": "score", "target": _round10(lerpf(950, 1000, d))}
			level["stones"] = _lerp_i(3, 4, d)
			level["ice"] = 6
			level["ice_hits"] = 2 if d >= 0.5 else 1
		"treasure":  # três joias, com pedras no caminho
			level["colors"] = 5
			level["moves"] = _lerp_i(20, 19, d)
			level["goal"] = {"type": "drop", "count": 3}
			level["gems"] = 3
			level["stones"] = 2


static func _boss_kind(level_number: int) -> String:
	return BOSS_KINDS[posmod(level_number / BOSS_EVERY, BOSS_KINDS.size())]


## Tipo da fase comum. Se a fase logo depois de um chefe teria a mesma meta
## do chefe, ela troca de tipo com a fase seguinte (sem repetir desafios).
static func _kind(level_number: int) -> String:
	var i := posmod(level_number - FIRST_LEVEL, KINDS.size())
	if is_boss(level_number - 1) and KINDS[i] == _boss_goal(level_number - 1):
		i += 1
	elif is_boss(level_number - 2) and KINDS[posmod(i - 1, KINDS.size())] == _boss_goal(level_number - 2):
		i -= 1
	return KINDS[posmod(i, KINDS.size())]


static func _boss_goal(level_number: int) -> String:
	return {"colors3": "colors", "fortress": "score", "treasure": "drop"}[_boss_kind(level_number)]


## Embaralha com o rng da fase (mesmo resultado para o mesmo número).
static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


## Especiais sorteados: mais pedras, coringas e gelo conforme a dificuldade.
static func _extras(level: Dictionary, rng: RandomNumberGenerator, d: float) -> void:
	match rng.randi_range(0, 3):
		1:
			level["stones"] = rng.randi_range(2, 3 + roundi(d))
		2:
			level["wilds"] = 2
		3:
			level["ice"] = rng.randi_range(5, 6)
			level["ice_hits"] = 2 if rng.randf() < d * 0.5 else 1
			if level["goal"]["type"] == "score":  # gelo segura blocos: meta um pouco menor
				level["goal"]["target"] -= 100


static func _lerp_i(a: int, b: int, t: float) -> int:
	return roundi(lerpf(a, b, t))


static func _round10(v: float) -> int:
	return roundi(v / 10.0) * 10
