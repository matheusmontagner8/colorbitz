## Lógica pura do tabuleiro: sem nós, sem interface, totalmente testável.
##
## Coordenadas: x = coluna (0 à esquerda), y = linha (0 no topo).
## A gravidade puxa os blocos para baixo (y maior) e, se [member collapse_columns]
## estiver ligado, colunas vazias se fecham para a esquerda.
extends RefCounted

const EMPTY := -1
const MIN_GROUP := 2
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var width: int
var height: int
## Decisão de design (seção 9.1): colunas vazias se fecham para o lado.
var collapse_columns := true

var _cells := PackedInt32Array()


func _init(w: int = 7, h: int = 9) -> void:
	width = w
	height = h
	_cells.resize(w * h)
	_cells.fill(EMPTY)


## Carrega o tabuleiro a partir de linhas de texto (útil em testes).
## Cada caractere é um dígito de cor ("0".."9") ou "." para vazio.
func load_rows(rows: Array) -> void:
	height = rows.size()
	width = String(rows[0]).length() if height > 0 else 0
	_cells.resize(width * height)
	for y in height:
		var row := String(rows[y])
		assert(row.length() == width, "Todas as linhas devem ter o mesmo tamanho")
		for x in width:
			var ch := row[x]
			_cells[y * width + x] = EMPTY if ch == "." else ch.to_int()


## Representação em texto, no mesmo formato de [method load_rows].
func to_rows() -> Array:
	var rows: Array = []
	for y in height:
		var row := ""
		for x in width:
			var c := get_cell(x, y)
			row += "." if c == EMPTY else str(c)
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


static func points_for(group_size: int) -> int:
	return group_size * group_size * 10


## Executa um toque. Se o grupo for válido, remove os blocos, aplica gravidade
## e retorna um dicionário com:
##   color (int), removed (Array[Vector2i]), points (int),
##   moves (Array de {from: Vector2i, to: Vector2i}) para animação.
## Se o toque for inválido (vazio ou bloco isolado), retorna {} e nada muda.
func tap(x: int, y: int) -> Dictionary:
	var group := find_group(x, y)
	if group.size() < MIN_GROUP:
		return {}
	var color := get_cell(x, y)
	for p in group:
		set_cell(p.x, p.y, EMPTY)
	var moves := settle()
	return {
		"color": color,
		"removed": group,
		"points": points_for(group.size()),
		"moves": moves,
	}


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


## Existe ao menos um grupo de 2 ou mais blocos?
func has_moves() -> bool:
	for y in height:
		for x in width:
			var c := get_cell(x, y)
			if c == EMPTY:
				continue
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
