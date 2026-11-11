## Visual de um bloco neon: quadrado arredondado com borda brilhante, halo
## e um ícone por cor (as cores ficam distinguíveis também para daltônicos).
extends Control

## Ordem das cores = ordem em que entram nas fases (fases com N cores usam as N primeiras).
const COLORS: Array[Color] = [
	Color("#2E9BFF"),  # azul      ● círculo
	Color("#B05CFF"),  # roxo      ■ quadrado
	Color("#2BFF88"),  # verde     ▲ triângulo
	Color("#FF4FD8"),  # rosa      ◆ losango
	Color("#FFE53D"),  # amarelo   ★ estrela
	Color("#FF3B3B"),  # vermelho  ✚ cruz
]
const COLOR_NAMES: Array[String] = ["azuis", "roxos", "verdes", "rosa", "amarelos", "vermelhos"]

var color_index := 0:
	set(value):
		color_index = value
		queue_redraw()

var _style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style.anti_aliasing = true
	resized.connect(func(): pivot_offset = size / 2.0)


static func color_of(index: int) -> Color:
	return COLORS[index % COLORS.size()]


func _draw() -> void:
	var col := color_of(color_index)
	var pad := size.x * 0.08
	_style.bg_color = col.darkened(0.6)
	_style.border_color = col
	_style.set_border_width_all(maxi(2, int(size.x * 0.055)))
	_style.set_corner_radius_all(int(size.x * 0.2))
	_style.shadow_color = Color(col, 0.42)
	_style.shadow_size = int(size.x * 0.12)
	draw_style_box(_style, Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0))
	draw_icon(self, color_index, size / 2.0, size.x * 0.17, col.lightened(0.45), maxf(2.0, size.x * 0.05))


## Desenha o ícone da cor como um "tubo de neon" (contorno).
static func draw_icon(canvas: CanvasItem, index: int, c: Vector2, s: float, color: Color, width: float) -> void:
	var pts := icon_points(index, c, s)
	pts.append(pts[0])
	pts.append(pts[1])  # fecha sem "dente" na junção
	canvas.draw_polyline(pts, color, width, true)


static func icon_points(index: int, c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match index % 6:
		0:  # círculo
			for i in 24:
				pts.append(c + Vector2.from_angle(i * TAU / 24.0) * s)
		1:  # quadrado
			var h := s * 0.85
			pts = PackedVector2Array([c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)])
		2:  # triângulo
			pts = PackedVector2Array([c + Vector2(0, -s * 1.05), c + Vector2(s, s * 0.75), c + Vector2(-s, s * 0.75)])
		3:  # losango
			pts = PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s, 0), c + Vector2(0, s * 1.1), c + Vector2(-s, 0)])
		4:  # estrela
			for i in 10:
				var r := s * 1.1 if i % 2 == 0 else s * 0.48
				pts.append(c + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * r)
		5:  # cruz
			var a := s * 0.35
			var b := s
			for v in [Vector2(-a, -b), Vector2(a, -b), Vector2(a, -a), Vector2(b, -a), Vector2(b, a), Vector2(a, a),
					Vector2(a, b), Vector2(-a, b), Vector2(-a, a), Vector2(-b, a), Vector2(-b, -a), Vector2(-a, -a)]:
				pts.append(c + v)
	return pts
