## Opções: liga/desliga som e música (salvo no progresso).
extends Control


func _ready() -> void:
	%SoundButton.pressed.connect(_toggle_sound)
	%MusicButton.pressed.connect(_toggle_music)
	%BackButton.pressed.connect(GameState.go_to_menu)
	_refresh()


func _toggle_sound() -> void:
	GameState.progress.sound_on = not GameState.progress.sound_on
	_apply()


func _toggle_music() -> void:
	GameState.progress.music_on = not GameState.progress.music_on
	_apply()


func _apply() -> void:
	GameState.apply_audio_settings()
	GameState.save()
	_refresh()


func _refresh() -> void:
	%SoundButton.text = "Som: %s" % ("ligado" if GameState.progress.sound_on else "desligado")
	%MusicButton.text = "Música: %s" % ("ligada" if GameState.progress.music_on else "desligada")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.go_to_menu()
