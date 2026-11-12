## Balão de dica (tutorial de toque, bomba, poderes, tabuleiro travado),
## com fundo para ficar legível sobre o tabuleiro.
extends Label

const NEON_CYAN := Color("#3DE0FF")

## Distância da base da tela até o balão (acima da barra de poderes).
var bottom_margin := 158.0
## Distância do topo da tela até o balão, quando mostrado no alto.
var top_margin := 112.0
var _tween: Tween


func _init() -> void:
	add_theme_font_size_override("font_size", 30)
	add_theme_color_override("font_color", Color.WHITE)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.1, 0.92)
	style.border_color = Color(NEON_CYAN, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(NEON_CYAN, 0.3)
	style.shadow_size = 12
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("normal", style)


## [param at_top]: balão sobre o HUD, para não cobrir o tabuleiro.
func show_tip(tip: String, at_top := false) -> void:
	if _tween:
		_tween.kill()
	text = tip
	visible = true
	modulate.a = 1.0
	# Centraliza na parte de baixo da tela, do tamanho do texto.
	var s := get_combined_minimum_size()
	offset_left = -s.x / 2.0
	offset_right = s.x / 2.0
	var bottom := -bottom_margin
	if at_top:  # âncora é a base da tela: converte "abaixo do título da fase"
		bottom = top_margin + s.y - get_parent_area_size().y
	offset_bottom = bottom
	offset_top = bottom - s.y


func hide_tip() -> void:
	if not visible or modulate.a < 1.0:
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(func(): visible = false)


## Esconde na hora, sem animação.
func clear() -> void:
	if _tween:
		_tween.kill()
	visible = false


func is_showing(tip: String) -> bool:
	return visible and text == tip
