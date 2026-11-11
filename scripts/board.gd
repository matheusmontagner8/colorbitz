## Lógica pura do tabuleiro: sem nós, sem interface, totalmente testável.
##
## Coordenadas: x = coluna (0 à esquerda), y = linha (0 no topo).
## A gravidade puxa os blocos para baixo (y maior) e, se [member collapse_columns]
## estiver ligado, colunas vazias se fecham para a esquerda.
extends RefCounted

const EMPTY := -1
const MIN_GROUP := 2
## Bomba (poder especial): valor de célula que não é uma cor.
const BOMB := 99
## Tamanho padrão de grupo que deixa uma bomba (veja [method bomb_size_for_colors]).
const DEFAULT_BOMB_GROUP_SIZE := 8
## Raio da explosão (1 = área 3x3 em volta da bomba).
const BOMB_RADIUS := 1
const BOMB_POINTS_PER_BLOCK := 50
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var width: int
var height: int
## Decisão de design (seção 9.1): colunas vazias se fecham para o lado.
var collapse_columns := true
## Grupos deste tamanho ou maiores deixam uma bomba no lugar do bloco tocado.
var bomb_group_size := DEFAULT_BOMB_GROUP_SIZE

var _cells := PackedInt32Array()


func _init(w: int = 7, h: int = 9) -> void:
	width = w
	height = h
	_cells.resize(w * h)
	_cells.fill(EMPTY)


## Carrega o tabuleiro a partir de linhas de texto (útil em testes).
## Cada caractere é um dígito de cor ("0".."9"), "." para vazio ou "B" para bomba.
func load_rows(rows: Array) -> void:
	height = rows.size()
	width = String(rows[0]).length() if height > 0 else 0
	_cells.resize(width * height)
	for y in height:
		var row := String(rows[y])
		assert(row.length() == width, "Todas as linhas devem ter o mesmo tamanho")
		for x in width:
			var ch := row[x]
			_cells[y * width + x] = EMPTY if ch == "." else (BOMB if ch == "B" else ch.to_int())


## Representação em texto, no mesmo formato de [method load_rows].
func to_rows() -> Array:
	var rows: Array = []
	for y in height:
		var row := ""
		for x in width:
			var c := get_cell(x, y)
			row += "." if c == EMPTY else ("B" if c == BOMB else str(c))
		rows.append(row)
	return rows


## Preenche o tabuleiro com cores aleatórias, garantindo que exista ao menos uma jogada.
func fill_random(num_colors: int, rng: RandomNumberGenerator) -> void:
	for _attempt in 100:
		for i in _cells.size():
			_cells[i] = rng.randi_range(0, num_colors - 1)
		if has_moves():
			return


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func get_cell(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return EMPTY
	return _cells[y * width + x]


func set_cell(x: int, y: int, color: int) -> void:
	if in_bounds(x, y):
		_cells[y * width + x] = color


## Retorna todas as posições conectadas (cima/baixo/esquerda/direita) com a mesma cor.
func find_group(x: int, y: int) -> Array[Vector2i]:
	var group: Array[Vector2i] = []
	var color := get_cell(x, y)
	if color == EMPTY:
		return group
	var start := Vector2i(x, y)
	var visited := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		group.append(p)
		for d in DIRS:
			var n := p + d
			if not visited.has(n) and get_cell(n.x, n.y) == color:
				visited[n] = true
				stack.append(n)
	return group


## "Grupo grande" depende de quantas cores a fase tem: com mais cores os
## grupos são menores, então a bomba sai com menos blocos (decisão de design:
## frequência parecida de bombas no jogo todo).
static func bomb_size_for_colors(colors: int) -> int:
	if colors <= 4:
		return 8
	if colors == 5:
		return 7
	return 6


static func points_for(group_size: int) -> int:
	return group_size * group_size * 10


## Executa um toque. Se for válido, remove os blocos, aplica gravidade e
## retorna um dicionário com:
##   color (int: cor do grupo, ou BOMB se foi uma explosão),
##   size (int: blocos coloridos destruídos),
##   removed (Array[Vector2i]: posições que somem, antes da gravidade),
##   removed_colors (Dictionary cor -> quantidade, para metas de cor),
##   points (int),
##   bomb (Vector2i: onde nasceu uma bomba, ou null),
##   exploded (Array[Vector2i]: bombas que explodiram),
##   moves (Array de {from: Vector2i, to: Vector2i}) para animação.
## Se o toque for inválido (vazio ou bloco isolado), retorna {} e nada muda.
func tap(x: int, y: int) -> Dictionary:
	if get_cell(x, y) == BOMB:
		return _explode(x, y)
	var group := find_group(x, y)
	if group.size() < MIN_GROUP:
		return {}
	var color := get_cell(x, y)
	var bomb_at = null
	var removed: Array[Vector2i] = []
	for p in group:
		if group.size() >= bomb_group_size and p == Vector2i(x, y):
			set_cell(p.x, p.y, BOMB)  # o bloco tocado vira bomba
			bomb_at = p
		else:
			set_cell(p.x, p.y, EMPTY)
			removed.append(p)
	var moves := settle()
	return {
		"color": color,
		"size": group.size(),
		"removed": removed,
		"removed_colors": {color: group.size()},
		"points": points_for(group.size()),
		"bomb": bomb_at,
		"exploded": [],
		"moves": moves,
	}


## Células atingidas ao explodir a bomba em (x, y), incluindo explosões em
## cadeia de outras bombas dentro da área. Não altera o tabuleiro.
## Retorna {cells: Array[Vector2i], bombs: Array[Vector2i]}.
func explosion_area(x: int, y: int) -> Dictionary:
	var hit := {}
	var bombs: Array[Vector2i] = []
	var queue: Array[Vector2i] = [Vector2i(x, y)]
	var queued := {Vector2i(x, y): true}
	while not queue.is_empty():
		var b: Vector2i = queue.pop_front()
		bombs.append(b)
		for dy in range(-BOMB_RADIUS, BOMB_RADIUS + 1):
			for dx in range(-BOMB_RADIUS, BOMB_RADIUS + 1):
				var p := b + Vector2i(dx, dy)
				var c := get_cell(p.x, p.y)
				if c == EMPTY:
					continue
				hit[p] = true
				if c == BOMB and not queued.has(p):
					queued[p] = true
					queue.append(p)
	var cells: Array[Vector2i] = []
	cells.assign(hit.keys())
	return {"cells": cells, "bombs": bombs}


func _explode(x: int, y: int) -> Dictionary:
	var area := explosion_area(x, y)
	var removed: Array[Vector2i] = area.cells
	var removed_colors := {}
	var destroyed := 0
	for p in removed:
		var c := get_cell(p.x, p.y)
		if c != BOMB:
			removed_colors[c] = int(removed_colors.get(c, 0)) + 1
			destroyed += 1
		set_cell(p.x, p.y, EMPTY)
	var moves := settle()
	return {
		"color": BOMB,
		"size": destroyed,
		"removed": removed,
		"removed_colors": removed_colors,
		"points": destroyed * BOMB_POINTS_PER_BLOCK,
		"bomb": null,
		"exploded": area.bombs,
		"moves": moves,
	}


## Poder "Martelo": destrói um único bloco, sem precisar de grupo.
## Se o alvo for uma bomba, ela explode. Retorna o mesmo formato de [method tap]
## ({} se a célula estiver vazia).
func smash(x: int, y: int) -> Dictionary:
	var c := get_cell(x, y)
	if c == EMPTY:
		return {}
	if c == BOMB:
		return _explode(x, y)
	var p := Vector2i(x, y)
	set_cell(x, y, EMPTY)
	var moves := settle()
	return {
		"color": c,
		"size": 1,
		"removed": [p] as Array[Vector2i],
		"removed_colors": {c: 1},
		"points": BOMB_POINTS_PER_BLOCK,
		"bomb": null,
		"exploded": [],
		"moves": moves,
	}


## Poder "Troca": troca dois blocos (quaisquer, inclusive bombas) de lugar.
## Retorna false se alguma célula estiver vazia, fora do tabuleiro ou se for a mesma.
func swap(a: Vector2i, b: Vector2i) -> bool:
	var ca := get_cell(a.x, a.y)
	var cb := get_cell(b.x, b.y)
	if a == b or ca == EMPTY or cb == EMPTY:
		return false
	set_cell(a.x, a.y, cb)
	set_cell(b.x, b.y, ca)
	return true


## Posições de todas as bombas no tabuleiro.
func bombs() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in height:
		for x in width:
			if get_cell(x, y) == BOMB:
				result.append(Vector2i(x, y))
	return result


## Aplica gravidade e (opcionalmente) fecha colunas vazias em uma única passada.
## Retorna a lista de blocos que mudaram de posição.
func settle() -> Array:
	var moves: Array = []
	var new_cells := PackedInt32Array()
	new_cells.resize(width * height)
	new_cells.fill(EMPTY)
	var dest_x := 0
	for x in width:
		var dest_y := height - 1
		for y in range(height - 1, -1, -1):
			var c := get_cell(x, y)
			if c == EMPTY:
				continue
			new_cells[dest_y * width + dest_x] = c
			if dest_x != x or dest_y != y:
				moves.append({"from": Vector2i(x, y), "to": Vector2i(dest_x, dest_y)})
			dest_y -= 1
		var column_has_blocks := dest_y < height - 1
		if column_has_blocks or not collapse_columns:
			dest_x += 1
	_cells = new_cells
	return moves


## Todos os grupos válidos (2+ blocos da mesma cor) do tabuleiro. Bombas não entram.
func all_groups() -> Array:
	var seen := {}
	var groups := []
	for y in height:
		for x in width:
			var p := Vector2i(x, y)
			if seen.has(p) or get_cell(x, y) == EMPTY or get_cell(x, y) == BOMB:
				continue
			var g := find_group(x, y)
			for q in g:
				seen[q] = true
			if g.size() >= MIN_GROUP:
				groups.append(g)
	return groups


## O maior grupo válido (para a dica), ou [] se não houver.
func best_group() -> Array:
	var best := []
	for g in all_groups():
		if g.size() > best.size():
			best = g
	return best


## Existe alguma jogada (grupo de 2+ blocos ou uma bomba para tocar)?
func has_moves() -> bool:
	for y in height:
		for x in width:
			var c := get_cell(x, y)
			if c == EMPTY:
				continue
			if c == BOMB:
				return true
			if get_cell(x + 1, y) == c or get_cell(x, y + 1) == c:
				return true
	return false


func count_blocks() -> int:
	var total := 0
	for c in _cells:
		if c != EMPTY:
			total += 1
	return total


func count_color(color: int) -> int:
	var total := 0
	for c in _cells:
		if c == color:
			total += 1
	return total
