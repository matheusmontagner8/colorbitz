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


## Dificuldade de 0 (fase 61) a 1 (teto).
static func difficulty(level_number: int) -> float:
	return clampf(float(level_number - FIRST_LEVEL) / RAMP_LEVELS, 0.0, 1.0)


## Fase [param level_number] (61, 62, ...) no mesmo formato do levels.json.
static func level_for(level_number: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_number * 7919 + 31337
	var d := difficulty(level_number)
	var kind: String = KINDS[posmod(level_number - FIRST_LEVEL, KINDS.size())]
	var level := {"id": level_number, "width": 7, "height": 9, "colors": 6, "endless": true}
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
