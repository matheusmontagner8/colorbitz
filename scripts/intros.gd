## Cartões de apresentação: na primeira vez que o jogador encontra uma meta,
## uma peça especial ou um modo novo, um cartão explica como funciona (com
## desenho, texto grande e botão "Entendi!"). Cada um aparece uma vez só
## (fica salvo em Progress.tutorials como "intro:<id>").
## Lógica pura: o que mostrar e quando. O cartão em si é ui/intro_card.gd.
extends RefCounted

const Board = preload("res://scripts/board.gd")
const Endless = preload("res://scripts/endless.gd")

## id -> {title, text, icon}. "icon": lista de células para desenhar
## (cores 0..5 ou Board.BOMB/WILD/STONE/GEM; "ice"/"ice2" = bloco congelado;
## "goal" = cores da meta da fase; "hole" = buraco; "chest"/"crown"/"medal"/"flame" =
## ícones do modo infinito, ui/badge_icon.gd). Textos em português
## (traduzidos por data/lang/en.json); "%d" no texto da bomba = tamanho do grupo.
const CARDS := {
	"goal_score": {"title": "Meta de pontos", "icon": [0, 1, 2],
		"text": "Toque em grupos de 2 ou mais blocos\nda mesma cor que estejam encostados.\nCada grupo vale pontos: grupos grandes\nvalem muito mais! Alcance a meta antes\nque as jogadas acabem."},
	"goal_color": {"title": "Meta de cor", "icon": ["goal"],
		"text": "Estoure a quantidade pedida de blocos\ndesta cor antes que as jogadas acabem.\nO número no topo da tela mostra\nquantos você já estourou."},
	"goal_colors": {"title": "Meta dupla", "icon": ["goal"],
		"text": "Agora são duas cores! Estoure a\nquantidade pedida de cada uma.\nO topo da tela mostra quanto falta\nde cada cor."},
	"goal_clear": {"title": "Limpar o tabuleiro", "icon": [3, 4, 5],
		"text": "Estoure blocos até sobrar no máximo\na quantidade pedida. Cuidado com\nos blocos que ficam sozinhos:\neles não estouram com um toque."},
	"goal_drop": {"title": "Joias", "icon": [Board.GEM],
		"text": "Joias não estouram. Estoure os blocos\nque estão embaixo delas para que caiam.\nQuando uma joia chega à última linha,\nela é coletada."},
	"bomb": {"title": "Bomba!", "icon": [Board.BOMB],
		"text": "Você estourou um grupo grande\n(%d blocos ou mais) e o bloco que você\ntocou virou uma bomba. Toque nela para\nexplodir todos os blocos em volta!"},
	"wild": {"title": "Coringa", "icon": [Board.WILD],
		"text": "O coringa combina com qualquer cor.\nEncostado num grupo, ele entra no grupo\ne o deixa maior. Se você tocar nele,\nele escolhe a cor do maior grupo."},
	"stone": {"title": "Pedra", "icon": [Board.STONE],
		"text": "Pedras não estouram com um toque.\nSó a explosão de uma bomba ou o\nMartelo conseguem quebrá-las.\nElas caem como os outros blocos."},
	"ice": {"title": "Bloco congelado", "icon": ["ice"],
		"text": "Blocos congelados não podem ser tocados.\nEstoure um grupo encostado neles\npara quebrar o gelo e soltar o bloco."},
	"ice2": {"title": "Gelo grosso", "icon": ["ice2"],
		"text": "Este gelo é mais grosso: precisa de\ndois estouros encostados para quebrar.\nO primeiro estouro deixa o gelo rachado."},
	"holes": {"title": "Tabuleiro com buracos", "icon": [1, "hole", 2],
		"text": "Este tabuleiro tem buracos.\nOs blocos caem através deles\nnormalmente, como se não\nestivessem ali."},
	"daily": {"title": "Fase diária", "icon": [4, 0, 3],
		"text": "Um desafio novo todo dia, igual para\ntodos os jogadores. Você pode tentar\nquantas vezes quiser: a primeira vitória\ndo dia vale +1 Martelo e +1 Troca."},
	"endless": {"title": "Modo infinito", "icon": [5, 2, 1],
		"text": "Parabéns! Agora as fases continuam\npara sempre, cada uma com um desafio.\nAs estrelas continuam valendo poderes."},
	"endless_goals": {"title": "Metas do infinito", "icon": ["chest", "crown", "medal"],
		"text": "Cada estrela enche o baú: com 30\nestrelas ele abre e dá poderes.\nA cada 10 fases vem uma fase chefe.\nVencer chefes dá patentes: Bronze,\nPrata, Ouro e outras ainda maiores."},
	"boss": {"title": "Fase chefe!", "icon": ["crown"],
		"text": "Esta fase é mais difícil que as outras.\nA primeira vitória vale +2 Martelos\ne +2 Trocas, e alguns chefes dão\numa patente nova. Use seus poderes!"},
	"streak": {"title": "Sequência de vitórias", "icon": ["flame"],
		"text": "Vença fases novas do infinito uma\natrás da outra para fazer uma sequência.\nA cada 5 vitórias seguidas, ganhe\n+1 Martelo e +1 Troca. Perder, ou sair\nno meio da fase, zera a sequência."},
}

## Ordem em que aparecem quando uma fase traz várias novidades de uma vez.
const ORDER := ["daily", "endless", "endless_goals", "streak", "boss", "goal_score", "goal_color", "goal_colors", "goal_clear",
	"goal_drop", "holes", "stone", "wild", "ice", "ice2"]


static func key(id: String) -> String:
	return "intro:" + id


## Novidades da fase (meta, peças do tabuleiro, modo), na ordem de ORDER.
## Não inclui a bomba, que só aparece durante o jogo.
static func concepts_for(level: Dictionary, board, daily := false) -> Array:
	var found := {}
	if daily:
		found["daily"] = true
	if bool(level.get("endless", false)):
		found["endless"] = true
		found["endless_goals"] = true
		# A sequência só aparece depois da primeira fase (já com 1 vitória).
		if int(level.get("id", 0)) > Endless.FIRST_LEVEL:
			found["streak"] = true
	if bool(level.get("boss", false)):
		found["boss"] = true
	var goal_type := String(level.get("goal", {}).get("type", "score"))
	found["goal_" + goal_type] = true
	for y in board.height:
		for x in board.width:
			match board.get_cell(x, y):
				Board.HOLE:
					found["holes"] = true
				Board.STONE:
					found["stone"] = true
				Board.WILD:
					found["wild"] = true
			var ice: int = board.get_ice(x, y)
			if ice >= 2:
				found["ice2"] = true
			elif ice == 1:
				found["ice"] = true
	var result := []
	for id in ORDER:
		if found.has(id):
			result.append(id)
	return result


## Só as que o jogador ainda não viu.
static func unseen(ids: Array, progress) -> Array:
	return ids.filter(func(id): return not progress.tutorials.has(key(id)))


static func mark_seen(id: String, progress) -> void:
	progress.tutorials[key(id)] = true
