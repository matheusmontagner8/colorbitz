#!/bin/sh
# Gera data/levels.json. Edite a tabela e rode: sh tools/levels.sh
# Colunas: id cores jogadas meta(s=pontos|c=cor) valor [cor] ; portão = estrelas exigidas (opcional, via GATE_<id>)
GATE_10=20; GATE_20=42; GATE_30=64; GATE_40=86; GATE_50=108; GATE_60=130
out=data/levels.json
first=1
emit() { # id cores jogadas tipo a [b]
  id=$1; colors=$2; moves=$3; type=$4
  if [ "$type" = s ]; then goal="{ \"type\": \"score\", \"target\": $5 }"; else goal="{ \"type\": \"color\", \"color\": $5, \"count\": $6 }"; fi
  eval gate=\${GATE_$id:-}
  extra=""; [ -n "$gate" ] && extra=", \"stars_required\": $gate"
  [ $first = 1 ] || printf ',\n' >> $out
  first=0
  printf '    { "id": %d, "width": 7, "height": 9, "colors": %d, "moves": %d, "goal": %s%s }' $id $colors $moves "$goal" "$extra" >> $out
}
printf '{\n  "levels": [\n' > $out
while read -r line; do
  case "$line" in ''|\#*) continue;; esac
  emit $line
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
# 5 cores (entra o amarelo)
11 5 18 s 900
12 5 18 c 4 7
13 5 17 s 1000
14 5 16 s 1100
15 5 16 c 3 8
16 5 16 s 1200
17 5 15 s 1250
18 5 15 c 4 8
19 5 14 s 1300
20 5 14 s 1350
# 6 cores (entra o vermelho)
21 6 18 s 700
22 6 16 c 5 5
23 6 16 s 850
24 6 15 s 900
25 6 15 c 2 6
26 6 14 s 950
27 6 14 s 1000
28 6 13 c 5 6
29 6 12 s 1000
30 6 12 s 1100
# Segunda metade: 6 cores, menos jogadas e metas maiores
31 6 16 s 900
32 6 15 c 0 6
33 6 15 s 950
34 6 14 s 1000
35 6 14 c 3 6
36 6 13 s 1000
37 6 13 s 1050
38 6 13 c 1 6
39 6 12 s 1050
40 6 15 s 1000
41 6 14 c 4 6
42 6 14 s 1000
43 6 13 s 1050
44 6 13 c 5 7
45 6 12 s 1050
46 6 12 s 1100
47 6 12 c 2 7
48 6 11 s 1050
49 6 11 s 1100
50 6 14 s 1050
51 6 13 c 0 7
52 6 13 s 1100
53 6 12 s 1100
54 6 12 c 3 7
55 6 11 s 1100
56 6 11 s 1100
57 6 11 c 4 7
58 6 10 s 1050
59 6 10 s 1100
60 6 11 s 1150
TABLE
printf '\n  ]\n}\n' >> $out
echo "gerado $out"
