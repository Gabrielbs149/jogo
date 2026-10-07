# Fluxo de trabalho a dois

## Em uma frase
O **GitHub é a nuvem** do projeto. Não é tempo real como o Google Docs, mas fica *quase* tempo real se a gente sincronizar toda hora. E tem uma vantagem que o Drive não tem: quando os dois mexem no mesmo arquivo, o Git **junta** as mudanças em vez de uma apagar a outra, e qualquer versão antiga pode ser recuperada.

**Por que não Drive/OneDrive para o projeto:** o Godot grava vários arquivos de uma vez (`.tscn`, `.uid`, `.import`, cache em `.godot/`). O sync da nuvem pega isso pela metade, trava arquivo aberto, cria `level_01 (conflito de PC-Gabriel).tscn` e corrompe a pasta `.git`. Por isso o projeto mora em `C:\dev\`, fora de qualquer pasta sincronizada.

**Por que ninguém edita a mesma cena ao mesmo tempo:** nenhuma engine boa para trabalhar com IA faz isso. O Unreal faz, mas os arquivos dele são binários e pesados. O Godot salva a cena inteira de uma vez. Com o Git, dois salvando a mesma cena viram um conflito que dá para resolver; no Drive, um apaga o outro.

## Tempo real de verdade (quando querem mexer JUNTOS)
| Situação | Ferramenta |
|---|---|
| Programar no mesmo arquivo ao mesmo tempo | **VS Code Live Share**: um abre a sessão, o outro entra pelo link e os dois digitam no mesmo arquivo, cada um com seu cursor. Os arquivos ficam na máquina de quem abriu, e ele commita no fim (adicione `Co-authored-by: Nome <email>` no corpo do commit). |
| Montar fase / mexer no editor juntos | Call no Discord com tela compartilhada do Godot. Quem está "no controle" mexe; para trocar, sync e passa a vez. |
| Ver o que o outro está fazendo | Webhook do GitHub num canal `#commits` do Discord: cada push aparece na hora. |
| Saber quem está em quê | Board do GitHub Projects (coluna **Fazendo**, issue com dono). |

## O ciclo de todo dia
1. **Abriu → sync** (puxa o que o parceiro mandou).
2. **Vai mexer em arquivo quente** (fase compartilhada, `project.godot`, autoload)? Avisa ("vou mexer na forest") ou move a issue para **Fazendo**.
3. **Funcionou algo → sync com mensagem** (commit e push **da sua branch**). Meta: a cada 30–60 min, não só no fim do dia. Pronto? PR para a `main`.
4. **O Godot perguntou se quer recarregar arquivos que mudaram no disco → sempre RECARREGAR.** Se salvar por cima, você apaga o que o parceiro mandou.
5. **Vai sair → sync.** Trabalho não passa a noite só na sua máquina.

Como fazer o sync:
- **Pelo Claude:** "sincroniza" (skill `sync`). Ele separa em commits, escreve as mensagens no padrão e resolve conflito se aparecer.
- **Sem Claude** (por exemplo, quando bater o limite do Pro): duplo clique em `sync.cmd`, ou no terminal: `sync "feat(ui): menu de pausa"`.

## Branches (D030, substitui o trunk-based da D003)
- **`main`**: sempre roda e **só recebe PR**. Ninguém commita direto nela.
- **Branch por feature**: `<tipo>/<assunto>` saindo da `main` atualizada (`feat/garras-do-tico`, `fix/capa`, `docs/gdd-som`, `level/ethera`). Vida curta (dias). Envie cedo (`git push -u origin <branch>`).
- **PR** para a `main` (`gh pr create`, template do repo) com CI verde. Merge em **squash**. Revisão do parceiro não é obrigatória: com CI verde, quem abriu faz o merge.
- Depois do merge: `git switch main && git pull` e apague a branch.
- **`prototypes/`** é uma pasta, não uma branch.
- **Tags** `v0.1.0`, `v0.2.0`...: fim de fase/ciclo. Build oficial sai de tag.

## Commits
`tipo(escopo): descrição no imperativo, em PT-BR`

| Tipo | Quando |
|---|---|
| `feat` | funcionalidade nova |
| `fix` | correção de bug |
| `refactor` | muda o código sem mudar o comportamento |
| `perf` | desempenho |
| `test` | testes |
| `docs` | documentação, GDD, decisões |
| `chore` | manutenção, config, dependências |
| `ci` | GitHub Actions |
| `asset` | arte, som, fonte, shader visual |
| `level` | fase/cena montada no editor |

Exemplos: `feat(player): adiciona pulo duplo`, `level(forest): fecha atalho da área 2`, `asset(music): tema da floresta`.

## Proteções automáticas
| Onde | O que faz |
|---|---|
| Hook `commit-msg` | recusa mensagem fora do padrão |
| Hook `pre-push` | roda `tools/check.ps1` (Godot na versão certa, import, todo `.gd` compila, testes GUT). Se falhar, não sobe. |
| CI (GitHub Actions) | mesma checagem num Linux limpo, mais `.uid`/`.import` esquecido |
| `.claude/settings.json` | os dois Claudes ficam proibidos de fazer force push, `reset --hard`, `git clean` e `--no-verify` |
| `.gitattributes` | fim de linha igual nos dois PCs; arquivo grande vai pro LFS |

## Evitar conflito (em ordem de importância)
1. **Sync frequente.** Conflito cresce com o tempo sem sync.
2. **Cenas pequenas.** Player, inimigo, porta e HUD têm cada um seu `.tscn`; a fase só **instancia**. Dois mexendo em coisas diferentes = arquivos diferentes = zero conflito.
3. **Pasta por coisa** (`actors/player/`, `levels/forest/`): cada um geralmente está na sua.
4. **Arquivos quentes** (avisar antes, commit sozinho): `project.godot` (autoload, input map, layers), `autoload/`, a fase que os dois usam, `default_bus_layout.tres`, temas de UI.
5. **Mover/renomear só pelo editor do Godot**, em commit próprio, avisando.
6. **Não reformatar/reordenar** arquivo que você não ia mudar (vale para o Claude também).

## Quando der conflito
Nada se perde: o Git para e espera.
- **Pelo Claude:** "resolve o conflito" (skill `conflito`). Ele junta as duas versões e explica o que fez.
- **Sem Claude:** `git rebase --abort` desfaz o pull e volta tudo como estava. Chama o parceiro.

| Arquivo | Como resolve |
|---|---|
| `.gd`, `.md`, `.json`, `.cfg` | junta as duas intenções; se forem incompatíveis, decide em call |
| `.tscn`, `.tres` | junta os blocos tomando cuidado com `id` repetido; se ficar complicado, fica a versão do parceiro e você refaz a sua parte no editor |
| `project.godot` | junta as seções (`[autoload]` e `[input]` dos dois) |
| `.uid`, `.import` | fica a do remoto |
| Arte/som (binário) | não tem como juntar: combinem quem é o dono; o outro salva a proposta como `nome_v2.png` |

## Arquivos grandes (Git LFS)
Áudio, fontes de arte (`.aseprite`, `.psd`, `.kra`, `.blend`), modelos 3D, fontes e vídeo vão para o LFS automaticamente (pelo `.gitattributes`). PNG fica no Git normal (pixel art é pequeno; se o jogo for 3D com textura grande, a gente revê). A cota grátis do LFS e os minutos de CI são limitados: confira em *Settings → Billing* de vez em quando.

## Ideias
1. **Teve ideia → issue `ideia`** (template no GitHub, ou para o Claude: "anota essa ideia: ..."). Sem filtro. A discussão acontece nos comentários.
2. **Call semanal de 20 min:** cada ideia vira **sim** (entra no arquivo do tema em `docs/gdd/` e vira issue `tarefa`), **depois** (continua aberta) ou **não** (fecha com o motivo).
3. Decisão (de design ou técnica) fica no arquivo do tema em `docs/gdd/` + uma linha em `docs/gdd/decisoes.md`.

Por que no GitHub e não num Google Doc: os dois Claudes leem issues e docs do repo. O que está fora do repo, a IA do outro não enxerga.

## Claude Code dos dois no mesmo repo
- Cada um tem sua conta, seu clone e sua sessão. **Os Claudes não conversam entre si**: eles se comunicam pelo repo (CLAUDE.md, `docs/`, commits, issues).
- **Compartilhado (vai pro Git):** `CLAUDE.md`, `.claude/settings.json` (permissões + hook que mostra o status do Git ao abrir) e `.claude/skills/` (`sync`, `conflito`, `ideia`).
- **Pessoal (fica fora do Git):** `CLAUDE.local.md` (suas preferências), `.claude/settings.local.json` e a memória do seu Claude.
- Decisão que o outro Claude precisa saber vai para o repo no mesmo commit. "Combinei com o meu Claude" não vale para o do outro.
- Duas sessões no mesmo arquivo ao mesmo tempo = conflito garantido. Combinem quem pega o quê pelo board.
- O plano Pro tem limite de uso: tarefa simples pede modelo mais leve, plano curto antes de tarefa grande, e nada de "lê o projeto inteiro".
