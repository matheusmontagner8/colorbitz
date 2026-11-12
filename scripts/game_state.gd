## Autoload "GameState": fases carregadas, progresso salvo, fase atual e
## navegação entre telas. Fica vivo durante todo o jogo.
extends Node

const LevelLoader = preload("res://scripts/level_loader.gd")
const Progress = preload("res://scripts/progress.gd")
const Daily = preload("res://scripts/daily.gd")
const Fx = preload("res://scripts/fx.gd")

const SAVE_PATH := "user://save.json"
const SCENE_MENU := "res://scenes/main_menu.tscn"
const SCENE_LEVEL_SELECT := "res://scenes/level_select.tscn"
const SCENE_GAME := "res://scenes/game.tscn"
const SCENE_OPTIONS := "res://scenes/options.tscn"
const SCENE_ACHIEVEMENTS := "res://scenes/achievements.tscn"
const TOAST_COLOR := Color("#FFE53D")
const TOAST_TIME := 2.6

var levels: Array = []
var progress = Progress.new()
var current_index := 0
## Ferramentas (ex.: tools/screenshot.gd) desligam para não mexer no save real.
var save_enabled := true
## A dica "toque na bomba" aparece até o jogador usar a primeira bomba.
var bomb_tip_seen := false
## Jogando a fase diária (current_level() devolve a fase do dia).
var daily_mode := false
var _daily_level: Dictionary = {}
## Ferramentas e testes podem fixar o dia (Daily.day_number); -1 = hoje de verdade.
var day_override := -1
var _toast_layer: CanvasLayer
var _toast_queue: Array = []
var _toast_running := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	levels = LevelLoader.load_levels()
	progress.load_from(SAVE_PATH)
	apply_audio_settings()
	add_child(preload("res://scripts/ui/neon_background.gd").new())
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 50
	add_child(_toast_layer)


## Vibração do celular (se ligada nas opções). Sem efeito no PC.
func vibrate(duration_ms: int, amplitude: float = -1.0) -> void:
	if progress.vibration_on:
		Input.vibrate_handheld(duration_ms, amplitude)


func current_level() -> Dictionary:
	return _daily_level if daily_mode else levels[current_index]


func has_next_level() -> bool:
	return not daily_mode and current_index + 1 < levels.size()


## Dia atual no horário de Brasília (veja Daily.day_number).
func today() -> int:
	return day_override if day_override >= 0 else Daily.day_number()


func is_unlocked(index: int) -> bool:
	return progress.is_unlocked(index, levels)


## Estrelas exigidas pela fase (0 se não for um portão).
func stars_required(index: int) -> int:
	return progress.stars_required(index, levels)


## Quantas estrelas ainda faltam para liberar a fase (0 = nenhuma).
func missing_stars(index: int) -> int:
	return progress.missing_stars(index, levels)


## Registra uma vitória na fase atual (ou na diária) e salva.
## Retorna quantos poderes de cada tipo o jogador ganhou (estrelas novas ou
## primeira vitória do dia na fase diária).
func complete_current_level(stars: int, score: int = 0) -> int:
	var gained := 0
	if daily_mode:
		gained = progress.record_daily_win(today(), score)
	else:
		var before: int = progress.powers_granted()
		progress.record_result(current_level().get("id", current_index + 1), stars)
		gained = progress.powers_granted() - before
	check_achievements()
	save()
	return gained


## Atualiza o recorde de hoje na fase diária (depois do bônus de fim de fase).
func update_daily_best(score: int) -> void:
	progress.update_daily_best(today(), score)
	save()


## Soma estatísticas da partida (veja GameSession.take_stats). Avisa e salva
## se alguma conquista for liberada; com [param flush], salva sempre.
func record_stats(delta: Dictionary, flush := false) -> void:
	progress.add_stats(delta)
	if not check_achievements().is_empty() or flush:
		save()


## Libera conquistas cumpridas e mostra o aviso de cada uma.
func check_achievements() -> Array:
	var unlocked: Array = progress.check_achievements()
	for a in unlocked:
		show_toast("Conquista: %s" % a.title, Daily.reward_text(a.reward))
	if not unlocked.is_empty():
		save()
	return unlocked


## Recompensa diária: marca o dia na sequência e devolve os poderes ganhos
## ({} se já marcou hoje ou se não for o 7º dia).
func claim_daily_reward() -> Dictionary:
	if not progress.can_claim_daily(today()):
		return {}
	var reward: Dictionary = progress.claim_daily(today())
	check_achievements()  # "Toda semana" depende da sequência
	save()
	return reward


# --- Aviso (toast) ------------------------------------------------------------

## Aviso no topo da tela, por cima de qualquer cena. Vários ficam em fila.
func show_toast(title: String, subtitle: String = "") -> void:
	_toast_queue.append([title, subtitle])
	if not _toast_running:
		_run_toasts()


func _run_toasts() -> void:
	_toast_running = true
	while not _toast_queue.is_empty():
		var item: Array = _toast_queue.pop_front()
		var panel := _make_toast(item[0], item[1])
		_toast_layer.add_child(panel)
		await get_tree().process_frame
		var w: float = get_viewport().get_visible_rect().size.x
		panel.position = Vector2((w - panel.size.x) / 2.0, -panel.size.y - 10.0)
		Audio.play_sfx("star", 1.3)
		var t := panel.create_tween()
		t.tween_property(panel, "position:y", 36.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(TOAST_TIME)
		t.tween_property(panel, "position:y", -panel.size.y - 10.0, 0.25)
		await t.finished
		panel.queue_free()
	_toast_running = false


func _make_toast(title: String, subtitle: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.16, 0.95)
	style.border_color = TOAST_COLOR
	style.set_border_width_all(4)
	style.set_corner_radius_all(26)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	style.shadow_color = Color(TOAST_COLOR, 0.35)
	style.shadow_size = 14
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 36)
	head.add_theme_color_override("font_color", TOAST_COLOR)
	Fx.glow_label(head, TOAST_COLOR, 10)
	box.add_child(head)
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 28)
		sub.add_theme_color_override("font_color", Color("#2BFF88"))
		box.add_child(sub)
	return panel


func power_count(power: String) -> int:
	return progress.power_count(power)


## Gasta um poder especial e salva na hora (não dá para "devolver" fechando o app).
func use_power(power: String) -> bool:
	if not progress.use_power(power):
		return false
	save()
	return true


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


func go_to_achievements() -> void:
	go_to(SCENE_ACHIEVEMENTS)


func play_level(index: int) -> void:
	daily_mode = false
	current_index = clampi(index, 0, levels.size() - 1)
	go_to(SCENE_GAME)


## Joga a fase diária de hoje (pode repetir; só a 1ª vitória do dia dá prêmio).
func play_daily() -> void:
	start_daily()
	go_to(SCENE_GAME)


## Prepara a fase diária sem trocar de cena (usado por play_daily e ferramentas).
func start_daily() -> void:
	daily_mode = true
	_daily_level = Daily.level_for(today())
