# 06 · Níveis

> Fases montadas no editor do Godot ou no editor de mapas do jogo (F2): `levels/<nome>/<nome>.tscn`.
> Toda fase usa `world/level.gd` (`Level`).

## Decisões fechadas
- **Começo calmo e pequeno**, e cada herói começa num lugar diferente (`Game.START_LEVELS`) (D019).
- **Arandu** (`levels/arandu/`): começo do Tico, cidade natal dele, **sem inimigos**; o portão norte leva a Ethera (D019, D027).
- **Ruínas de Ethera** (`levels/ethera/`): acampamento com fogueira ao sul, heróis esperando pelo caminho, grupos de inimigos e as ruínas no centro com o **Último Guardião** (D013, D018, D022).
- **Arena de Ethera** (`levels/arenas/ethera_arena.tscn`): onde todas as lutas de Ethera acontecem (D022).
- **Estrutura da campanha:** um Astro por capítulo, cada um com arena, servos e regra de batalha própria (HISTORIA / D013).
- **Editor de mapas no jogo** para montar e testar fases (D023).
- **Dificuldade medida por simulação** (`tools/simulate_arena.gd`, três perfis de jogador; números na D022).

## Em aberto
- [A DEFINIR] **Fases de início** de Namfoodle, Chumasso, José Maria e Bahamut (hoje os quatro começam em Ethera).
- [A DEFINIR] **Capítulos depois de Ethera:** quais Astros, em que ordem, que lugares?
- [A DEFINIR] **Acampamento** com Caiaque, Umu e Juca entre capítulos *(proposta)*: é uma fase própria?
- [A DEFINIR] **Curva de dificuldade:** hoje o chefe de Ethera vence o jogador "fraco" no QTE 3 de 4 vezes. É o alvo? Dificuldade selecionável?
- [A DEFINIR] **Tamanho e duração** de cada fase (minutos de jogo).
- [A DEFINIR] **Arenas próprias** por capítulo/chefe ou uma arena genérica por região?
- [A DEFINIR] **Ethera** precisa do mesmo replanejamento visual que Arandu teve? (ver [04-arte.md](04-arte.md))
- [A DEFINIR] **Segredos, colecionáveis, caminhos opcionais?**

## Fases existentes
| Fase | Arquivo | O que tem | Estado |
|---|---|---|---|
| Arandu | `levels/arandu/arandu.tscn` | muralha 70 × 70 m com torres e portão; ruas em cruz; praça com poço e feira; taverna, conselho, mercador, capela, ferraria; beco do Tico com a cena de abertura; 4 moradores com fala + figurantes; floresta em volta | jogável; montada por `tools/art/montar_arandu.gd` (rodar de novo apaga ajustes à mão) |
| Ruínas de Ethera | `levels/ethera/ethera.tscn` | acampamento + fogueira, 4 heróis esperando, 5 grupos de inimigos (2 de escaravelhos, 2 sentinelas, Último Guardião), pilares com inscrições | jogável, visual ainda da primeira versão |
| Arena de Ethera | `levels/arenas/ethera_arena.tscn` | altar partido, posições do jogador e de até 4 inimigos | jogável |

## Fluxo atual
Tela inicial → escolha do herói → prólogo → fase de início do herói (Tico: Arandu, com a cena do rato) → portão → Ethera → encontros → arena → volta ao mesmo ponto → Último Guardião → fim do capítulo.

## Dificuldade (D022)
Tico, 4 lutas por caso, vida cheia: 2 escaravelhos e sentinela — vence sempre (o jogador fraco termina com ~76% da vida). Último Guardião — bom no QTE 4/4 (65% da vida), médio 3/4 (33%), fraco 1/4. A vida não enche entre lutas (só na fogueira), então o desgaste soma até o chefe.
