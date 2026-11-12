## Lógica pura do tabuleiro: sem nós, sem interface, totalmente testável.
##
## Coordenadas: x = coluna (0 à esquerda), y = linha (0 no topo).
## A gravidade puxa os blocos para baixo (y maior) e, se [member collapse_columns]
## estiver ligado, colunas vazias se fecham para a esquerda.
##
## Valores de célula: cores (0..MAX_COLORS-1), EMPTY, HOLE (buraco de tabuleiros
## com formato) e especiais: BOMB, STONE (pedra), WILD (coringa) e GEM (joia).
## O gelo é uma camada à parte ([method get_ice]) que prende um bloco colorido.
extends RefCounted

const EMPTY := -1
## Célula que não existe (tabuleiros com formato). Os blocos "atravessam" buracos ao cair.
const HOLE := -2
const MIN_GROUP := 2
const MAX_COLORS := 10
## Bomba (poder especial).
const BOMB := 99
## Pedra: não forma grupo; só sai com bomba ou Martelo.
const STONE := 98
## Coringa: combina com qualquer cor.
const WILD := 97
## Joia: não estoura; é coletada ao chegar no fundo da coluna (meta "drop").
const GEM := 96
## Tamanho padrão de grupo que deixa uma bomba (veja [method bomb_size_for_colors]).
const DEFAULT_BOMB_GROUP_SIZE := 8
## Raio da explosão (1 = área 3x3 em volta da bomba).
const BOMB_RADIUS := 1
const BOMB_POINTS_PER_BLOCK := 50
const GEM_POINTS := 200
## Quantos blocos ficam embaixo de cada joia no começo da fase.
const GEM_START_DEPTH := 2
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## Caracteres de [method load_rows] / [method to_rows] para as células que não são cores.
const CHARS := {EMPTY: ".", HOLE: "x", BOMB: "B", STONE: "S", WILD: "W", GEM: "G"}

var width: int
var height: int
## Decisão de design (seção 9.1): colunas vazias se fecham para o lado.
## Tabuleiros com buracos desligam isso (veja [method apply_mask]).
var collapse_columns := true
## Grupos deste tamanho ou maiores deixam uma bomba no lugar do bloco tocado.
var bomb_group_size := DEFAULT_BOMB_GROUP_SIZE

var _cells := PackedInt32Array()
## Quantos estouros vizinhos ainda faltam para soltar o bloco (0 = sem gelo).
var _ice := PackedInt32Array()


func _init(w: int = 7, h: int = 9) -> void:
	width = w
	height = h
	_cells.resize(w * h)
	_cells.fill(EMPTY)
	_ice.resize(w * h)
	_ice.fill(0)


static func is_color(c: int) -> bool:
	return c >= 0 and c < MAX_COLORS


## Carrega o tabuleiro a partir de linhas de texto (útil em testes).
## Dígitos são cores; "." vazio, "x" buraco, "B" bomba, "S" pedra, "W" coringa, "G" joia.
func load_rows(rows: Array) -> void:
	height = rows.size()
	width = String(rows[0]).length() if height > 0 else 0
	_cells.resize(width * height)
	_ice.resize(width * height)
	_ice.fill(0)
	for y in height:
		var row := String(rows[y])
		assert(row.length() == width, "Todas as linhas devem ter o mesmo tamanho")
		for x in width:
			var ch := row[x]
			var value := ch.to_int()
			for k in CHARS:
				if CHARS[k] == ch:
					value = k
			_cells[y * width + x] = value


## Representação em texto, no mesmo formato de [method load_rows] (sem o gelo).
func to_rows() -> Array:
	var rows: Array = []
	for y in height:
		var row := ""
		for x in width:
			var c := get_cell(x, y)
			row += CHARS[c] if CHARS.has(c) else str(c)
		rows.append(row)
	return rows


## Formato do tabuleiro: "#" é célula, "." (ou espaço) é buraco.
func apply_mask(mask: Array) -> void:
	for y in mini(height, mask.size()):
		var row := String(mask[y])
		for x in mini(width, row.length()):
			if row[x] != "#":
				_cells[y * width + x] = HOLE
				_ice[y * width + x] = 0
	collapse_columns = false  # colunas com buracos diferentes não podem se fechar


## Preenche o tabuleiro com cores aleatórias, garantindo que exista ao menos uma jogada.
func fill_random(num_colors: int, rng: RandomNumberGenerator) -> void:
	_ice.fill(0)
	for _attempt in 100:
		for i in _cells.size():
			if _cells[i] != HOLE:
				_cells[i] = rng.randi_range(0, num_colors - 1)
		if has_moves():
			return


## Coloca os especiais da fase sobre um tabuleiro já preenchido:
## {gems, stones, wilds, ice, ice_hits}. Joias começam no meio de colunas
## diferentes, fora das bordas (com uns 2 blocos embaixo); pedras longe do
## topo. Garante uma jogada no final.
func place_specials(spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var gem_columns: Array = []
	# Nas bordas a coluna tem menos vizinhos e quase não forma grupos: injusto.
	for x in range(1, width - 1) if width >= 5 else range(width):
		if _column_cells(x).size() >= 3:
			gem_columns.append(x)
	for x in _pick(gem_columns, int(spec.get("gems", 0)), rng):
		var column := _column_cells(x)
		var spot: Vector2i = column[mini(GEM_START_DEPTH, column.size() - 1)]
		set_cell(spot.x, spot.y, GEM)
	var low: Array = []
	for p in _cells_where(func(c): return is_color(c)):
		if p.y >= 2:
			low.append(p)
	for p in _pick(low, int(spec.get("stones", 0)), rng):
		set_cell(p.x, p.y, STONE)
	for p in _pick(_cells_where(func(c): return is_color(c)), int(spec.get("wilds", 0)), rng):
		set_cell(p.x, p.y, WILD)
	var hits := maxi(1, int(spec.get("ice_hits", 1)))
	for p in _pick(_cells_where(func(c): return is_color(c)), int(spec.get("ice", 0)), rng):
		set_ice(p.x, p.y, hits)
	if not has_moves():
		shuffle(rng)


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func get_cell(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return EMPTY
	return _cells[y * width + x]


func set_cell(x: int, y: int, color: int) -> void:
	if in_bounds(x, y):
		_cells[y * width + x] = color


## Esvazia a célula (e tira o gelo). Buracos continuam buracos.
func clear_cell(x: int, y: int) -> void:
	if in_bounds(x, y) and _cells[y * width + x] != HOLE:
		_cells[y * width + x] = EMPTY
		_ice[y * width + x] = 0


func get_ice(x: int, y: int) -> int:
	return _ice[y * width + x] if in_bounds(x, y) else 0


func set_ice(x: int, y: int, hits: int) -> void:
	if in_bounds(x, y):
		_ice[y * width + x] = maxi(0, hits)


func is_frozen(x: int, y: int) -> bool:
	return get_ice(x, y) > 0


## Retorna todas as posições conectadas (cima/baixo/esquerda/direita) com a
## mesma cor, incluindo coringas. Blocos congelados não participam.
## Tocar num coringa escolhe a cor vizinha que forma o maior grupo.
func find_group(x: int, y: int) -> Array[Vector2i]:
	return _group_at(x, y).cells


func _group_at(x: int, y: int) -> Dictionary:
	var none: Array[Vector2i] = []
	var c := get_cell(x, y)
	if is_frozen(x, y) or not (is_color(c) or c == WILD):
		return {"cells": none, "color": EMPTY}
	var p := Vector2i(x, y)
	if is_color(c):
		return {"cells": _flood(p, c), "color": c}
	var best: Array[Vector2i] = none
	var best_color := EMPTY
	for color in MAX_COLORS:
		var g := _flood(p, color)
		if g.size() > best.size() and g.any(func(q): return get_cell(q.x, q.y) == color):
			best = g
			best_color = color
	return {"cells": best, "color": best_color}


func _joins(p: Vector2i, color: int) -> bool:
	var c := get_cell(p.x, p.y)
	return (c == color or c == WILD) and not is_frozen(p.x, p.y)


func _flood(start: Vector2i, color: int) -> Array[Vector2i]:
	var group: Array[Vector2i] = []
	var visited := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		group.append(p)
		for d in DIRS:
			var n := p + d
			if not visited.has(n) and _joins(n, color):
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
##   size (int: blocos destruídos),
##   removed (Array[Vector2i]: posições que somem, antes da gravidade),
##   removed_colors (Dictionary cor -> quantidade, para metas de cor),
##   points (int),
##   bomb (Vector2i: onde nasceu uma bomba, ou null),
##   exploded (Array[Vector2i]: bombas que explodiram),
##   iced (Array[Vector2i]: gelos que racharam, antes da gravidade),
##   gems (Array de {from, to}: joias coletadas; from = posição antes do toque,
##         to = fundo da coluna onde foram coletadas),
##   moves (Array de {from: Vector2i, to: Vector2i}) para animação.
## Se o toque for inválido (vazio, isolado, pedra, joia, gelo), retorna {} e nada muda.
func tap(x: int, y: int) -> Dictionary:
	if get_cell(x, y) == BOMB:
		return _explode(x, y)
	var g := _group_at(x, y)
	var group: Array[Vector2i] = g.cells
	if group.size() < MIN_GROUP:
		return {}
	var color: int = g.color
	var bomb_at = null
	var removed: Array[Vector2i] = []
	for p in group:
		if group.size() >= bomb_group_size and p == Vector2i(x, y):
			set_cell(p.x, p.y, BOMB)  # o bloco tocado vira bomba
			bomb_at = p
		else:
			clear_cell(p.x, p.y)
			removed.append(p)
	var iced := _crack_ice_around(group)
	return _result(color, group.size(), removed, {color: group.size()}, points_for(group.size()), bomb_at, [], iced)


## Estouros racham o gelo dos vizinhos (uma vez por toque).
func _crack_ice_around(group: Array[Vector2i]) -> Array[Vector2i]:
	var in_group := {}
	for p in group:
		in_group[p] = true
	var cracked: Array[Vector2i] = []
	for p in group:
		for d in DIRS:
			var n := p + d
			if not in_group.has(n) and is_frozen(n.x, n.y) and not cracked.has(n):
				set_ice(n.x, n.y, get_ice(n.x, n.y) - 1)
				cracked.append(n)
	return cracked


## Monta o resultado e aplica gravidade (com coleta de joias).
func _result(color: int, size: int, removed: Array[Vector2i], removed_colors: Dictionary,
		points: int, bomb_at, exploded: Array, iced: Array[Vector2i]) -> Dictionary:
	var settled := _resolve()
	return {
		"color": color,
		"size": size,
		"removed": removed,
		"removed_colors": removed_colors,
		"points": points + settled.gems.size() * GEM_POINTS,
		"bomb": bomb_at,
		"exploded": exploded,
		"iced": iced,
		"gems": settled.gems,
		"moves": settled.moves,
	}


## Células atingidas ao explodir a bomba em (x, y), incluindo explosões em
## cadeia de outras bombas dentro da área. Joias e buracos não são atingidos.
## Não altera o tabuleiro. Retorna {cells: Array[Vector2i], bombs: Array[Vector2i]}.
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
				if c == EMPTY or c == HOLE or c == GEM:
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
		if is_color(c):
			removed_colors[c] = int(removed_colors.get(c, 0)) + 1
		if c != BOMB:
			destroyed += 1
		clear_cell(p.x, p.y)
	var none: Array[Vector2i] = []
	return _result(BOMB, destroyed, removed, removed_colors, destroyed * BOMB_POINTS_PER_BLOCK, null, area.bombs, none)


## Poder "Martelo": destrói um único bloco, sem precisar de grupo (inclusive
## pedra, coringa e bloco congelado). Numa bomba, ela explode. Joias não.
## Retorna o mesmo formato de [method tap] ({} se não houver o que destruir).
func smash(x: int, y: int) -> Dictionary:
	var c := get_cell(x, y)
	if c == EMPTY or c == HOLE or c == GEM:
		return {}
	if c == BOMB:
		return _explode(x, y)
	clear_cell(x, y)
	var removed: Array[Vector2i] = [Vector2i(x, y)]
	var none: Array[Vector2i] = []
	return _result(c, 1, removed, {c: 1} if is_color(c) else {}, BOMB_POINTS_PER_BLOCK, null, [], none)


## Poder "Troca": troca dois blocos de lugar (o gelo vai junto).
## Retorna false se alguma célula estiver vazia, for buraco, joia, fora do
## tabuleiro ou se for a mesma.
func swap(a: Vector2i, b: Vector2i) -> bool:
	var ca := get_cell(a.x, a.y)
	var cb := get_cell(b.x, b.y)
	if a == b or not _swappable(ca) or not _swappable(cb):
		return false
	var ia := get_ice(a.x, a.y)
	set_cell(a.x, a.y, cb)
	set_ice(a.x, a.y, get_ice(b.x, b.y))
	set_cell(b.x, b.y, ca)
	set_ice(b.x, b.y, ia)
	return true


static func _swappable(c: int) -> bool:
	return c != EMPTY and c != HOLE and c != GEM


## Embaralha as cores dos blocos coloridos soltos (especiais e congelados
## ficam no lugar) até existir uma jogada. Retorna false se for impossível:
## aí o tabuleiro fica como estava.
func shuffle(rng: RandomNumberGenerator) -> bool:
	if not bombs().is_empty():
		return true  # bomba já é jogada
	var cells: Array[Vector2i] = []
	for p in _cells_where(func(c): return is_color(c)):
		if not is_frozen(p.x, p.y):
			cells.append(p)
	var values: Array[int] = []
	var per_color := {}
	for p in cells:
		var c := get_cell(p.x, p.y)
		values.append(c)
		per_color[c] = int(per_color.get(c, 0)) + 1
	var original := values.duplicate()
	var pair_color := EMPTY
	for c in per_color:
		if per_color[c] >= MIN_GROUP:
			pair_color = c
			break
	var has_wild := not _cells_where(func(c): return c == WILD).is_empty()
	if pair_color == EMPTY and not has_wild:
		return false
	for _attempt in 30:
		_shuffle_values(values, rng)
		_write(cells, values)
		if has_moves():
			return true
	# Sorte ruim: coloca dois blocos da mesma cor em células vizinhas.
	if pair_color != EMPTY:
		for i in cells.size():
			for d in [Vector2i.RIGHT, Vector2i.DOWN]:
				var j := cells.find(cells[i] + d)
				if j < 0:
					continue
				_swap_values(values, i, values.find(pair_color))
				var k := values.find(pair_color)
				if k == i:
					k = values.find(pair_color, i + 1)
				_swap_values(values, j, k)
				_write(cells, values)
				return has_moves()
	_write(cells, original)
	return false


func _write(cells: Array[Vector2i], values: Array) -> void:
	for i in cells.size():
		set_cell(cells[i].x, cells[i].y, values[i])


## Fisher-Yates com o rng dado (Array.shuffle usaria o rng global).
static func _shuffle_values(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		_swap_values(values, i, rng.randi_range(0, i))


static func _swap_values(values: Array, i: int, j: int) -> void:
	var tmp = values[i]
	values[i] = values[j]
	values[j] = tmp


## Escolhe n itens aleatórios distintos de [param items].
static func _pick(items: Array, n: int, rng: RandomNumberGenerator) -> Array:
	var copy := items.duplicate()
	_shuffle_values(copy, rng)
	return copy.slice(0, mini(n, copy.size()))


func _cells_where(pred: Callable) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in height:
		for x in width:
			if pred.call(get_cell(x, y)):
				result.append(Vector2i(x, y))
	return result


## Células (não buraco) da coluna, de baixo para cima.
func _column_cells(x: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(height - 1, -1, -1):
		if get_cell(x, y) != HOLE:
			result.append(Vector2i(x, y))
	return result


## Posições de todas as bombas no tabuleiro.
func bombs() -> Array[Vector2i]:
	return _cells_where(func(c): return c == BOMB)


## Aplica gravidade (e coleta joias). Retorna a lista de blocos que mudaram de posição.
func settle() -> Array:
	return _resolve().moves


## Gravidade + fechamento de colunas + coleta de joias que chegam ao fundo,
## repetindo até estabilizar. Cada célula carrega um "id" (sua posição
## original) para que os movimentos saiam de onde o bloco estava antes.
func _resolve() -> Dictionary:
	var ids := PackedInt32Array()
	ids.resize(_cells.size())
	for i in ids.size():
		ids[i] = i
	var gems: Array = []
	while true:
		ids = _settle(ids)
		var collected := false
		for x in width:
			var column := _column_cells(x)
			if column.is_empty():
				continue
			var bottom: Vector2i = column[0]
			if get_cell(bottom.x, bottom.y) == GEM:
				var orig := ids[bottom.y * width + bottom.x]
				gems.append({"from": Vector2i(orig % width, orig / width), "to": bottom})
				clear_cell(bottom.x, bottom.y)
				collected = true
		if not collected:
			break
	var moves: Array = []
	for x in width:
		for y in range(height - 1, -1, -1):
			var i := y * width + x
			var c := _cells[i]
			if c == EMPTY or c == HOLE or ids[i] == i:
				continue
			moves.append({"from": Vector2i(ids[i] % width, ids[i] / width), "to": Vector2i(x, y)})
	return {"moves": moves, "gems": gems}


## Uma passada de gravidade: em cada coluna os blocos descem para as células
## livres (pulando buracos); colunas vazias se fecham se [member collapse_columns].
func _settle(ids: PackedInt32Array) -> PackedInt32Array:
	var new_cells := PackedInt32Array()
	new_cells.resize(_cells.size())
	new_cells.fill(EMPTY)
	var new_ice := PackedInt32Array()
	new_ice.resize(_cells.size())
	var new_ids := PackedInt32Array()
	new_ids.resize(_cells.size())
	new_ids.fill(-1)
	for i in _cells.size():
		if _cells[i] == HOLE:
			new_cells[i] = HOLE
	var dest_x := 0
	for x in width:
		var stack: Array[int] = []  # índices dos blocos da coluna, de baixo para cima
		for p in _column_cells(x):
			var i := p.y * width + p.x
			if _cells[i] != EMPTY:
				stack.append(i)
		if stack.is_empty() and collapse_columns:
			continue
		var slots := _column_cells(dest_x)
		for k in stack.size():
			var src := stack[k]
			var dst: int = slots[k].y * width + slots[k].x
			new_cells[dst] = _cells[src]
			new_ice[dst] = _ice[src]
			new_ids[dst] = ids[src]
		dest_x += 1
	_cells = new_cells
	_ice = new_ice
	return new_ids


## Todos os grupos válidos (2+ blocos) do tabuleiro. Bombas e especiais não
## iniciam grupos; coringas podem aparecer em mais de um grupo.
func all_groups() -> Array:
	var seen := {}
	var groups := []
	for y in height:
		for x in width:
			var p := Vector2i(x, y)
			var c := get_cell(x, y)
			if seen.has(p) or not is_color(c) or is_frozen(x, y):
				continue
			var g := _flood(p, c)
			for q in g:
				if get_cell(q.x, q.y) == c:
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
			if c == BOMB:
				return true
			if not is_color(c) or is_frozen(x, y):
				continue
			for d in DIRS:
				if _joins(Vector2i(x, y) + d, c):
					return true
	return false


## Blocos no tabuleiro (tudo que não é vazio nem buraco).
func count_blocks() -> int:
	var total := 0
	for c in _cells:
		if c >= 0:
			total += 1
	return total


func count_color(color: int) -> int:
	var total := 0
	for c in _cells:
		if c == color:
			total += 1
	return total
