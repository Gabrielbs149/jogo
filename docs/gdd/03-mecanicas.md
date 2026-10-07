# 03 · Mecânicas

> Números de batalha moram nos `.tres` e no Inspector (`Combatant`, `Ability`, `BattleArena`), não no código.
> Mexeu em número? Rode `tools/simulate_arena.gd` e registre o resultado em [decisoes.md](decisoes.md).

## Decisões fechadas
- **Exploração em 3ª pessoa** com câmera atrás do ombro (D018). **Luta por turnos numa arena separada**, só com o seu personagem, com QTE (D022).
- **Regras de D&D 5.5:** d20 + bônus contra CA (20 crítico, 1 erra), vantagem/desvantagem (2d20), salvamentos, ataque furtivo, Bênção, Marca do caçador, Amedrontado, Invisível. Efeitos duram **turnos** na arena (D018, D022).
- **Recrutar:** os outros heróis esperam pela fase; F conversa e você decide se chama. Quem entra segue você, mas fica fora da luta (D018, D022).
- **Encontros:** inimigos parados em grupos no mapa; encostar = luta. Acertar um antes com o botão esquerdo = **primeiro golpe** (você joga primeiro e ganha +1 PA). Vencido, o grupo some; perdeu, volta ao começo da fase com vida cheia (D022).
- **Vida entre lutas:** não enche sozinha; a **fogueira** (F) enche (D022).
- **Cenas de história** por roteiro (D025); prólogo em todo jogo novo.
- **Editor de mapas dentro do jogo** (F2 ou tela inicial) para montar e testar fases (D023).
- **Jogo salvo (D037):** um arquivo só (`user://save.json`), gravado sozinho ao entrar numa fase, ao voltar de uma luta, ao descansar na fogueira ("Jogo salvo") e ao sair para o menu ou fechar o jogo. Nunca grava no meio de uma luta nem no Testar do editor. Guarda herói, grupo, lutas vencidas, vida, fases já vistas e o lugar no mapa. Tela inicial: **Continuar** (só aparece se tem jogo salvo) e **Novo jogo** (começa do zero e grava por cima).

## Em aberto
- [A DEFINIR] **Progressão:** o herói sobe de nível? Ganha habilidades novas? Itens/equipamento? Dinheiro? O que se ganha ao vencer um Astro?
- [A DEFINIR] **Recrutados:** se não lutam, para que servem? (bônus fora da luta? conversa? troca de herói entre capítulos?)
- [A DEFINIR] **Morte e derrota:** só "volta ao começo da fase" ou checkpoints? Dificuldade selecionável?
- [A DEFINIR] **QTE:** janelas atuais (perfeito ±0,08 s, bom ±0,2 s, esquiva ±0,15 s, aparar ±0,08 s) estão boas? Opção de acessibilidade (janela maior / QTE automático)?
- [A DEFINIR] **Habilidades no mapa:** hoje Q/E/R só funcionam na luta. Fica assim?
- [A DEFINIR] **Controle (gamepad):** suportar? Qual mapeamento?
- [A DEFINIR] **Jogo salvo:** mais de um espaço (um por herói?) ou salvar à mão? Avisar antes do "Novo jogo" apagar o salvo?
- [A DEFINIR] **Break/stagger, mira livre, mecânica própria de cada herói** — citados como "talvez depois", nunca decididos.

## Core loop
- **30 s (luta):** escolher ação (ataque ganha PA, habilidade gasta PA) → acertar o tempo do anel (Espaço) para ter vantagem → no turno do inimigo, esquivar (Espaço) ou aparar (F) no tempo certo.
- **5–10 min (fase):** explorar, ler inscrições, conversar, achar heróis, escolher quando encarar cada grupo de inimigos (ou pegar o primeiro golpe), descansar na fogueira.
- **Sessão:** um capítulo: cena de abertura → caminho → chefe (Astro/guardião) → próxima fase *(estrutura da campanha; detalhe em aberto)*.

## Controles
| Ação | Exploração | Arena |
|---|---|---|
| Andar / correr | WASD ou setas / Shift | — |
| Câmera | mouse (fica preso; Esc solta) | fixa |
| Golpe | botão esquerdo (no mapa: primeiro golpe num grupo) | **1** ou Enter = ataque (+1 PA) |
| Habilidades | — (aviso "são usadas na luta") | **Q / E / R** (custam PA) |
| Trocar alvo | — | A / D |
| QTE no golpe | — | **Espaço** quando o anel fecha |
| Defesa | — | **Espaço** esquiva · **F** (ou botão direito) apara |
| Esquiva | Espaço | — |
| Interagir | **F** (ler, conversar, descansar, viajar, chamar herói) | — |
| Pausa | Esc | — |
| Editor de mapas | **F2** | — |
| Cenas | Espaço / F / clique passam; Esc pula | |

## Sistemas
- **Arena** (`battle/battle_arena.gd`): ordem por iniciativa (d20 + DES). PA começa em 2, máximo 9. Habilidade custa `ap_cost`.
  - QTE no golpe: perfeito = vantagem; bom = normal; errou = desvantagem. Em habilidade de salvamento, perfeito dá desvantagem ao inimigo no salvamento.
  - Defesa: esquiva no tempo = o golpe erra (área não pega); aparar no tempo = sem dano, contra-ataque com vantagem e +1 PA; perdeu o tempo = d20 normal contra a sua CA.
- **Mapa:** `Encounter` (grupo → arena), `Interactable` (ler / descansar / conversar / viajar), `HeroSpot` (herói esperando). Estado entre cenas no autoload `Game`.
- **Simulação de equilíbrio** (D022): Tico, 4 lutas por caso — 2 escaravelhos e sentinela: vence sempre; Último Guardião: bom no QTE 4/4 (sobra 65% da vida), médio 3/4, fraco 1/4.

## Progressão
[A DEFINIR] Ainda não existe sistema de progressão no jogo. Ver *Em aberto*.
