## Opções: som, música, vibração, efeitos reduzidos, modo daltônico (salvos no progresso),
## apagar o progresso (com confirmação) e a tela "Sobre" (versão, licenças, privacidade).
extends Control

const OverlayPanel = preload("res://scripts/ui/overlay_panel.gd")
const Fx = preload("res://scripts/fx.gd")
const I18n = preload("res://scripts/i18n.gd")

const DANGER_COLOR := Color("#FF4F4F")

## Confirmação de "Apagar progresso" (null quando fechada).
var confirm: Control


func _ready() -> void:
	Audio.play_music("menu")
	%SoundButton.pressed.connect(_toggle.bind("sound_on"))
	%MusicButton.pressed.connect(_toggle.bind("music_on"))
	%VibrationButton.pressed.connect(_toggle.bind("vibration_on"))
	%EffectsButton.pressed.connect(_toggle.bind("reduce_effects"))
	%ColorblindButton.pressed.connect(_toggle.bind("colorblind"))
	%LanguageButton.pressed.connect(_next_language)
	%ResetButton.pressed.connect(_ask_reset)
	%BackButton.pressed.connect(GameState.go_to_menu)
	%AboutButton.pressed.connect(GameState.go_to_about)
	_refresh()


func _toggle(setting: String) -> void:
	var progress = GameState.progress
	progress.set(setting, not progress.get(setting))
	GameState.apply_settings()
	GameState.save()
	if setting == "vibration_on":
		GameState.vibrate(60)  # demonstra a vibração ao ligar
	_refresh()


func _refresh() -> void:
	var p = GameState.progress
	%SoundButton.text = tr("Som: %s") % tr("ligado" if p.sound_on else "desligado")
	%MusicButton.text = tr("Música: %s") % tr("ligada" if p.music_on else "desligada")
	%VibrationButton.text = tr("Vibração: %s") % tr("ligada" if p.vibration_on else "desligada")
	%EffectsButton.text = tr("Efeitos: %s") % tr("reduzidos" if p.reduce_effects else "completos")
	%ColorblindButton.text = tr("Daltonismo: %s") % tr("ligado" if p.colorblind else "desligado")
	%LanguageButton.text = tr("Idioma: %s") % I18n.NAMES[I18n.current()]


## Alterna o idioma (português <-> inglês) e salva a escolha.
func _next_language() -> void:
	var langs: Array = I18n.LANGUAGES
	var next: String = langs[(langs.find(I18n.current()) + 1) % langs.size()]
	GameState.progress.language = next
	I18n.apply(next)
	GameState.save()
	_refresh()


func _ask_reset() -> void:
	confirm = OverlayPanel.new()
	confirm.color.a = 0.94
	add_child(confirm)
	var title := Fx.make_label(confirm.box, 56, DANGER_COLOR)
	title.text = "Apagar progresso?"
	Fx.glow_label(title, DANGER_COLOR, 14)
	var text := Fx.make_label(confirm.box, 30, Color(1, 1, 1, 0.85))
	text.text = "Estrelas, fases, poderes, conquistas\ne a sequência diária serão perdidos.\nIsso não pode ser desfeito."
	confirm.add_spacer(12)
	var yes: Button = confirm.add_button("Apagar tudo", _do_reset)
	yes.add_theme_color_override("font_color", DANGER_COLOR)
	confirm.add_button("Cancelar", _close_confirm).theme_type_variation = &"AccentButton"
	confirm.visible = true


func _do_reset() -> void:
	GameState.reset_progress()
	_close_confirm()
	GameState.show_toast("Progresso apagado", "O jogo começa do zero.")
	_refresh()


func _close_confirm() -> void:
	if confirm:
		confirm.queue_free()
		confirm = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if confirm:
			_close_confirm()
		else:
			GameState.go_to_menu()
