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
## Bomba (mesmo valor de Board.BOMB) e sua cor neon laranja.
const BOMB := preload("res://scripts/board.gd").BOMB
const BOMB_COLOR := Color("#FF8A3D")
const SPARK_COLOR := Color("#FFE53D")

var color_index := 0:
	set(value):
		color_index = value
		set_process(value == BOMB)  # só a bomba é animada (pavio piscando)
		queue_redraw()

var _style := StyleBoxFlat.new()
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style.anti_aliasing = true
	resized.connect(func(): pivot_offset = size / 2.0)
	set_process(color_index == BOMB)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


static func color_of(index: int) -> Color:
	if index == BOMB:
		return BOMB_COLOR
	return COLORS[index % COLORS.size()]


func _draw() -> void:
	if color_index == BOMB:
		_draw_bomb()
		return
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


## Bomba neon: corpo redondo escuro com contorno laranja, brilho pulsando,
## pavio e faísca piscando.
func _draw_bomb() -> void:
	var c := size / 2.0 + Vector2(0, size.x * 0.06)
	var r := size.x * 0.3
	var pulse := 0.5 + 0.5 * sin(_time * 7.0)
	var w := maxf(2.0, size.x * 0.055)
	draw_circle(c, r * 1.45, Color(BOMB_COLOR, 0.10 + 0.14 * pulse))  # halo
	draw_circle(c, r * 1.2, Color(BOMB_COLOR, 0.12 + 0.10 * pulse))
	draw_circle(c, r, Color("#1c0f2e"))  # corpo
	draw_arc(c, r, 0.0, TAU, 40, BOMB_COLOR, w, true)  # contorno neon
	draw_arc(c, r * 0.62, PI * 1.05, PI * 1.45, 10, Color(1, 1, 1, 0.55), w * 0.8, true)  # reflexo
	# bocal e pavio
	var neck := c + Vector2(r * 0.5, -r * 0.78)
	draw_line(c + Vector2(r * 0.3, -r * 0.88), neck + Vector2(r * 0.12, r * 0.05), BOMB_COLOR, w * 1.4, true)
	var fuse := PackedVector2Array()
	for i in 7:
		var t := i / 6.0
		fuse.append(neck + Vector2(t * r * 0.55, -t * r * 0.55 - sin(t * PI) * r * 0.25))
	draw_polyline(fuse, Color(1, 0.85, 0.6, 0.9), w * 0.7, true)
	# faísca
	var tip := fuse[fuse.size() - 1]
	var spark := r * (0.32 + 0.18 * pulse)
	draw_circle(tip, spark * 1.3, Color(SPARK_COLOR, 0.25 + 0.3 * pulse))
	draw_colored_polygon(_spark_points(tip, spark), SPARK_COLOR.lightened(0.3 * pulse))


static func _spark_points(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		var rr := s if i % 2 == 0 else s * 0.4
		pts.append(c + Vector2.from_angle(i * PI / 4.0 + PI / 8.0) * rr)
	return pts
