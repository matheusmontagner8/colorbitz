## Progresso do jogador (estrelas por fase e opções), salvo em JSON.
## Lógica pura: não depende de cenas, por isso é testável.
extends RefCounted

const SAVE_VERSION := 1

## id da fase (String) -> melhor número de estrelas (1..3)
var stars: Dictionary = {}
var sound_on := true
var music_on := true
var vibration_on := true


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


## A primeira fase está sempre liberada; as demais exigem vencer a anterior.
func is_unlocked(index: int, levels: Array) -> bool:
	if index <= 0:
		return true
	if index >= levels.size():
		return false
	return stars_for(levels[index - 1].get("id", index)) > 0


func total_stars() -> int:
	var total := 0
	for v in stars.values():
		total += int(v)
	return total


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"stars": stars.duplicate(),
		"settings": {"sound": sound_on, "music": music_on, "vibration": vibration_on},
	}


func from_dict(data: Dictionary) -> void:
	stars = {}
	var saved_stars = data.get("stars", {})
	if typeof(saved_stars) == TYPE_DICTIONARY:
		for key in saved_stars:
			stars[str(key)] = clampi(int(saved_stars[key]), 0, 3)
	var settings = data.get("settings", {})
	if typeof(settings) == TYPE_DICTIONARY:
		sound_on = bool(settings.get("sound", true))
		music_on = bool(settings.get("music", true))
		vibration_on = bool(settings.get("vibration", true))


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
