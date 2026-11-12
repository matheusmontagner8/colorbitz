## Base das telas sobrepostas ao jogo (pausa e resultado): fundo escuro em
## tela cheia, coluna centralizada e botões grandes. Funciona com o jogo pausado.
extends ColorRect

const Fx = preload("res://scripts/fx.gd")

const NEON_CYAN := Color("#3DE0FF")

var box: VBoxContainer


func _init() -> void:
	color = Color(0.01, 0.015, 0.06, 0.86)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	center.add_child(box)


func add_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(440, 108)
	b.pressed.connect(on_pressed)
	box.add_child(b)
	return b


func add_spacer(height: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	box.add_child(s)
