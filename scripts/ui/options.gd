## Opções: liga/desliga som, música e vibração (salvo no progresso).
extends Control


func _ready() -> void:
	Audio.play_music("menu")
	%SoundButton.pressed.connect(_toggle.bind("sound_on"))
	%MusicButton.pressed.connect(_toggle.bind("music_on"))
	%VibrationButton.pressed.connect(_toggle.bind("vibration_on"))
	%BackButton.pressed.connect(GameState.go_to_menu)
	_refresh()


func _toggle(setting: String) -> void:
	var progress = GameState.progress
	progress.set(setting, not progress.get(setting))
	GameState.apply_audio_settings()
	GameState.save()
	if setting == "vibration_on":
		GameState.vibrate(60)  # demonstra a vibração ao ligar
	_refresh()


func _refresh() -> void:
	var p = GameState.progress
	%SoundButton.text = "Som: %s" % ("ligado" if p.sound_on else "desligado")
	%MusicButton.text = "Música: %s" % ("ligada" if p.music_on else "desligada")
	%VibrationButton.text = "Vibração: %s" % ("ligada" if p.vibration_on else "desligada")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.go_to_menu()
