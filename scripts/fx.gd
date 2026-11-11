## Recursos visuais compartilhados (texturas e materiais do tema neon).
extends RefCounted

static var _dot: Texture2D
static var _additive: CanvasItemMaterial


## Ponto redondo com borda suave (partículas).
static func dot_texture() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.8))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_dot = t
	return _dot


## Mistura aditiva: cores somam com o fundo escuro e parecem brilhar.
static func additive_material() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


## Faz um Label "brilhar" com contorno colorido translúcido.
static func glow_label(label: Label, color: Color, strength: int = 12) -> void:
	label.add_theme_color_override("font_shadow_color", Color(color, 0.55))
	label.add_theme_constant_override("shadow_outline_size", strength)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
