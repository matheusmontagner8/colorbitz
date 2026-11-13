## Visual de um bloco neon: quadrado arredondado com borda brilhante, halo
## e um ícone por cor (a forma identifica a cor; o modo daltônico ainda troca a
## paleta e destaca o ícone).
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
## Paleta do modo daltônico (opção "Daltonismo"): escolhida por simulação de
## protanopia, deuteranopia e tritanopia para que nenhum par de cores fique
## parecido (na paleta neon, azul e roxo quase se igualam na deuteranopia).
## Mesma ordem de entrada nas fases e mesmos símbolos da paleta normal.
const COLORBLIND_COLORS: Array[Color] = [
	Color("#40FFC6"),  # verde-água ● círculo
	Color("#B340FF"),  # roxo       ■ quadrado
	Color("#FFFF00"),  # amarelo    ▲ triângulo
	Color("#E6395C"),  # vermelho   ◆ losango
	Color("#BF8600"),  # laranja    ★ estrela
	Color("#0099BF"),  # azul       ✚ cruz
]
const Board = preload("res://scripts/board.gd")
## Especiais (mesmos valores do Board) e suas cores.
const BOMB := Board.BOMB
const STONE := Board.STONE
const WILD := Board.WILD
const GEM := Board.GEM
const BOMB_COLOR := Color("#FF8A3D")
const SPARK_COLOR := Color("#FFE53D")
const STONE_COLOR := Color("#8A93B8")
const WILD_COLOR := Color("#FFFFFF")
const GEM_COLOR := Color("#7DF9FF")
const ICE_COLOR := Color("#BDEBFF")

## Modo daltônico ligado: paleta segura e símbolos maiores, brancos.
## Ajustado pelo GameState a partir das opções.
static var colorblind := false

var color_index := 0:
	set(value):
		color_index = value
		set_process(_animated())
		queue_redraw()
## Camada de gelo por cima do bloco (0 = sem gelo, 1 = rachado, 2 = inteiro).
var ice := 0:
	set(value):
		ice = value
		queue_redraw()

var _style := StyleBoxFlat.new()
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style.anti_aliasing = true
	resized.connect(func(): pivot_offset = size / 2.0)
	set_process(_animated())


## Bomba (pavio), coringa (arco-íris girando) e joia (brilho) são animados.
func _animated() -> bool:
	return color_index in [BOMB, WILD, GEM]


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


static func color_of(index: int) -> Color:
	match index:
		BOMB:
			return BOMB_COLOR
		STONE:
			return STONE_COLOR
		WILD:
			return WILD_COLOR
		GEM:
			return GEM_COLOR
	var pal := palette()
	return pal[index % pal.size()]


## Cores dos blocos em uso (normal ou daltônico).
static func palette() -> Array[Color]:
	return COLORBLIND_COLORS if colorblind else COLORS


func _draw() -> void:
	match color_index:
		BOMB:
			_draw_bomb()
		STONE:
			_draw_stone()
		WILD:
			_draw_wild()
		GEM:
			_draw_gem()
		_:
			_draw_color_block()
	if ice > 0:
		_draw_ice()


func _draw_color_block() -> void:
	var col := color_of(color_index)
	var pad := size.x * 0.08
	_style.bg_color = col.darkened(0.6)
	_style.border_color = col
	_style.set_border_width_all(maxi(2, int(size.x * 0.055)))
	_style.set_corner_radius_all(int(size.x * 0.2))
	_style.shadow_color = Color(col, 0.42)
	_style.shadow_size = int(size.x * 0.12)
	draw_style_box(_style, Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0))
	if colorblind:  # símbolo maior e branco: a forma basta para reconhecer a cor
		draw_icon(self, color_index, size / 2.0, size.x * 0.22, Color(0, 0, 0, 0.55), maxf(4.0, size.x * 0.12))
		draw_icon(self, color_index, size / 2.0, size.x * 0.22, Color.WHITE, maxf(3.0, size.x * 0.07))
	else:
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


func _box_rect() -> Rect2:
	var pad := size.x * 0.08
	return Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0)


## Pedra: bloco cinza fosco, sem brilho, com rachaduras.
func _draw_stone() -> void:
	_style.bg_color = Color("#2A2F45")
	_style.border_color = STONE_COLOR
	_style.set_border_width_all(maxi(2, int(size.x * 0.05)))
	_style.set_corner_radius_all(int(size.x * 0.14))
	_style.shadow_color = Color(0, 0, 0, 0.5)
	_style.shadow_size = int(size.x * 0.05)
	draw_style_box(_style, _box_rect())
	var k := size.x
	var w := maxf(1.5, k * 0.035)
	var crack := Color(STONE_COLOR, 0.8)
	draw_polyline(PackedVector2Array([Vector2(0.3, 0.2) * k, Vector2(0.42, 0.42) * k, Vector2(0.35, 0.58) * k, Vector2(0.48, 0.8) * k]), crack, w, true)
	draw_polyline(PackedVector2Array([Vector2(0.42, 0.42) * k, Vector2(0.66, 0.36) * k, Vector2(0.78, 0.5) * k]), crack, w, true)
	draw_circle(Vector2(0.7, 0.72) * k, k * 0.05, Color(STONE_COLOR, 0.5))
	draw_circle(Vector2(0.26, 0.74) * k, k * 0.035, Color(STONE_COLOR, 0.4))


## Coringa: borda com as 6 cores girando e uma estrela branca no meio.
func _draw_wild() -> void:
	var r := _box_rect()
	_style.bg_color = Color("#1A1433")
	_style.border_color = Color(1, 1, 1, 0.25)
	_style.set_border_width_all(maxi(1, int(size.x * 0.02)))
	_style.set_corner_radius_all(int(size.x * 0.2))
	_style.shadow_color = Color(1, 1, 1, 0.25)
	_style.shadow_size = int(size.x * 0.1)
	draw_style_box(_style, r)
	var c := size / 2.0
	var ring := size.x * 0.33
	var w := maxf(2.0, size.x * 0.07)
	var pal := palette()
	for i in pal.size():
		var a0 := _time * 2.0 + i * TAU / pal.size()
		draw_arc(c, ring, a0, a0 + TAU / pal.size(), 8, pal[i], w, true)
	var star := PackedVector2Array()
	for i in 10:
		var rr := size.x * (0.17 if i % 2 == 0 else 0.07)
		star.append(c + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * rr)
	draw_colored_polygon(star, Color.WHITE)


## Joia: diamante facetado com brilho pulsando (precisa chegar ao fundo).
func _draw_gem() -> void:
	var c := size / 2.0
	var k := size.x
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	draw_circle(c, k * 0.42, Color(GEM_COLOR, 0.10 + 0.12 * pulse))
	var top := c.y - k * 0.22
	var mid := c.y - k * 0.06
	var bottom := c.y + k * 0.32
	var outline := PackedVector2Array([
		Vector2(c.x - k * 0.18, top), Vector2(c.x + k * 0.18, top), Vector2(c.x + k * 0.33, mid),
		Vector2(c.x, bottom), Vector2(c.x - k * 0.33, mid)])
	draw_colored_polygon(outline, Color(GEM_COLOR, 0.35))
	var w := maxf(2.0, k * 0.045)
	var closed := outline.duplicate()
	closed.append(outline[0])
	closed.append(outline[1])
	draw_polyline(closed, GEM_COLOR.lightened(0.3), w, true)
	var facet := Color(1, 1, 1, 0.7)
	draw_line(Vector2(c.x - k * 0.33, mid), Vector2(c.x + k * 0.33, mid), facet, w * 0.6, true)
	draw_line(Vector2(c.x - k * 0.08, top), Vector2(c.x - k * 0.14, mid), facet, w * 0.5, true)
	draw_line(Vector2(c.x + k * 0.08, top), Vector2(c.x + k * 0.14, mid), facet, w * 0.5, true)
	draw_line(Vector2(c.x - k * 0.14, mid), Vector2(c.x, bottom), facet, w * 0.5, true)
	draw_line(Vector2(c.x + k * 0.14, mid), Vector2(c.x, bottom), facet, w * 0.5, true)
	draw_circle(Vector2(c.x + k * 0.1, top + k * 0.06), k * 0.03 * (0.5 + pulse), Color.WHITE)


## Gelo por cima do bloco: translúcido; com 1 golpe restante aparece rachado.
func _draw_ice() -> void:
	var r := _box_rect().grow(-size.x * 0.01)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ICE_COLOR, 0.42 if ice >= 2 else 0.28)
	sb.border_color = Color(ICE_COLOR, 0.95)
	sb.set_border_width_all(maxi(2, int(size.x * (0.07 if ice >= 2 else 0.045))))
	sb.set_corner_radius_all(int(size.x * 0.16))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var k := size.x
	var w := maxf(1.5, k * 0.03)
	draw_line(Vector2(0.24, 0.3) * k, Vector2(0.36, 0.2) * k, Color(1, 1, 1, 0.9), w, true)  # reflexo
	draw_line(Vector2(0.24, 0.42) * k, Vector2(0.48, 0.2) * k, Color(1, 1, 1, 0.7), w, true)
	if ice == 1:
		var crack := Color(1, 1, 1, 0.85)
		draw_polyline(PackedVector2Array([Vector2(0.5, 0.14) * k, Vector2(0.56, 0.4) * k, Vector2(0.44, 0.56) * k, Vector2(0.58, 0.86) * k]), crack, w, true)
		draw_polyline(PackedVector2Array([Vector2(0.56, 0.4) * k, Vector2(0.84, 0.48) * k]), crack, w, true)
		draw_polyline(PackedVector2Array([Vector2(0.44, 0.56) * k, Vector2(0.16, 0.66) * k]), crack, w, true)
