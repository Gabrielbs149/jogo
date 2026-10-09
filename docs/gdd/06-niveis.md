# 06 · Níveis

> Fases montadas no editor do Godot ou no editor de mapas do jogo (F2): `levels/<nome>/<nome>.tscn`.
> Toda fase usa `world/level.gd` (`Level`).

## Decisões fechadas
- **Começo calmo e pequeno**, e cada herói começa num lugar diferente (`Game.START_LEVELS`) (D019).
- **Arandu** (`levels/arandu/`): começo do Tico, cidade natal dele, **sem inimigos**; o portão norte leva a Ethera (D019, D027, refeita na D041).
- **Primeiro dia em Arandu (D059):** área pequena: o beco do Tico (barraco com marquise), a rua do portão, a praça da fonte; pontos: Seu Brás na esquina, padaria, celeiro (bico dos caixotes), banca de frutas (briga) e o **beco lateral** (fechado por um muro, ao sul do beco do Tico). As janelas acesas e as lanternas guiam de noite. Peças montadas por `tools/art/montar_prologo.gd`.
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
- [A DEFINIR] **Segredos, colecionáveis, caminhos opcionais?**

## Fases existentes
| Fase | Arquivo | O que tem | Estado |
|---|---|---|---|
| Arandu | `levels/arandu/arandu.tscn` | muralha 92 × 92 m com torres e portão ao norte; avenidas de pedra em cruz com postes acesos; **praça central** com chafariz numa plataforma de degraus, canteiros com árvore, bancos, estátuas, feira (frutas, verduras, pães, peixe), pelourinho; estalagem, taverna, padaria (missão da fome), ferreiro, casa do conselho e do mercador, capela com torre do sino; quarteirões de dentro com estábulo e cercado, moinho com horta, serraria, jardim com poço; casas no miolo com caminhos de terra; animais, fumaça nas chaminés; beco do Tico; floresta em volta | jogável; montada por `tools/art/montar_arandu.gd` + `montar_cena_tico.gd` + `montar_missao_padaria.gd` (rodar de novo apaga ajustes à mão) |
| Ruínas de Ethera | `levels/ethera/ethera.tscn` | acampamento + fogueira, 4 heróis esperando, 5 grupos de inimigos (2 de escaravelhos, 2 sentinelas, Último Guardião), pilares com inscrições; praça de pedra com anel de muros partidos, portal de colunas, trilha batida, capim seco | jogável; montada por `tools/art/montar_ethera.gd` (D035; rodar de novo apaga ajustes à mão na decoração) |
| Arena de Ethera | `levels/arenas/ethera_arena.tscn` | coração das ruínas: lajes e terra batida, muros partidos e colunas atrás dos inimigos, altar do selo partido com dois braseiros, penhascos no horizonte, capim seco; posições do jogador e de até 4 inimigos | jogável; decoração montada por `tools/art/montar_arena_ethera.gd` (D036) |

## Fluxo atual
Tela inicial → escolha do herói → prólogo → fase de início do herói (Tico: Arandu, com a cena do rato) → portão → Ethera → encontros → arena → volta ao mesmo ponto → Último Guardião → fim do capítulo.

## Dificuldade (D022)
Tico, 4 lutas por caso, vida cheia: 2 escaravelhos e sentinela — vence sempre (o jogador fraco termina com ~76% da vida). Último Guardião — bom no QTE 4/4 (65% da vida), médio 3/4 (33%), fraco 1/4. A vida não enche entre lutas (só na fogueira), então o desgaste soma até o chefe.
