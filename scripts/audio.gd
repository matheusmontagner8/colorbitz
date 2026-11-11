## Autoload "Audio": música de fundo (com troca suave entre faixas) e efeitos.
## Os arquivos são gerados por tools/generate_audio.gd.
extends Node

const SFX_NAMES := ["pop", "click", "thud", "combo", "boom", "star", "win", "lose", "powerup"]
const MUSIC := {
	"menu": "res://assets/audio/music_menu.wav",
	"level": "res://assets/audio/music_level.wav",
}
const MUSIC_DB := -9.0
const SILENT_DB := -40.0
const FADE_TIME := 0.6
const SFX_VOICES := 10

var _sfx := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sfx_name in SFX_NAMES:
		_sfx[sfx_name] = load("res://assets/audio/%s.wav" % sfx_name)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	_music.volume_db = MUSIC_DB
	add_child(_music)
	# Todo botão do jogo faz "clique", sem precisar ligar um por um.
	get_tree().node_added.connect(_on_node_added)


func play_sfx(sfx_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _sfx.get(sfx_name)
	if stream == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Troca a música com fade. Chamar de novo com a mesma faixa não reinicia.
func play_music(music_name: String) -> void:
	if music_name == _music_name or not MUSIC.has(music_name):
		return
	_music_name = music_name
	var stream: AudioStreamWAV = load(MUSIC[music_name])
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	if _fade:
		_fade.kill()
	_fade = create_tween()
	if _music.playing:
		_fade.tween_property(_music, "volume_db", SILENT_DB, FADE_TIME / 2.0)
	_fade.tween_callback(func():
		_music.stream = stream
		_music.volume_db = SILENT_DB
		_music.play())
	_fade.tween_property(_music, "volume_db", MUSIC_DB, FADE_TIME)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	play_sfx("click")
