## Gera todos os efeitos sonoros e músicas do jogo por síntese, sem samples
## externos (então não há licença de terceiros a verificar).
## Uso: godot --headless --path . -s tools/generate_audio.gd
## Saída: assets/audio/*.wav (mono, 22050 Hz, 16 bits). Determinístico.
extends SceneTree

const RATE := 22050
const OUT_DIR := "res://assets/audio"

enum Wave { SINE, TRIANGLE, SOFT_SQUARE }

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 7
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save("pop", _pop(), 0.8)
	_save("click", _click(), 0.5)
	_save("thud", _thud(), 0.6)
	_save("combo", _combo(), 0.7)
	_save("boom", _boom(), 0.95)
	_save("star", _star(), 0.6)
	_save("win", _win(), 0.75)
	_save("lose", _lose(), 0.7)
	_save("music_menu", _music_menu(), 0.6)
	_save("music_level", _music_level(), 0.7)
	quit()


# --- Efeitos ------------------------------------------------------------------

func _pop() -> PackedFloat32Array:
	var b := _buf(0.18)
	_tone(b, 0.0, 0.18, 520, 1150, Wave.SINE, 0.8, 0.003, 0.05)
	_tone(b, 0.0, 0.12, 1040, 2300, Wave.TRIANGLE, 0.2, 0.003, 0.03)
	_noise(b, 0.0, 0.02, 0.3, 0.001, 0.006, 7000, 7000)
	return b


func _click() -> PackedFloat32Array:
	var b := _buf(0.07)
	_tone(b, 0.0, 0.07, 1500, 1400, Wave.SINE, 0.7, 0.001, 0.015)
	_tone(b, 0.0, 0.05, 3000, 2800, Wave.TRIANGLE, 0.2, 0.001, 0.01)
	return b


func _thud() -> PackedFloat32Array:
	var b := _buf(0.16)
	_tone(b, 0.0, 0.16, 170, 80, Wave.SINE, 1.0, 0.002, 0.05)
	_noise(b, 0.0, 0.05, 0.25, 0.001, 0.015, 700, 300)
	return b


## Sequência rápida subindo (grupos médios).
func _combo() -> PackedFloat32Array:
	var b := _buf(0.45)
	var notes := [84, 88, 91, 96]  # C6 E6 G6 C7
	for i in notes.size():
		var f := _midi(notes[i])
		_tone(b, i * 0.055, 0.25, f, f, Wave.TRIANGLE, 0.5, 0.002, 0.07)
		_tone(b, i * 0.055, 0.25, f * 2.0, f * 2.0, Wave.SINE, 0.15, 0.002, 0.04)
	return b


## Explosão de desenho animado: assobio caindo + "pof" de ruído + soco grave.
func _boom() -> PackedFloat32Array:
	var b := _buf(1.0)
	_tone(b, 0.0, 0.22, 1600, 350, Wave.SINE, 0.25, 0.005, 0.12)  # assobio
	_noise(b, 0.06, 0.94, 1.0, 0.004, 0.22, 6000, 180)  # nuvem de "poeira"
	_tone(b, 0.06, 0.6, 190, 38, Wave.SINE, 1.0, 0.003, 0.16)  # soco grave
	_tone(b, 0.06, 0.4, 95, 30, Wave.SOFT_SQUARE, 0.35, 0.003, 0.1)
	_tone(b, 0.2, 0.35, 700, 160, Wave.TRIANGLE, 0.18, 0.01, 0.1)  # "boing" de cartoon
	return b


func _star() -> PackedFloat32Array:
	var b := _buf(0.6)
	_tone(b, 0.0, 0.6, 1318.5, 1318.5, Wave.SINE, 0.6, 0.002, 0.2)
	_tone(b, 0.0, 0.4, 1975.5, 1975.5, Wave.SINE, 0.25, 0.002, 0.12)
	_tone(b, 0.0, 0.25, 2637.0, 2637.0, Wave.TRIANGLE, 0.12, 0.002, 0.06)
	return b


func _win() -> PackedFloat32Array:
	var b := _buf(1.4)
	var notes := [72, 76, 79, 84]  # C5 E5 G5 C6
	for i in notes.size():
		var f := _midi(notes[i])
		_tone(b, i * 0.11, 0.3, f, f, Wave.TRIANGLE, 0.5, 0.003, 0.12)
		_tone(b, i * 0.11, 0.3, f, f, Wave.SINE, 0.3, 0.003, 0.12)
	for n in [84, 88, 91]:  # acorde final C6 E6 G6
		var f := _midi(n)
		_tone(b, 0.46, 0.94, f, f, Wave.TRIANGLE, 0.3, 0.005, 0.45)
		_tone(b, 0.46, 0.94, f * 1.003, f * 1.003, Wave.SINE, 0.2, 0.005, 0.45)
	return b


func _lose() -> PackedFloat32Array:
	var b := _buf(1.2)
	var notes := [67, 64, 60]  # G4 E4 C4, descendo
	for i in notes.size():
		var f := _midi(notes[i])
		var last := i == notes.size() - 1
		var dur := 0.7 if last else 0.28
		_tone(b, i * 0.24, dur, f, f * (0.94 if last else 1.0), Wave.SOFT_SQUARE, 0.35, 0.01, 0.35 if last else 0.15)
		_tone(b, i * 0.24, dur, f / 2.0, f / 2.0 * (0.94 if last else 1.0), Wave.SINE, 0.3, 0.01, 0.3)
	return b


# --- Músicas (loops sem emenda: as caudas "dão a volta" no buffer) ---------------

## Calma: 72 BPM, acordes suaves (Cmaj7 Am7 Fmaj7 G6), baixo e arpejo de sino.
func _music_menu() -> PackedFloat32Array:
	var beat := 60.0 / 72.0
	var bar := beat * 4.0
	var b := _buf(bar * 8.0)
	var chords := [
		[48, [60, 64, 67, 71]],
		[45, [57, 60, 64, 67]],
		[41, [53, 57, 60, 64]],
		[43, [55, 59, 62, 64]],
	]
	var arp := [0, 2, 1, 3, 2, 0, 3, 1]
	for ci in chords.size():
		var root: int = chords[ci][0]
		var notes: Array = chords[ci][1]
		var start := ci * bar * 2.0
		for n in notes:
			var f := _midi(n)
			_tone(b, start, bar * 2.0 + 1.5, f, f, Wave.SINE, 0.10, 1.2, 0.0, 1.5, true)
			_tone(b, start, bar * 2.0 + 1.5, f * 1.004, f * 1.004, Wave.SINE, 0.06, 1.2, 0.0, 1.5, true)
		for k in 2:
			var fb := _midi(root)
			_tone(b, start + k * bar, bar, fb, fb, Wave.SINE, 0.28, 0.05, 1.6, 0.3, true)
		for step in 16:
			if step % 4 == 3:
				continue  # respiros no arpejo
			var fa := _midi(notes[arp[step % arp.size()]] + 12)
			_tone(b, start + step * beat / 2.0, 1.0, fa, fa, Wave.SINE, 0.07, 0.005, 0.35, 0.3, true)
	return b


## Animada: 120 BPM, Am F C G, bumbo, palma, chimbal, baixo e arpejo.
func _music_level() -> PackedFloat32Array:
	var beat := 0.5
	var bar := beat * 4.0
	var b := _buf(bar * 8.0)
	var chords := [
		[45, [57, 60, 64]],
		[41, [53, 57, 60]],
		[48, [60, 64, 67]],
		[43, [55, 59, 62]],
	]
	var arp := [0, 1, 2, 1, 0, 2, 1, 2]
	for ci in chords.size():
		var root: int = chords[ci][0]
		var notes: Array = chords[ci][1]
		var start := ci * bar * 2.0
		for n in notes:  # pad discreto
			var f := _midi(n)
			_tone(b, start, bar * 2.0 + 0.5, f, f, Wave.SINE, 0.045, 0.3, 0.0, 0.5, true)
		for e in 16:  # baixo em colcheias, oitava acima nos contratempos
			var fb := _midi(root + (12 if e % 2 == 1 else 0))
			_tone(b, start + e * beat / 2.0, 0.22, fb, fb, Wave.SOFT_SQUARE, 0.2, 0.004, 0.09, 0.02, true)
		for s in 32:  # arpejo em semicolcheias
			var fa := _midi(notes[arp[s % arp.size()]] + 12)
			_tone(b, start + s * beat / 4.0, 0.2, fa, fa, Wave.TRIANGLE, 0.11, 0.002, 0.08, 0.02, true)
	for i in 8 * 4:  # bateria
		var t := i * beat
		_tone(b, t, 0.2, 150, 45, Wave.SINE, 0.9, 0.002, 0.08, 0.02, true)  # bumbo
		if i % 2 == 1:
			_noise(b, t, 0.15, 0.35, 0.002, 0.05, 2500, 1800, false, true)  # palma
		_noise(b, t + beat / 2.0, 0.05, 0.12, 0.001, 0.012, 7000, 7000, true, true)  # chimbal
	return b


# --- Síntese ------------------------------------------------------------------

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	b.fill(0.0)
	return b


func _midi(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


## Tom com varredura exponencial de f0 a f1. Envelope: ataque linear,
## depois decaimento exponencial (decay <= 0 = sustenta) e release linear no fim.
func _tone(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, wave: Wave,
		amp: float, attack: float, decay: float, release: float = 0.01, wrap: bool = false) -> void:
	var n := int(dur * RATE)
	var s0 := int(start * RATE)
	var size := b.size()
	var phase := 0.0
	var ratio := f1 / f0
	for i in n:
		var t := float(i) / RATE
		var f := f0 if ratio == 1.0 else f0 * pow(ratio, t / dur)
		phase += TAU * f / RATE
		var env := t / attack if t < attack else (exp(-(t - attack) / decay) if decay > 0.0 else 1.0)
		env *= minf(1.0, (dur - t) / release)
		var idx := s0 + i
		if wrap:
			idx %= size
		elif idx >= size:
			break
		b[idx] += _wave(wave, phase) * amp * env


## Ruído com filtro passa-baixa de um polo (corte varrendo de lp0 a lp1).
## highpass = true devolve ruído - passa-baixa (chimbal).
func _noise(b: PackedFloat32Array, start: float, dur: float, amp: float, attack: float, decay: float,
		lp0: float, lp1: float, highpass: bool = false, wrap: bool = false) -> void:
	var n := int(dur * RATE)
	var s0 := int(start * RATE)
	var size := b.size()
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var fc := lp0 * pow(lp1 / lp0, t / dur)
		var a := 1.0 - exp(-TAU * fc / RATE)
		var x := _rng.randf_range(-1.0, 1.0)
		y += a * (x - y)
		var v := (x - y) if highpass else y
		var env := t / attack if t < attack else exp(-(t - attack) / decay)
		env *= minf(1.0, (dur - t) / 0.005)
		var idx := s0 + i
		if wrap:
			idx %= size
		elif idx >= size:
			break
		b[idx] += v * amp * env


func _wave(wave: Wave, phase: float) -> float:
	match wave:
		Wave.TRIANGLE:
			return 2.0 / PI * asin(sin(phase))
		Wave.SOFT_SQUARE:
			return tanh(2.5 * sin(phase))
	return sin(phase)


func _save(name: String, b: PackedFloat32Array, peak: float) -> void:
	var m := 0.0
	for v in b:
		m = maxf(m, absf(v))
	var gain := peak / m if m > 0.0 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	var path := ProjectSettings.globalize_path("%s/%s.wav" % [OUT_DIR, name])
	var err := wav.save_to_wav(path)
	print("%-12s %5.2fs  pico %.2f  %s" % [name, b.size() / float(RATE), m, "ok" if err == OK else error_string(err)])
