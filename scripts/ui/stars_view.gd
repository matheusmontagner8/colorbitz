## Desenha 3 estrelas (cheias ou vazias). Usado na seleção de fases e no resultado.
## Desenhadas como polígonos para não depender de a fonte ter o caractere ★.
@tool
extends Control

@export_range(0, 3) var count := 0:
	set(value):
		count = value
		queue_redraw()
@export var filled_color := Color("#F0E442")
@export var empty_color := Color(1, 1, 1, 0.18)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x / 3.0, size.y)
	for i in 3:
		var center := Vector2(size.x / 2.0 + (i - 1) * s, size.y / 2.0)
		draw_colored_polygon(star_points(center, s * 0.46), filled_color if i < count else empty_color)


static func star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts
