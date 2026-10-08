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
- **Editor de mapas dentro do jogo** (F2 ou tela inicial) para montar e testar fases (D023, refeito na D042):
  - **Biblioteca** à esquerda com foto de cada peça (592 peças em categorias: Prédios, Muralha, Praça e feira, Luzes, Natureza, Objetos, Animais, Gente e história, Inimigos, Peças de casa, Vila medieval, Masmorra, Objetos do kit, Natureza do kit, Comida, Itens de RPG, Jardim), busca e "Recentes"; aba "Na fase" com a árvore da fase.
  - **Grade ligada por padrão** (0,5 / 1 / 2 / 4 m; G liga, [ e ] trocam): prédios e muros encaixam pela **pegada** (o centro cai no meio das células ou na linha, conforme o tamanho, então as bordas ficam nas linhas). A pegada aparece pintada no chão: verde livre, vermelho batendo em outra estrutura, amarelo escolhida; com a medida em metros.
  - Estruturas pousam no chão; objetos podem ir em cima de mesa e balcão. Q/E giram 90° (Shift 15°) em volta do centro; setas andam 1 célula; C centraliza na grade; Alt solta da grade.
  - Barra de baixo mostra as teclas do que dá para fazer agora. Painel da direita com botões (girar, centralizar, duplicar, apagar) e os campos da peça.
  - Bug corrigido: a câmera do jogo (CameraRig) vinha marcada como atual na fase e tomava a vista do editor.
  - Miniaturas geradas por `tools/editor/gerar_icones.gd`; categorias e nomes em `editor/biblioteca.gd`.
- **Missões (D040):** conversa com escolhas numeradas (`ui/dialogue/`), testes de perícia do D&D 5.5 (d20 + bônus contra CD; 20 natural passa, 1 natural falha; a rolagem aparece na conversa), objetivo no canto de cima à direita, marca "!" em quem tem missão e seta onde entregar. O estado fica em `Game.flags` / `Game.items` / `Game.objective` e vai para o jogo salvo. Cada missão é um script em `world/quests/` ligado às pessoas da fase (Interactable com ação QUEST).
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
- **30 s (luta, D048):** escolher a ação → o d20 rola na tela e diz se acertou → se acertou, o desafio de tempo da habilidade (anel, barra, sequência, martelar ou segurar) diz quanto do dano entra → no turno do inimigo, ele rola contra a sua CA e, se acertar, você se defende do jeito que o golpe pede (aparar/esquivar, pular para o lado, combo de 3, finta). Ritmo, Postura (quebra) e Fúria do chefe.
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
