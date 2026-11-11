## Visual de um bloco: quadrado arredondado colorido com um ícone por cor,
## para que as cores sejam distinguíveis também por quem tem daltonismo.
extends Control

## Paleta Okabe-Ito (amigável a daltonismo).
const COLORS: Array[Color] = [
	Color("#E69F00"),  # laranja
	Color("#56B4E9"),  # azul-céu
	Color("#009E73"),  # verde
	Color("#CC79A7"),  # rosa
	Color("#F0E442"),  # amarelo
	Color("#D55E00"),  # vermelhão
]
const COLOR_NAMES: Array[String] = ["laranja", "azuis", "verdes", "rosa", "amarelos", "vermelhos"]
const ICON_COLOR := Color(0, 0, 0, 0.38)

var color_index := 0:
	set(value):
		color_index = value
		queue_redraw()

var _style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func(): pivot_offset = size / 2.0)


func _draw() -> void:
	var pad := size.x * 0.05
	_style.bg_color = COLORS[color_index % COLORS.size()]
	_style.set_corner_radius_all(int(size.x * 0.22))
	draw_style_box(_style, Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0))
	draw_icon(self, color_index, size / 2.0, size.x * 0.2)


## Desenha o ícone da cor (também usado no HUD para mostrar a meta).
static func draw_icon(canvas: CanvasItem, index: int, c: Vector2, s: float) -> void:
	match index % 6:
		0:
			canvas.draw_circle(c, s, ICON_COLOR)
		1:
			canvas.draw_rect(Rect2(c - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), ICON_COLOR)
		2:
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(s, s * 0.8), c + Vector2(-s, s * 0.8)]), ICON_COLOR)
		3:
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), ICON_COLOR)
		4:
			var pts := PackedVector2Array()
			for i in 10:
				var r := s if i % 2 == 0 else s * 0.45
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			canvas.draw_colored_polygon(pts, ICON_COLOR)
		5:
			var w := s * 0.4
			canvas.draw_rect(Rect2(c - Vector2(s, w / 2.0), Vector2(s * 2.0, w)), ICON_COLOR)
			canvas.draw_rect(Rect2(c - Vector2(w / 2.0, s), Vector2(w, s * 2.0)), ICON_COLOR)
