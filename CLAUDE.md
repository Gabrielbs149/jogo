# CLAUDE.md

Regras do projeto para os **dois** Claudes: o do Gabriel e o do John. Cada um roda na própria conta, no próprio clone. Vocês **não compartilham memória nem conversa**: o que precisa valer para os dois mora no repo (aqui, em `docs/`, nas issues e no histórico do Git).

## O jogo em resumo
- **"A Noite Sem Nome" / Plano do Fogo:** RPG 3D baseado na campanha de RPG de mesa do grupo, em Novazul. Você escolhe 1 de 5 heróis (Tico-Lirou, Naumfode, Chumasso, José Maria, Bahamut), começa sozinho no lugar de origem dele e encontra os outros pelo caminho.
- **Exploração em 3ª pessoa** (WASD + mouse) e **luta por turnos com QTE numa arena separada**, estilo Clair Obscur, com regras de D&D 5.5 (d20, vantagem, salvamentos). Na luta, só o seu personagem.
- **Visual estilizado:** kits Quaternius (cenário) + KayKit (moradores e animações); heróis com modelo próprio.
- Detalhes de cada tema: `docs/gdd/` (abaixo).

## Engine
- **Godot 4.7.2**, fixado em `.godot-version`. Os dois sempre na mesma versão; atualizar é decisão conjunta, em commit próprio.
- **GDScript com tipagem estática.** Sem C#.

## `docs/gdd/` é a fonte da verdade do design
| Arquivo | Tema |
|---|---|
| `docs/gdd/00-visao-geral.md` | conceito, gênero, público, plataforma, engine, pitch |
| `docs/gdd/01-historia.md` | premissa, mundo, lore, enredo, tom |
| `docs/gdd/02-personagens.md` | heróis, NPCs, inimigos |
| `docs/gdd/03-mecanicas.md` | core loop, controles, sistemas, progressão |
| `docs/gdd/04-arte.md` | direção visual, paleta, estilo, assets |
| `docs/gdd/05-som.md` | música, efeitos, clima sonoro |
| `docs/gdd/06-niveis.md` | fases, estrutura, dificuldade |
| `docs/gdd/07-roadmap.md` | fases do projeto, tarefas, quem faz o quê |
| `docs/gdd/decisoes.md` | log de decisões (data, tema, decisão, motivo) |

- Cada arquivo começa com **Decisões fechadas** e **Em aberto**. Antes de implementar algo de design, leia o tema. Se o código e o `docs/gdd/` divergirem, **pergunte**: não "corrija" um pelo outro sozinho.
- **Não invente decisões.** O que não foi decidido fica `[A DEFINIR]` ou *(proposta)*. Decisão nova: atualiza o arquivo do tema **e** acrescenta uma linha no topo de `docs/gdd/decisoes.md`, no mesmo commit, **depois que o humano confirmar**.
- **História:** o mundo é do mestre da mesa. Fato da campanha não se inventa; texto do Gabriel é citado como está.
- `docs/DECISOES.md` é só histórico (D001–D029 com detalhes). `docs/GDD.md`, `HISTORIA.md`, `ESTILO.md` e `ROADMAP.md` viraram ponteiros para `docs/gdd/`.

## Comandos por tema (`.claude/commands/`)
Cada um lê o arquivo do tema + a visão geral, assume o papel de especialista, fica só naquele tema e, a cada decisão, propõe a mudança no arquivo e a linha em `decisoes.md`, aplicando só depois da confirmação.

| Comando | Papel | Arquivo |
|---|---|---|
| `/visao <assunto>` | diretor do jogo | `00-visao-geral.md` |
| `/historia <assunto>` | roteirista | `01-historia.md` |
| `/personagens <assunto>` | designer de personagens | `02-personagens.md` |
| `/mecanicas <assunto>` | game designer de sistemas | `03-mecanicas.md` |
| `/arte <assunto>` | diretor de arte | `04-arte.md` |
| `/som <assunto>` | diretor de áudio | `05-som.md` |
| `/niveis <assunto>` | level designer | `06-niveis.md` |
| `/roadmap <assunto>` | produtor | `07-roadmap.md` |

Skills do repo: `sync` (sincronizar), `conflito` (resolver conflito), `ideia` (registrar ideia como issue).

## Estrutura de pastas
```
res://
├─ actors/        heroes/ (os 5 jogáveis), enemies/, props/ (rato...), tico_lirou/, tika_muro/ (modelos), shared/ (Animator)
├─ combat/        Combatant, Ability, CombatRules (D&D), AIBrain, CombatFX
├─ battle/        arena por turnos (BattleArena: iniciativa, PA, QTE, esquivar/aparar)
├─ player/        controle no mapa (WASD, primeiro golpe)
├─ world/         Level, Encounter, Interactable (F), HeroSpot, Figurante, props/ (peças do catálogo)
├─ editor/        editor de mapas dentro do jogo (F2 numa fase ou botão na tela inicial)
├─ story/         cenas por roteiro: Roteiro (.tres) + CutscenePlayer; prólogo e cenas dos heróis
├─ levels/        fases: levels/<nome>/<nome>.tscn + levels/<nome>/art/ (arandu, ethera, arenas)
├─ ui/            hud/, battle_hud/, title/, character_select/, theme/ (Cinzel + Lato)
├─ systems/       game/ (autoload Game), camera/ (3ª pessoa)
├─ data/          abilities/*.tres
├─ assets/        o que várias cenas usam: kits/ (Quaternius + KayKit), materials/, shaders/, skies/, vfx/, fonts/, environment/
├─ tests/         testes GUT, espelhando as pastas do código
├─ tools/         check.ps1, sync, simulate_arena.gd, art/ (montadores e geradores), blender/ (scripts do Blender)
├─ art_src/       fontes de arte (.blend), ignorado pelo Godot, LFS
├─ docs/          gdd/ (design), FLUXO.md, SETUP.md, GUIA_ESQUELETO.md
└─ addons/        plugins de terceiros (GUT). Não editar.
```
Asset de uma coisa só mora junto dela. Só sobe para `assets/` quando duas ou mais cenas usam.

## Como as partes funcionam (para não quebrar)
- **Regras e números de batalha moram em `.tres` e no Inspector** (`Combatant`, `Ability` com `ap_cost`/`status_turns`, `BattleArena`), nunca enterrados no código. Mexeu em número? Rode `tools/simulate_arena.gd` e registre em `docs/gdd/decisoes.md`.
- **Fases** usam `world/level.gd` (`Level`): cria você no `PlayerSpawn`, os outros nos `HeroSpot`, liga os `Encounter`, toca a cena de abertura (`cena_de_abertura`) e monta a navegação (grupo `nav_source`). Começo de cada herói: `Game.START_LEVELS`.
- **Cenas** (`story/`): roteiro em texto com comandos entre colchetes; formato no topo de `story/roteiro.gd`. O prólogo (`story/prologo.tres`) é escrito pelo Gabriel: não regenere por script.
- **Personagens animados:** esqueleto humanoide + biblioteca `assets/kits/kaykit/animacoes/humanoide.res`; o nó `Animator` escolhe a animação. Passo a passo em `docs/GUIA_ESQUELETO.md`.
- **Arandu** foi montada por `tools/art/montar_arandu.gd` + `montar_cena_tico.gd` a pedido do Gabriel (D027). Rodar de novo **apaga** ajustes feitos à mão na fase: pergunte antes.
- Estado entre cenas: autoload `Game` (`systems/game/game.gd`).

## Ferramentas instaladas no projeto
- **MCP `godot`** (`.mcp.json`): `run_project` + `get_debug_output` + `stop_project` para rodar o jogo e ler erros. **Não use** `create_scene`/`add_node`/`save_scene` para montar fase.
- **MCP `blender`** (`mcp-for-blender`): modelar ao vivo com o Blender aberto. Para algo repetível, prefira script em `tools/blender/` com `blender --background`.
- **Plugin GodotPrompter**: conselhos genéricos de Godot 4; quando contradizem este arquivo ou `docs/gdd/`, vale o nosso.
- Antes de abrir uma janela do Godot (fotos, testes com tela), confira se o humano não está jogando (LoL, Rocket League): janela nova rouba o foco.

## Colaboração (Gabriel `@Gabrielbs149` + John `@JohnG-404`)
- **Cada um com sua conta** do Claude e seu clone. Os Claudes não conversam entre si: falam pelo repo (este arquivo, `docs/gdd/`, commits, issues, PRs). "Combinei com o meu Claude" não vale para o do outro.
- **Sincronização pelo GitHub.** Nada de Drive/OneDrive para o projeto (D004).
- **Branch por feature** (D030): a `main` sempre roda e só recebe PR.
  1. `git switch main && git pull` → `git switch -c <tipo>/<assunto>` (ex.: `feat/garras-do-tico`, `fix/capa-do-tico`, `docs/gdd-som`, `level/ethera`).
  2. Commits pequenos no padrão. Envie a branch cedo e sempre (`git push -u origin <branch>`).
  3. Abra o PR para a `main` (`gh pr create`, template do repo). CI verde é obrigatório.
  4. [A DEFINIR] revisão do parceiro obrigatória ou opcional? Merge em **squash**.
  5. Branch de vida curta (dias, não semanas). Depois do merge: `git switch main && git pull` e apague a branch.
- **Arquivos quentes** (`project.godot`, autoloads, a fase que os dois usam, temas de UI): avise antes, PR só disso.
- **Mover/renomear** arquivo do jogo só pelo FileSystem do editor, em PR próprio.
- Quando o Godot perguntar se recarrega arquivos que mudaram no disco: **sempre recarregar**.
- Detalhes (conflito, LFS, Live Share): `docs/FLUXO.md`.

## Regras de ouro
1. **Editor-first.** Fases, cenários, layout de UI e posicionamento são montados pelos humanos no editor (do Godot ou o editor de mapas F2). Código cuida de comportamento; não gere mundo por script sem o humano pedir.
2. **A `main` sempre roda.** Antes de commitar: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1`. O pre-push roda de novo e o CI de novo. Nunca use `--no-verify`.
3. **Commits pequenos, um assunto cada.**
4. **Nunca:** force push, `reset --hard`, `git clean`, reescrever histórico já enviado, apagar arquivo do parceiro sem perguntar, reformatar arquivo que você não precisava mudar.
5. **Mudança local que não é sua** pode ser trabalho do humano no editor. Não descarte e não commite junto sem perguntar.
6. **Ideia não é tarefa.** Ideia vira issue `ideia` (skill `ideia`); só vira código depois de aprovada e virar issue `tarefa` com dono.
7. Idioma: conversa, docs, commits e comentários em **PT-BR**; identificadores (variáveis, funções, nós, arquivos) em **inglês** (D005).

## Padrões de código

### Nomes
| O quê | Padrão | Exemplo |
|---|---|---|
| Pastas e arquivos | snake_case, sempre minúsculo | `actors/player/player.tscn`, `main_menu.gd` |
| Cena + script | mesmo nome, mesma pasta | `door.tscn` + `door.gd` |
| `class_name`, nós na árvore | PascalCase | `class_name HealthComponent`, nó `AnimationPlayer` |
| Funções, variáveis | snake_case | `func take_damage(amount: int) -> void` |
| Privado | prefixo `_` | `_velocity`, `func _update_animation() -> void` |
| Constantes, valores de enum | CONSTANT_CASE | `const MAX_SPEED := 200.0` |
| Enums | PascalCase | `enum State { IDLE, RUN, JUMP }` |
| Sinais | snake_case, no passado | `signal health_changed(value: int)`, `signal died` |
| Grupos | snake_case, plural | `"enemies"`, `"interactables"` |
| Ações de input | snake_case | `move_left`, `jump`, `interact` |
| Testes | `test_<alvo>.gd` | `tests/components/test_health_component.gd` |

Arquivo sempre minúsculo: o Windows não diferencia `Player.png` de `player.png`, mas o jogo exportado diferencia. Quebra só na build.

### GDScript
- Tipagem estática em tudo: variáveis, parâmetros e retorno (`-> void`). `:=` só quando o tipo é óbvio na mesma linha.
- Ordem no arquivo (guia oficial): `@tool` → `class_name` → `extends` → doc `##` → signals → enums → constants → `@export` → vars públicas → vars privadas → `@onready` → `_init`/`_ready`/`_process`/`_physics_process` → métodos públicos → métodos privados.
- Indentação com **tab**. Linhas até ~100 colunas.
- **Chamada para baixo, sinal para cima:** o pai chama métodos do filho; o filho emite sinal e não procura o pai (`get_parent()`). Entre sistemas distantes, use o autoload `Events` (barramento de sinais) quando ele existir.
- Nós: `@onready var _sprite: Sprite2D = $Sprite2D` ou `%NomeUnico`. Nada de `get_node("../../X")`.
- Número de gameplay (velocidade, dano, tempo, alcance) vai em `@export` ou num `Resource` `.tres`, para ajustar no Inspector. Nada de número mágico enterrado no código.
- Composição antes de herança: comportamento reutilizável vira componente em `components/`.
- Erro real: `push_error`/`push_warning`. `print` de debug não entra em commit.
- Comentário explica o **porquê**. `##` em classes e funções públicas.

#### 3D
- Modelos: origem nos pés, frente para **−Z** no Godot (+Y no Blender). Os modelos do KayKit olham para +Z: a cena que usa gira 180° (`world/figurante.gd`, `actors/tico_lirou/tico_lirou.tscn`).
- Efeito visual de um instante (projétil, número, anel) vai no `CombatFX` e devolve com `await`.
- Peças de cenário com colisão automática entram no grupo `colisao_auto` (a fase cria a colisão ao abrir; não vai para o arquivo).

#### Armadilhas Godot 3 → 4 (use SEMPRE a coluna da direita)
| Godot 3 (errado aqui) | Godot 4 (certo) |
|---|---|
| `export var` / `onready var` / `tool` | `@export var` / `@onready var` / `@tool` |
| `yield(obj, "sig")` | `await obj.sig` |
| `connect("sig", self, "_f")` / `emit_signal("sig", a)` | `sig.connect(_f)` / `sig.emit(a)` |
| `KinematicBody2D` + `move_and_slide(vel)` | `CharacterBody2D`: `velocity = ...` e `move_and_slide()` sem argumento |
| export de nó no `.tscn` sem `node_paths` | `[node ... node_paths=PackedStringArray("grid")]` + `grid = NodePath("../Grid")` |
| `.instance()` | `.instantiate()` |
| `setget` | `var hp: int: set = _set_hp` |
| `rand_range`, `deg2rad`, `stepify` | `randf_range`, `deg_to_rad`, `snapped` |
| `PoolStringArray` | `PackedStringArray` |
| `File`, `Directory` | `FileAccess`, `DirAccess` |
| `Spatial`, `Position2D` | `Node3D`, `Marker2D` |
| `Tween.new()` | `create_tween()` |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` |

Na dúvida sobre uma API, confira a doc da 4.7 (https://docs.godotengine.org/en/4.7/). Não chute.

### Editando .tscn / .tres à mão
- Só para coisa pequena: valor de propriedade, ligar script, conexão de sinal simples.
- Cada `[ext_resource]`/`[sub_resource]` tem `id` único no arquivo. O `uid="uid://..."` precisa bater com o `.uid`/`.import` do recurso. **Não invente uid**: na dúvida, omita o atributo e o Godot preenche ao salvar.
- Depois: rode `tools/check.ps1` e peça para o humano abrir a cena no editor e salvar (Ctrl+S), o que normaliza o arquivo.

### Arquivos que o Godot gera
- `.godot/` nunca vai para o Git (já está no `.gitignore`). Não leia nem varra.
- `*.uid` (de scripts/shaders) e `*.import` **sempre vão**, no mesmo commit do arquivo dono. Criou `.gd` fora do editor? O `.uid` só nasce no import: rode `tools/check.ps1` e commite o `.uid` gerado. O CI barra `.uid`/`.import` esquecido.

## Testes
- GUT em `addons/gut`. Testes em `tests/`, espelhando as pastas.
- Lógica pura (dano, regras, save, editor, cenas) leva teste. Visual e "feel" ficam com o playtest humano.
- Bug corrigido: escreva o teste que reproduz, quando der.

## Commits
`tipo(escopo): descrição curta no imperativo, em PT-BR`

Tipos: `feat` `fix` `refactor` `perf` `test` `docs` `chore` `ci` `asset` (arte/som/fonte) `level` (fase/cena montada no editor). Escopo = área (`tico`, `arandu`, `ui`, `battle`, `gdd`...). O hook `commit-msg` recusa mensagem fora do padrão. Fecha tarefa? `Closes #12` no corpo.

## Ao terminar uma tarefa
1. `tools/check.ps1` verde.
2. Commits no padrão, `.uid`/`.import` junto, na branch da feature.
3. Push da branch e PR (ou atualização do PR).
4. Diga ao humano **o que abrir no editor e o que testar** (cena, tecla, o que deve acontecer).

## Economia (plano com limite de uso)
- Leia só o necessário. Não varra `addons/` nem `.godot/`.
- Tarefa grande: plano curto antes e execução em lotes.
