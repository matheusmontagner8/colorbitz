## Ícones desenhados do modo infinito (sem depender de emoji na fonte):
## "medal" (patente, na cor dela), "chest" (baú de estrelas), "crown" (fase
## chefe) e "flame" (sequência de vitórias).
extends Control

const StarsView = preload("res://scripts/ui/stars_view.gd")

const GOLD := Color("#FFD54A")
const FLAME := Color("#FF9A3D")

var kind := "medal":
	set(value):
		kind = value
		queue_redraw()
var color := GOLD:
	set(value):
		color = value
		queue_redraw()


func _init(icon_kind: String = "medal", icon_color: Color = GOLD, px: float = 56.0) -> void:
	kind = icon_kind
	color = icon_color
	custom_minimum_size = Vector2(px, px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var k := minf(size.x, size.y) / 100.0  # desenho em coordenadas 0..100
	var o := (size - Vector2(100, 100) * k) / 2.0
	match kind:
		"chest":
			_chest(o, k)
		"crown":
			_crown(o, k)
		"flame":
			_flame(o, k)
		_:
			_medal(o, k)


## Medalha: fita em V, disco com borda na cor da patente e estrela no meio.
func _medal(o: Vector2, k: float) -> void:
	var dark := color.darkened(0.45)
	draw_colored_polygon(_pts(o, k, [Vector2(26, 0), Vector2(44, 0), Vector2(58, 34), Vector2(42, 42)]), Color("#3DE0FF").darkened(0.2))
	draw_colored_polygon(_pts(o, k, [Vector2(56, 0), Vector2(74, 0), Vector2(58, 42), Vector2(42, 34)]), Color("#FF4FD8").darkened(0.2))
	var c := o + Vector2(50, 64) * k
	draw_circle(c, 40 * k, Color(color, 0.18))  # brilho
	draw_circle(c, 32 * k, dark)
	draw_arc(c, 32 * k, 0, TAU, 40, color, 6 * k, true)
	draw_colored_polygon(StarsView.star_points(c, 18 * k), color.lightened(0.25))


## Baú: corpo e tampa arredondados, faixas e fechadura.
func _chest(o: Vector2, k: float) -> void:
	var wood := Color("#7A3FB8")
	var band := color
	draw_circle(o + Vector2(50, 56) * k, 46 * k, Color(band, 0.12))
	var lid := StyleBoxFlat.new()
	lid.bg_color = wood.lightened(0.15)
	lid.corner_radius_top_left = int(22 * k)
	lid.corner_radius_top_right = int(22 * k)
	lid.anti_aliasing = true
	draw_style_box(lid, Rect2(o + Vector2(10, 22) * k, Vector2(80, 30) * k))
	var body := StyleBoxFlat.new()
	body.bg_color = wood
	body.set_corner_radius_all(int(8 * k))
	body.anti_aliasing = true
	draw_style_box(body, Rect2(o + Vector2(10, 50) * k, Vector2(80, 40) * k))
	draw_rect(Rect2(o + Vector2(10, 47) * k, Vector2(80, 7) * k), band)
	for x in [24, 70]:
		draw_rect(Rect2(o + Vector2(x, 22) * k, Vector2(6, 68) * k), band)
	draw_rect(Rect2(o + Vector2(42, 44) * k, Vector2(16, 20) * k), band.lightened(0.3))
	draw_circle(o + Vector2(50, 53) * k, 3 * k, wood.darkened(0.4))


## Coroa: três pontas com joias e base.
func _crown(o: Vector2, k: float) -> void:
	draw_circle(o + Vector2(50, 55) * k, 46 * k, Color(color, 0.14))
	var shape := _pts(o, k, [Vector2(12, 30), Vector2(32, 52), Vector2(50, 18), Vector2(68, 52), Vector2(88, 30), Vector2(80, 76), Vector2(20, 76)])
	draw_colored_polygon(shape, color)
	draw_rect(Rect2(o + Vector2(20, 76) * k, Vector2(60, 10) * k), color.darkened(0.25))
	for p in [Vector2(12, 30), Vector2(50, 18), Vector2(88, 30)]:
		draw_circle(o + p * k, 7 * k, color.lightened(0.35))
	draw_circle(o + Vector2(50, 60) * k, 7 * k, Color("#FF4FD8"))
	draw_circle(o + Vector2(32, 64) * k, 5 * k, Color("#3DE0FF"))
	draw_circle(o + Vector2(68, 64) * k, 5 * k, Color("#2BFF88"))


## Chama (sequência de vitórias): gota pontuda na cor, com miolo claro.
func _flame(o: Vector2, k: float) -> void:
	draw_circle(o + Vector2(50, 60) * k, 44 * k, Color(color, 0.14))
	draw_colored_polygon(_drop(o, k, Vector2(50, 64), 30.0, 52.0), color)
	draw_colored_polygon(_drop(o, k, Vector2(50, 74), 16.0, 30.0), Color("#FFE53D"))


## Gota com a ponta para cima: semicírculo embaixo (centro [param c], raio
## [param r]) e laterais curvas até a ponta, [param h] acima do centro.
func _drop(o: Vector2, k: float, c: Vector2, r: float, h: float) -> PackedVector2Array:
	var pts := []
	for i in 13:  # metade de baixo do círculo, da direita para a esquerda
		var a := PI * i / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	for i in range(1, 9):  # lado esquerdo subindo até a ponta
		var t := i / 8.0
		pts.append(c + Vector2(-r * (1.0 - t) * (1.0 - t * 0.35), -h * t))
	for i in range(7, 0, -1):  # lado direito descendo
		var t := i / 8.0
		pts.append(c + Vector2(r * (1.0 - t) * (1.0 - t * 0.35) + 4.0 * t, -h * t))
	return _pts(o, k, pts)


func _pts(o: Vector2, k: float, points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(o + p * k)
	return result
