#!/bin/sh
# Gera data/levels.json. Edite a tabela e rode: sh tools/levels.sh
# Colunas: id cores jogadas meta valor(es) [| extras JSON]
#   metas: s PONTOS | c COR QTD | m COR:QTD,COR:QTD (várias cores) | k MAX_SOBRA (limpar) | d JOIAS (derrubar)
#   extras (opcional, depois de "|"): stones, wilds, ice, ice_hits, gems, mask (nome em level_loader.gd) e tip
# Portão = estrelas exigidas (via GATE_<id>).
GATE_10=22; GATE_20=46; GATE_30=70; GATE_40=94; GATE_50=118; GATE_60=142
out=data/levels.json
first=1
emit() { # id cores jogadas tipo a [b]
  id=$1; colors=$2; moves=$3; type=$4
  case $type in
    s) goal="{ \"type\": \"score\", \"target\": $5 }" ;;
    c) goal="{ \"type\": \"color\", \"color\": $5, \"count\": $6 }" ;;
    m) targets=$(echo "$5" | sed 's/\([0-9]\):\([0-9]*\)/"\1": \2/g; s/,/, /g')
       goal="{ \"type\": \"colors\", \"targets\": { $targets } }" ;;
    k) goal="{ \"type\": \"clear\", \"max_left\": $5 }" ;;
    d) goal="{ \"type\": \"drop\", \"count\": $5 }" ;;
    *) echo "fase $id: meta desconhecida '$type'" >&2; exit 1 ;;
  esac
  eval gate=\${GATE_$id:-}
  extra=""; [ -n "$gate" ] && extra=", \"stars_required\": $gate"
  [ -n "$frag" ] && extra="$extra, $frag"
  [ $first = 1 ] || printf ',\n' >> $out
  first=0
  printf '    { "id": %d, "width": 7, "height": 9, "colors": %d, "moves": %d, "goal": %s%s }' $id $colors $moves "$goal" "$extra" >> $out
}
printf '{\n  "levels": [\n' > $out
while read -r line; do
  case "$line" in ''|\#*) continue;; esac
  frag=""
  case "$line" in *"|"*) frag=$(echo "${line#*|}" | sed 's/^ *//; s/ *$//');; esac
  emit ${line%%|*}
done <<'TABLE'
# 3 cores: tutorial
1 3 15 s 800
2 3 15 s 1500
# 4 cores
3 4 18 c 0 9
4 4 18 s 1300
5 4 16 s 1500
6 4 16 c 2 10
7 4 15 s 1700
8 4 14 s 1800
9 4 14 c 1 11
10 4 13 s 1900
# 5 cores (entra o amarelo); entram a pedra (13) e o coringa (16)
11 5 18 s 900
12 5 18 c 4 7
13 5 17 s 950 | "stones": 3, "tip": "Pedras não estouram! Só a bomba\nou o Martelo conseguem quebrá-las."
14 5 16 s 1100
15 5 16 c 3 8
16 5 16 s 1250 | "wilds": 2, "tip": "Coringa! Ele combina com\nqualquer cor."
17 5 15 s 1150 | "stones": 3
18 5 15 c 4 8
19 5 14 s 1300 | "stones": 2, "wilds": 2
20 5 14 s 1350
# 6 cores (entra o vermelho); entram o gelo (23) e as joias (26)
21 6 17 s 750
22 6 15 c 5 6
23 6 15 s 850 | "ice": 5, "tip": "Blocos congelados! Estoure um\ngrupo ao lado para soltá-los."
24 6 14 s 1100 | "wilds": 2
25 6 14 c 2 7
26 5 20 d 2 | "gems": 2, "tip": "Leve as joias até o fundo!\nEstoure os blocos embaixo delas."
27 6 13 s 950 | "stones": 4
28 6 12 c 5 7
29 6 11 s 950 | "ice": 6, "stones": 2
30 6 11 s 1150
# Segunda metade: metas duplas (32), formatos (33), limpar (36), gelo grosso (38)
31 6 15 s 1000
32 6 14 m 0:5,3:5 | "tip": "Meta dupla: estoure as\nduas cores pedidas."
33 6 14 s 850 | "mask": "ampulheta", "tip": "Tabuleiro com formato! Os blocos\natravessam os buracos ao cair."
34 6 13 s 1100 | "ice": 6, "wilds": 2
35 6 13 c 3 7
36 6 12 k 29 | "tip": "Limpe o tabuleiro! Deixe no\nmáximo os blocos pedidos."
37 5 18 d 2 | "gems": 2, "wilds": 1
38 6 12 c 1 7 | "ice": 6, "ice_hits": 2, "tip": "Gelo grosso: precisa de\ndois estouros ao lado."
39 6 11 s 900 | "mask": "pilares"
40 6 14 s 1100
41 6 13 c 4 6
42 5 19 d 3 | "gems": 3
43 6 12 s 900 | "mask": "cantos", "stones": 3
44 6 12 m 2:6,5:6 | "wilds": 2
45 6 11 s 950 | "ice": 8, "ice_hits": 2
46 6 11 k 31 | "stones": 3
47 6 11 c 2 6 | "mask": "janela"
48 6 10 s 1150
49 6 10 s 1200 | "ice": 6, "wilds": 2, "stones": 2
50 6 13 s 1150
51 6 12 c 0 7
52 6 16 d 3 | "gems": 3, "mask": "ampulheta"
53 6 11 m 1:5,4:5 | "ice": 6, "ice_hits": 2
54 6 11 c 3 8 | "stones": 4
55 6 10 s 1150 | "mask": "cantos", "wilds": 2
56 6 10 k 27 | "mask": "pilares"
57 6 10 c 4 7 | "ice": 8, "ice_hits": 2
58 6 9 s 1150 | "stones": 4, "wilds": 2
59 5 17 d 3 | "gems": 3, "ice": 6
60 6 12 m 0:5,5:5 | "mask": "janela", "stones": 2, "ice": 6, "ice_hits": 2
TABLE
printf '\n  ]\n}\n' >> $out
echo "gerado $out"
