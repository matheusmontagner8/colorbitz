## Tela de pausa: Continuar, Reiniciar fase e Menu.
extends "res://scripts/ui/overlay_panel.gd"

signal resume_pressed
signal restart_pressed
signal menu_pressed

var _warning: Label


func _init() -> void:
	super()
	var title := Fx.make_label(box, 68, NEON_CYAN)
	title.text = "Pausado"
	Fx.glow_label(title, NEON_CYAN, 18)
	add_spacer(16)
	add_button("Continuar", func(): resume_pressed.emit()).theme_type_variation = &"AccentButton"
	add_button("Reiniciar fase", func(): restart_pressed.emit())
	add_button("Menu", func(): menu_pressed.emit())
	_warning = Fx.make_label(box, 28, Color("#FF9A3D"))
	_warning.visible = false


## Aviso embaixo dos botões (ex.: sair zera a sequência); vazio = esconde.
func set_warning(text: String) -> void:
	_warning.text = text
	_warning.visible = text != ""
