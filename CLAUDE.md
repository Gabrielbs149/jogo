# CLAUDE.md

Regras do projeto para os **dois** Claudes: o do Gabriel e o do <AMIGO>. Cada um roda na própria conta, no próprio clone. Vocês **não compartilham memória nem conversa**: o que precisa valer para os dois mora no repo (aqui, em `docs/`, nas issues e no histórico do Git). Decidiu algo que o outro precisa saber? Registre em `docs/DECISOES.md` no mesmo commit.

## O projeto
- **Godot 4.7.2**, fixado em `.godot-version`. Os dois sempre na mesma versão; atualizar é decisão conjunta, em commit próprio.
- **GDScript com tipagem estática.** Sem C#.
- **3D em terceira pessoa** (D007). Personagem: `actors/player/` (`Player` + `CameraRig`). Fase de teste: `levels/sandbox/`. Fase de exemplo: `levels/mist_field/`.
- **Visual só em tons de cinza** (D008): do preto até cinza claro (~`#CCCCCC`), **nunca branco puro, nunca cor**. Toda fase usa o `WorldEnvironment` com `assets/environment/gray_world.tres` (tira a saturação e limita o brilho; os tons se ajustam no gradiente dele). Material novo: `albedo_color` cinza (R = G = B). UI: texto até `Color(0.78, 0.78, 0.78)`, fundo preto translúcido.
- **Ritmo lento, focado em história** (D009): nada de corrida/ação rápida sem o humano pedir. História entra por `Interactable` (`components/interactable/`) + autoload `Dialogue` (`ui/dialogue/`); as falas ficam no Inspector, não no código.
- Design: `docs/GDD.md` (ideia ainda em aberto). Fases: `docs/ROADMAP.md`. Git: `docs/FLUXO.md`.
- Equipe: Gabriel (`@Gabrielbs149`) e <AMIGO> (`@<usuario-github-amigo>`). Os dois mexem em tudo, ao mesmo tempo.
- Idioma: conversa, docs, commits e comentários em **PT-BR**. Identificadores (variáveis, funções, nós, arquivos, pastas) em **inglês**, combinando com a API do Godot.

## Começo de toda sessão
O hook de início mostra `git status` e os últimos commits do remoto. Se aparecer `behind`, o parceiro mandou coisa: **sincronize antes de editar** (skill `sync`). Rebase parado com conflito? Resolva primeiro (skill `conflito`).

## Regras de ouro
1. **Editor-first.** Fases, cenários, layout de UI e posicionamento são montados pelos humanos **no editor do Godot**. Código cuida de comportamento; nunca gere mundo por script (instanciar paredes/tiles/props para "montar" a fase). Precisa de nó novo numa cena? Prefira dizer o que arrastar e onde. Edite `.tscn` à mão só para mudanças pequenas e mecânicas (ver abaixo).
2. **A `main` sempre roda.** Antes de commitar: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1`. O pre-push roda de novo e o CI de novo. Nunca use `--no-verify`.
3. **Commits pequenos, um assunto cada, sync frequente.** Quanto mais tempo sem sync, maior o conflito.
4. **Nunca:** force push, `reset --hard`, `git clean`, reescrever histórico já enviado, apagar arquivo do parceiro sem perguntar, reformatar ou reordenar arquivo que você não precisava mudar.
5. **Mudança local que não é sua** pode ser trabalho em andamento do humano no editor. Não descarte e não commite junto sem perguntar.
6. **Mover/renomear arquivo do jogo só pelo FileSystem do editor** (ele atualiza as referências). Rename vai em commit próprio.
7. **Arquivos quentes** (`project.godot`, `autoload/`, a fase que os dois usam, `default_bus_layout.tres`, temas de UI): mexeu, commit só disso e sync na hora.
8. **Ideia não é tarefa.** Não implemente ideia que não virou issue `tarefa` sem o humano pedir.

## Estrutura de pastas
```
res://
├─ main/          cena de entrada (main.tscn) e boot
├─ autoload/      singletons registrados em project.godot (Events, Game, Save...)
├─ actors/        player/, enemies/<nome>/, npcs/<nome>/ — cada um com .tscn + .gd + arte/som próprios
├─ levels/        fases montadas no editor: levels/<nome>/<nome>.tscn
├─ components/    pedaços reutilizáveis por composição (HealthComponent, Hitbox...)
├─ ui/            hud/, menus/, dialog/
├─ systems/       lógica sem cena própria (save, inventory...)
├─ data/          Resources .tres (stats, itens) e tabelas de balanceamento
├─ assets/        SÓ o que várias cenas compartilham: fonts/, music/, sfx/, shaders/, themes/
├─ prototypes/    protótipos de 1 dia (Fase 1); apagar os que não vingarem
├─ addons/        plugins de terceiros (GUT). Não editar.
├─ tests/         testes GUT, espelhando as pastas do código
├─ tools/         check, sync, preparar (scripts de apoio)
├─ art_src/       fontes de arte (.aseprite/.psd/.blend), ignorado pelo Godot, vai por LFS
└─ docs/          documentação, ignorado pelo Godot
```
Asset de uma coisa só mora junto dela (`actors/player/player_run.png`). Só sobe para `assets/` quando duas ou mais cenas usam. Cada um geralmente fica na sua pasta, e isso reduz conflito.

## Nomes
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

## GDScript
- Tipagem estática em tudo: variáveis, parâmetros e retorno (`-> void`). `:=` só quando o tipo é óbvio na mesma linha.
- Ordem no arquivo (guia oficial): `@tool` → `class_name` → `extends` → doc `##` → signals → enums → constants → `@export` → vars públicas → vars privadas → `@onready` → `_init`/`_ready`/`_process`/`_physics_process` → métodos públicos → métodos privados.
- Indentação com **tab**. Linhas até ~100 colunas.
- **Chamada para baixo, sinal para cima:** o pai chama métodos do filho; o filho emite sinal e não procura o pai (`get_parent()`). Entre sistemas distantes, use o autoload `Events` (barramento de sinais) quando ele existir.
- Nós: `@onready var _sprite: Sprite2D = $Sprite2D` ou `%NomeUnico`. Nada de `get_node("../../X")`.
- Número de gameplay (velocidade, dano, tempo, alcance) vai em `@export` ou num `Resource` `.tres`, para ajustar no Inspector. Nada de número mágico enterrado no código.
- Composição antes de herança: comportamento reutilizável vira componente em `components/`.
- Erro real: `push_error`/`push_warning`. `print` de debug não entra em commit.
- Comentário explica o **porquê**. `##` em classes e funções públicas.

### Armadilhas Godot 3 → 4 (use SEMPRE a coluna da direita)
| Godot 3 (errado aqui) | Godot 4 (certo) |
|---|---|
| `export var` / `onready var` / `tool` | `@export var` / `@onready var` / `@tool` |
| `yield(obj, "sig")` | `await obj.sig` |
| `connect("sig", self, "_f")` / `emit_signal("sig", a)` | `sig.connect(_f)` / `sig.emit(a)` |
| `KinematicBody2D` + `move_and_slide(vel)` | `CharacterBody2D`: `velocity = ...` e `move_and_slide()` sem argumento |
| `.instance()` | `.instantiate()` |
| `setget` | `var hp: int: set = _set_hp` |
| `rand_range`, `deg2rad`, `stepify` | `randf_range`, `deg_to_rad`, `snapped` |
| `PoolStringArray` | `PackedStringArray` |
| `File`, `Directory` | `FileAccess`, `DirAccess` |
| `Spatial`, `Position2D` | `Node3D`, `Marker2D` |
| `Tween.new()` | `create_tween()` |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` |

Na dúvida sobre uma API, confira a doc da 4.7 (https://docs.godotengine.org/en/4.7/). Não chute.

## Editando .tscn / .tres à mão
- Só para coisa pequena: valor de propriedade, ligar script, conexão de sinal simples.
- Cada `[ext_resource]`/`[sub_resource]` tem `id` único no arquivo. O `uid="uid://..."` precisa bater com o `.uid`/`.import` do recurso. **Não invente uid**: na dúvida, omita o atributo e o Godot preenche ao salvar.
- Depois: rode `tools/check.ps1` e peça para o humano abrir a cena no editor e salvar (Ctrl+S), o que normaliza o arquivo.

## Arquivos que o Godot gera
- `.godot/` nunca vai para o Git (já está no `.gitignore`). Não leia nem varra.
- `*.uid` (de scripts/shaders) e `*.import` **sempre vão**, no mesmo commit do arquivo dono. Criou `.gd` fora do editor? O `.uid` só nasce no import: rode `tools/check.ps1` e commite o `.uid` gerado. O CI barra `.uid`/`.import` esquecido.

## Testes
- GUT em `addons/gut`. Testes em `tests/`, espelhando as pastas (`tests/components/test_health_component.gd`).
- Lógica pura (dano, inventário, save, regras) leva teste. Visual e "feel" ficam com o playtest humano.
- Bug corrigido: escreva o teste que reproduz, quando der.

## Commits
`tipo(escopo): descrição curta no imperativo, em PT-BR`

Tipos: `feat` `fix` `refactor` `perf` `test` `docs` `chore` `ci` `asset` (arte/som/fonte) `level` (fase/cena montada no editor). Escopo = área (`player`, `enemy`, `ui`, `save`, `audio`, `forest`...).

Exemplos: `feat(player): adiciona pulo duplo` · `fix(ui): corrige texto cortado no menu` · `asset(sfx): sons de passo na grama` · `level(forest): fecha atalho da área 2`

Corpo opcional com o porquê. Fecha tarefa? `Closes #12` no corpo. O hook `commit-msg` recusa mensagem fora do padrão.

## Git (resumo; o completo está em `docs/FLUXO.md`)
- Trunk-based: os dois trabalham na `main` com `pull --rebase` frequente (skill `sync`).
- Branch `exp/<assunto>` só para algo que deixaria o jogo quebrado por mais de um dia. Entra por PR (`gh pr create`) com CI verde, squash merge.
- No `pull --rebase` o lado **`--ours`/HEAD é o remoto (o parceiro)** e o **`--theirs` é o seu commit**. É o contrário do que parece.

## Ideias e tarefas
- Ideia nova → issue com label `ideia` (skill `ideia`).
- Aprovada na call → entra no `docs/GDD.md` e vira issue `tarefa` com dono.

## Ao terminar uma tarefa
1. `tools/check.ps1` verde.
2. Commits no padrão, `.uid`/`.import` junto.
3. Sync.
4. Diga ao humano **o que abrir no editor e o que testar** (cena, tecla, o que deve acontecer).

## Economia (os dois estão no plano Pro, que tem limite de uso)
- Leia só o necessário. Não varra `addons/` nem `.godot/`. Não releia arquivo inteiro à toa.
- Tarefa grande: proponha um plano curto antes e execute em lotes.
