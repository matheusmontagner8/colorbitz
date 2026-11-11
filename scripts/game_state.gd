## Autoload "GameState": fases carregadas, progresso salvo, fase atual e
## navegação entre telas. Fica vivo durante todo o jogo.
extends Node

const LevelLoader = preload("res://scripts/level_loader.gd")
const Progress = preload("res://scripts/progress.gd")

const SAVE_PATH := "user://save.json"
const SCENE_MENU := "res://scenes/main_menu.tscn"
const SCENE_LEVEL_SELECT := "res://scenes/level_select.tscn"
const SCENE_GAME := "res://scenes/game.tscn"
const SCENE_OPTIONS := "res://scenes/options.tscn"

var levels: Array = []
var progress = Progress.new()
var current_index := 0
## Ferramentas (ex.: tools/screenshot.gd) desligam para não mexer no save real.
var save_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	levels = LevelLoader.load_levels()
	progress.load_from(SAVE_PATH)
	apply_audio_settings()


func current_level() -> Dictionary:
	return levels[current_index]


func has_next_level() -> bool:
	return current_index + 1 < levels.size()


## Registra uma vitória na fase atual e salva.
func complete_current_level(stars: int) -> void:
	if progress.record_result(current_level().get("id", current_index + 1), stars):
		save()


func save() -> void:
	if not save_enabled:
		return
	var err: Error = progress.save_to(SAVE_PATH)
	if err != OK:
		push_error("Falha ao salvar progresso: %s" % error_string(err))


## Silencia os barramentos de áudio conforme as opções.
## (Os barramentos Music e SFX ficam em default_bus_layout.tres.)
func apply_audio_settings() -> void:
	_set_bus_mute("SFX", not progress.sound_on)
	_set_bus_mute("Music", not progress.music_on)


func _set_bus_mute(bus_name: String, mute: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, mute)


# --- Navegação ---------------------------------------------------------------

func go_to(scene_path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)


func go_to_menu() -> void:
	go_to(SCENE_MENU)


func go_to_level_select() -> void:
	go_to(SCENE_LEVEL_SELECT)


func go_to_options() -> void:
	go_to(SCENE_OPTIONS)


func play_level(index: int) -> void:
	current_index = clampi(index, 0, levels.size() - 1)
	go_to(SCENE_GAME)
