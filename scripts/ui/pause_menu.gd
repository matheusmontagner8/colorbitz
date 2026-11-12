## Tela de pausa: Continuar, Reiniciar fase e Menu.
extends "res://scripts/ui/overlay_panel.gd"

signal resume_pressed
signal restart_pressed
signal menu_pressed


func _init() -> void:
	super()
	var title := Fx.make_label(box, 68, NEON_CYAN)
	title.text = "Pausado"
	Fx.glow_label(title, NEON_CYAN, 18)
	add_spacer(16)
	add_button("Continuar", func(): resume_pressed.emit()).theme_type_variation = &"AccentButton"
	add_button("Reiniciar fase", func(): restart_pressed.emit())
	add_button("Menu", func(): menu_pressed.emit())
