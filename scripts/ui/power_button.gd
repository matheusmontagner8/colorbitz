## Botão de poder especial (Martelo ou Troca): ícone neon desenhado,
## nome embaixo e um selo com a quantidade disponível.
extends Button

const COLORS := {"hammer": Color("#FF8A3D"), "swap": Color("#3DE0FF")}
const NAMES := {"hammer": "Martelo", "swap": "Troca"}
const BADGE_COLOR := Color("#FF4FD8")

var power := "hammer":
	set(v):
		power = v
		queue_redraw()
var count := 0:
	set(v):
		count = v
		queue_redraw()
## Ligado enquanto o jogador escolhe o(s) bloco(s) do poder.
var active := false:
	set(v):
		active = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(200, 124)
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	var col: Color = COLORS.get(power, Color.WHITE)
	if disabled:
		col = Color(col, 0.35)
	if active:
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_border_width_all(5)
		sb.border_color = col
		sb.set_corner_radius_all(20)
		sb.shadow_color = Color(col, 0.55)
		sb.shadow_size = 16
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var c := Vector2(size.x / 2.0, 50.0)
	if power == "hammer":
		_draw_hammer(c, col)
	else:
		_draw_swap(c, col)
	var font := get_theme_default_font()
	draw_string(font, Vector2(0, size.y - 16), tr(NAMES.get(power, "")), HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(1, 1, 1, 0.4 if disabled else 0.9))
	# Selo com a quantidade.
	var bc := Vector2(size.x - 24, 24)
	var badge := BADGE_COLOR if count > 0 else Color(0.35, 0.38, 0.5)
	draw_circle(bc, 22, Color(badge, 0.3))
	draw_circle(bc, 18, badge)
	draw_string(font, bc + Vector2(-30, 9), str(count), HORIZONTAL_ALIGNMENT_CENTER, 60, 26, Color.WHITE)


func _draw_hammer(c: Vector2, col: Color) -> void:
	draw_set_transform(c, -0.7)
	_neon_rect(Rect2(-5, -6, 10, 38), col)    # cabo
	_neon_rect(Rect2(-24, -26, 48, 20), col)  # cabeça
	draw_set_transform(Vector2.ZERO)


func _draw_swap(c: Vector2, col: Color) -> void:
	for dir in [1, -1]:
		var y: float = c.y - 11.0 * dir
		var tip := Vector2(c.x + 26.0 * dir, y)
		draw_line(Vector2(c.x - 24.0 * dir, y), tip - Vector2(10.0 * dir, 0), col, 6.0, true)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14.0 * dir, -10), tip + Vector2(-14.0 * dir, 10)]), col)


func _neon_rect(r: Rect2, col: Color) -> void:
	draw_rect(r, Color(col, col.a * 0.3))
	draw_rect(r, col, false, 4.0)
