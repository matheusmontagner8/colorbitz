# Pop Blocks

[![Testes](https://github.com/matheusmontagner8/pop-blocks/actions/workflows/tests.yml/badge.svg)](https://github.com/matheusmontagner8/pop-blocks/actions/workflows/tests.yml)

Puzzle casual para celular feito em **Godot 4** com **GDScript**. Toque em grupos
de blocos da mesma cor para removê-los e cumpra a meta da fase antes de acabarem
as jogadas.

<p align="center"><img src="docs/screenshot.png" width="300" alt="Tela do jogo"></p>

> Projeto em desenvolvimento: este é o MVP do meu primeiro jogo para Android.
> O nome "Pop Blocks" é provisório.

## Como jogar

- Toque em um bloco: ele e todos os vizinhos da mesma cor (cima, baixo, esquerda,
  direita) somem, se o grupo tiver 2 ou mais blocos.
- Os blocos de cima caem e as colunas vazias se fecham para a esquerda.
- Pontos por jogada: `n × n × 10`, em que `n` é o tamanho do grupo. Grupos maiores valem bem mais.
- Cada fase tem uma meta (pontuação ou "remover X blocos de uma cor") e um limite de jogadas.
- Tocar em um bloco isolado não gasta jogada.
- Cada cor tem também um ícone próprio (●, ■, ▲, ◆…), para que quem tem daltonismo jogue sem problema.

## Destaques técnicos

- **Lógica separada da interface**: [`scripts/board.gd`](scripts/board.gd) e
  [`scripts/game_session.gd`](scripts/game_session.gd) são classes puras (sem nós
  de cena), então dá para testá-las isoladamente.
- **Fases em dados**: todas as fases ficam em [`data/levels.json`](data/levels.json),
  nenhuma é escrita no código.
- **Testes automatizados** com um executor próprio e leve, rodando em modo headless
  no GitHub Actions a cada push.
- Animações com `Tween`, protegidas contra reinício de fase no meio da animação.

## Rodando o projeto

1. Instale o [Godot 4.7+](https://godotengine.org/download) (versão padrão, não a .NET).
2. Clone o repositório e abra o `project.godot` no editor.
3. Pressione **F5**.

### Testes

```bash
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
```

### Captura de tela / teste de fumaça da interface

```bash
godot --path . -s tools/screenshot.gd -- res://docs/screenshot.png
```

## Estrutura

```
data/      fases (levels.json)
docs/      imagens do README
scenes/    cenas do Godot
scripts/   lógica do jogo (board, game_session, level_loader) e interface
tests/     testes da lógica e executor
tools/     scripts utilitários
```

## Roteiro

- [x] **Semana 1**: tabuleiro, remoção de grupos, gravidade, pontuação e testes
- [ ] **Semana 2**: menu, seleção de fases, pausa, resultado e progresso salvo
- [ ] **Semana 3**: arte, sons, música e as 30 fases balanceadas
- [ ] **Semana 4**: anúncios e publicação na Google Play (teste fechado)

## Licença

Código sob a licença [MIT](LICENSE).
