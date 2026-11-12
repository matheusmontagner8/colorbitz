## Lista de conquistas. Cada uma acompanha um valor de Progress.stat_value()
## e é liberada quando ele chega a "goal", dando "reward" em poderes.
## Lógica pura, sem interface.
extends RefCounted

const LIST := [
	{"id": "primeira_bomba", "title": "Bum!", "desc": "Crie sua primeira bomba", "stat": "bombs_created", "goal": 1, "reward": {"hammer": 1}},
	{"id": "mega_grupo", "title": "Mega grupo", "desc": "Estoure 15 blocos de uma vez", "stat": "best_group", "goal": 15, "reward": {"swap": 1}},
	{"id": "desafio_do_dia", "title": "Desafio do dia", "desc": "Vença a fase diária", "stat": "daily_wins", "goal": 1, "reward": {"swap": 1}},
	{"id": "britadeira", "title": "Britadeira", "desc": "Destrua 10 pedras", "stat": "stones", "goal": 10, "reward": {"hammer": 1}},
	{"id": "quebra_gelo", "title": "Quebra-gelo", "desc": "Rache 30 gelos", "stat": "ice", "goal": 30, "reward": {"hammer": 1}},
	{"id": "joalheiro", "title": "Joalheiro", "desc": "Leve 15 joias até o fundo", "stat": "gems", "goal": 15, "reward": {"swap": 1}},
	{"id": "estrategista", "title": "Estrategista", "desc": "Use 10 poderes", "stat": "powers", "goal": 10, "reward": {"swap": 1}},
	{"id": "na_raca", "title": "Na raça", "desc": "Vença 10 fases sem usar poderes", "stat": "wins_no_power", "goal": 10, "reward": {"hammer": 1}},
	{"id": "mil_blocos", "title": "Mil blocos", "desc": "Estoure 1000 blocos", "stat": "blocks", "goal": 1000, "reward": {"swap": 1}},
	{"id": "demolidor", "title": "Demolidor", "desc": "Crie 25 bombas", "stat": "bombs_created", "goal": 25, "reward": {"hammer": 1, "swap": 1}},
	{"id": "perfeccionista", "title": "Perfeccionista", "desc": "Ganhe 3 estrelas em 15 fases", "stat": "three_stars", "goal": 15, "reward": {"hammer": 1, "swap": 1}},
	{"id": "toda_semana", "title": "Toda semana", "desc": "Abra o jogo 7 dias seguidos", "stat": "streak", "goal": 7, "reward": {"hammer": 1, "swap": 1}},
	{"id": "fiel", "title": "Fiel", "desc": "Vença 7 fases diárias", "stat": "daily_wins", "goal": 7, "reward": {"hammer": 1, "swap": 1}},
	{"id": "metade", "title": "Metade do caminho", "desc": "Vença a fase 30", "stat": "max_level", "goal": 30, "reward": {"hammer": 1, "swap": 1}},
	{"id": "mestre", "title": "Mestre Colorbitz", "desc": "Vença a fase 60", "stat": "max_level", "goal": 60, "reward": {"hammer": 2, "swap": 2}},
]


static func find(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}
