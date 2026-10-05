# Setup: do zero ao primeiro commit

Leva uns 30–40 min cada. Os dois estão no Windows. Quem faz o quê: 🅖 Gabriel · 🅐 John · 🅖🅐 os dois.

> ⚠️ **O projeto mora em `C:\dev\`, fora do OneDrive/Google Drive.** Pasta sincronizada + Git + Godot = arquivo travado, cópia `(conflito).tscn` e `.git` corrompido. A nuvem do projeto é o GitHub. (`tools/preparar.ps1` se recusa a rodar dentro do OneDrive.)

Atalho: depois do passo 2, dá para abrir o Claude Code e pedir *"segue o docs/SETUP.md, parte do Gabriel"* (ou *"parte do John"*). Ele executa e para onde precisar de você.

## 1. Contas 🅖🅐
- Uma conta no GitHub para cada um, com **2FA ligado**.
- Claude Code: já vem no Pro. Instale o **Claude Desktop** (https://claude.ai/download) e use a aba **Code**.
- 🅖 (opcional) Você é universitário: o **GitHub Student Developer Pack** dá GitHub Pro grátis, com mais minutos de CI e a possibilidade de travar force-push na `main` mesmo com o repo privado.

## 2. Programas 🅖🅐
No PowerShell:
```powershell
winget install --id Git.Git -e
winget install --id GitHub.cli -e
winget install --id Microsoft.VisualStudioCode -e
winget install --id OpenJS.NodeJS.LTS -e
```
O Node.js é para o MCP do Godot, que o Claude usa para rodar o jogo e ler os erros.
O Gabriel já tem o Git, então pode pular essa linha.

**Godot:** se você já tem o da **Steam** na versão do `.godot-version`, o `preparar.ps1` usa ele. Na Steam: botão direito no Godot → *Propriedades → Atualizações* → **"Só atualizar ao abrir"**, e versão nova só quando os dois combinarem (o `check.ps1` barra versão diferente). Se não tiver Godot nenhum, o `preparar.ps1` baixa a versão exata para `C:\dev\godot\` e cria o atalho na área de trabalho.

Feche e abra o PowerShell. Depois:
```powershell
git config --global user.name "Seu Nome"
git config --global user.email "o-email-da-sua-conta-github@exemplo.com"
git config --global init.defaultBranch main
git lfs install --skip-repo
gh auth login
```
No `gh auth login`, escolha GitHub.com → HTTPS → *Login with a web browser*.

## 3. Criar o repositório 🅖
```powershell
New-Item -ItemType Directory -Force C:\dev | Out-Null
cd C:\dev
gh repo create jogo --private --clone
robocopy "C:\Users\Gabriel\OneDrive\Desktop\kit-jogo" C:\dev\jogo /E
cd C:\dev\jogo
powershell -NoProfile -ExecutionPolicy Bypass -File tools\preparar.ps1
```
`jogo` é um codinome: renomear depois é fácil (*Settings → Rename* no GitHub). O `preparar.ps1` configura o Git do clone (hooks, rebase, LFS), baixa o Godot 4.7.2 e roda a primeira checagem.

**Abra no Godot:** atalho *Godot 4.7.2* na área de trabalho → *Import* → `C:\dev\jogo\project.godot` → *Import & Edit*. Espere o import, aperte F5 (no painel Output deve aparecer "Projeto rodando") e feche o Godot.

**Instale o GUT** (testes):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\instalar-gut.ps1
```
Depois, no Godot: *Project → Project Settings → Plugins → GUT → Enable*.

**Preencha os placeholders:** troque `John`, `Gabrielbs149` e `JohnG-404` no `CLAUDE.md`, no `README.md` e em `docs/`. Dá para pedir: *"troca os placeholders: amigo = Fulano, github dele = fulano123, meu = gabriel123"*.

**Primeiro commit:**
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check.ps1
git add -A
git commit -m "chore: estrutura inicial do projeto"
git branch -M main
git push -u origin main
```
Confira a aba **Actions** no GitHub: o CI tem que ficar verde.

**Convide o 🅐:** *Settings → Collaborators → Add people* → usuário dele, ou:
```powershell
gh api -X PUT repos/Gabrielbs149/jogo/collaborators/JohnG-404 -f permission=push
```

**Labels:**
```powershell
gh label create ideia  --color FBCA04 --description "Ideia em discussão" --force
gh label create tarefa --color 0E8A16 --description "Trabalho decidido, com dono" --force
gh label create bug    --color D73A4A --description "Algo quebrado" --force
gh label create depois --color C5DEF5 --description "Boa ideia, mas não agora" --force
```

**Board:** no repo → *Projects → New project → Board*. Colunas: **Ideias · A fazer · Fazendo · Feito**. Em *Settings → Manage access*, adicione o 🅐 como *Write*.

## 4. O John entra 🅐
Aceite o convite (chega por e-mail ou em github.com/notifications). Depois:
```powershell
New-Item -ItemType Directory -Force C:\dev | Out-Null
cd C:\dev
gh repo clone Gabrielbs149/jogo
cd jogo
powershell -NoProfile -ExecutionPolicy Bypass -File tools\preparar.ps1
```
Abra no Godot pelo atalho (*Import* → `C:\dev\jogo\project.godot`). No Claude Desktop → **Code** → escolha a pasta `C:\dev\jogo`.

**Na primeira sessão o Claude pergunta duas coisas. Aceite as duas:**
- usar o servidor MCP **godot** do projeto (`.mcp.json`);
- instalar o marketplace **skillsmith** e o plugin **godot-prompter** (vêm do `.claude/settings.json`).

Teste com: *"lê o CLAUDE.md e me explica nosso fluxo em 5 linhas"* e depois *"qual a versão do Godot pelo MCP?"*.

O VS Code vai sugerir as extensões do projeto (godot-tools e Live Share) quando você abrir a pasta: aceite.

## 5. Treino juntos, em call (15 min) 🅖🅐
1. 🅐 coloca o próprio nome na tabela "Equipe" do `README.md` e faz o sync (`sync.cmd` ou pede pro Claude: "sincroniza").
2. 🅖 faz o sync e vê o commit chegar.
3. **Conflito de propósito:** os dois mudam a mesma linha do `docs/GDD.md` (o pitch). 🅖 faz sync primeiro. 🅐 faz sync, dá conflito, 🅐 pede pro Claude *"resolve o conflito"* e os dois assistem.
4. **Live Share:** 🅖 abre o VS Code em `C:\dev\jogo` → *Live Share* → manda o link. 🅐 entra e os dois editam o `main/main.gd` ao mesmo tempo.
5. Cada um pede pro Claude registrar uma ideia: *"anota essa ideia: ..."*. Confiram as issues no GitHub.

## 6. Extras (opcional)
- **Feed no Discord:** no canal → *Editar canal → Integrações → Webhooks → Novo* → copie a URL. No GitHub: *Settings → Webhooks → Add webhook* → Payload URL = `<url-do-discord>/github`, content type `application/json`, eventos: pushes, issues, pull requests.
- **Proteger a `main`** (precisa de GitHub Pro em repo privado): *Settings → Rules → New ruleset* → alvo `main` → marcar *Block force pushes* e *Restrict deletions*.

## Problemas comuns
| Sintoma | Resolve |
|---|---|
| `Godot não encontrado` | rode `tools\preparar.ps1` de novo, ou defina a variável de ambiente `GODOT` apontando para o `..._console.exe` |
| `versão errada do Godot` | os dois precisam da versão do `.godot-version`; rode o `preparar.ps1` |
| push recusado: checagem falhou | leia o erro acima dele; peça pro Claude: "o push falhou, conserta" |
| arquivo de som/arte aparece como texto de 3 linhas | o LFS não baixou: `git lfs install --skip-repo` e depois `git lfs pull` |
| `.uid` esquecido (CI vermelho) | `tools\check.ps1`, `git add *.uid` e commit |
