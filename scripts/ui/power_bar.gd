## Barra de poderes na base da tela: Martelo, Troca e o botão Embaralhar
## (que só aparece com o tabuleiro travado, entre os dois).
extends HBoxContainer

const PowerButton = preload("res://scripts/ui/power_button.gd")

const POWERS := ["hammer", "swap"]

signal power_pressed(power: String)
signal shuffle_pressed

## "hammer"/"swap" -> PowerButton
var buttons := {}
var shuffle_button: Button


func _init(height: float, margin: float) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -height
	offset_bottom = -margin
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 16)
	for power in POWERS:
		var pb := PowerButton.new()
		pb.power = power
		pb.pressed.connect(func(): power_pressed.emit(power))
		add_child(pb)
		buttons[power] = pb
	shuffle_button = Button.new()
	shuffle_button.text = "Embaralhar"
	shuffle_button.theme_type_variation = &"AccentButton"
	shuffle_button.add_theme_font_size_override("font_size", 28)
	shuffle_button.custom_minimum_size = Vector2(176, 124)
	shuffle_button.focus_mode = Control.FOCUS_NONE
	shuffle_button.visible = false
	shuffle_button.pressed.connect(func(): shuffle_pressed.emit())
	add_child(shuffle_button)
	move_child(shuffle_button, 1)  # entre o Martelo e a Troca


## Saldo de cada poder; desliga os botões sem saldo ou fora de jogo.
func refresh(playing: bool) -> void:
	for p in buttons:
		var pb = buttons[p]
		pb.count = GameState.power_count(p)
		pb.disabled = pb.count <= 0 or not playing


func disable_all() -> void:
	for pb in buttons.values():
		pb.disabled = true


## Marca o poder escolhido ("" = nenhum).
func set_active(power: String) -> void:
	for p in buttons:
		buttons[p].active = p == power


## Tabuleiro travado: os poderes com saldo pulsam. Retorna se há algum.
func pulse_available() -> bool:
	var any := false
	for p in buttons:
		if GameState.power_count(p) <= 0:
			continue
		any = true
		var pb: Control = buttons[p]
		pb.pivot_offset = pb.size / 2.0
		var t := create_tween()
		for i in 3:
			t.tween_property(pb, "scale", Vector2.ONE * 1.1, 0.18).set_trans(Tween.TRANS_SINE)
			t.tween_property(pb, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	return any


## Mostra o Embaralhar com um "pulo".
func show_shuffle() -> void:
	shuffle_button.visible = true
	shuffle_button.pivot_offset = shuffle_button.custom_minimum_size / 2.0
	shuffle_button.scale = Vector2.ONE * 0.3
	create_tween().tween_property(shuffle_button, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_shuffle() -> void:
	shuffle_button.visible = false
