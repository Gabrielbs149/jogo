<#
Prepara este clone. Rodar 1 vez por PC, logo depois de clonar.
  - recusa rodar dentro de pasta sincronizada (OneDrive/Drive/Dropbox)
  - configura o Git deste clone: hooks, pull com rebase, LFS, conflito mais legível
  - baixa o Godot da versão do .godot-version para C:\dev\godot\<versão> e cria o atalho
  - roda a primeira checagem (import + scripts)
Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tools\preparar.ps1
#>
$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
Set-Location $raiz

if ($raiz -match 'OneDrive|Google Drive|GoogleDrive|Dropbox') {
    Write-Host "Este repo está em $raiz, que é pasta sincronizada. Clone em C:\dev\ (docs/SETUP.md)." -ForegroundColor Red
    exit 1
}

Write-Host "== Git deste clone" -ForegroundColor Cyan
git config core.hooksPath .githooks      # hooks versionados: commit-msg, pre-push, LFS
git config pull.rebase true              # pull sem "merge commit" de bobeira
git config rebase.autoStash true         # pull funciona mesmo com mudança local
git config fetch.prune true
git config core.autocrlf false           # quem manda no fim de linha é o .gitattributes
git config merge.conflictStyle zdiff3    # conflito mostra também a versão original
git config rerere.enabled true           # lembra como você resolveu um conflito repetido
git lfs install --skip-repo | Out-Null
if (git remote) { git lfs pull }          # repo recém-criado ainda não tem remoto
if (-not (git config user.name) -or -not (git config user.email)) {
    Write-Host "Falta seu nome/e-mail no Git: veja docs/SETUP.md, passo 2." -ForegroundColor Yellow
}
Write-Host "OK"

$versao = (Get-Content (Join-Path $raiz '.godot-version') -Raw).Trim()
$nome = "Godot_v$versao-stable_win64"
$pastaGodot = Join-Path (Split-Path $raiz -Parent) "godot\$versao"
$exe = Join-Path $pastaGodot "$nome.exe"
$console = Join-Path $pastaGodot "${nome}_console.exe"

Write-Host "`n== Godot $versao" -ForegroundColor Cyan
. (Join-Path $PSScriptRoot '_godot.ps1')
$existente = Find-Godot -Raiz $raiz -Versao $versao
if ($existente -and ((Get-GodotVersion $existente) -like "$versao.stable*")) {
    # Já tem a versão certa (site, Steam...): usa ela, sem baixar nada
    [Environment]::SetEnvironmentVariable('GODOT', $existente, 'User')
    $env:GODOT = $existente
    Write-Host "OK: já instalado em $existente"
    if ($existente -like '*steamapps*') {
        Write-Host "É o da Steam: em Propriedades > Atualizações, deixe 'só atualizar quando eu abrir'. Versão nova só quando os dois combinarem." -ForegroundColor Yellow
    }
} else {
    if (-not (Test-Path $console)) {
        Write-Host "Baixando do GitHub oficial do Godot (~85 MB)..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'   # a barra de progresso do PS 5.1 deixa o download 10x mais lento
        $url = "https://github.com/godotengine/godot-builds/releases/download/$versao-stable/$nome.exe.zip"
        $zip = Join-Path $env:TEMP "$nome.zip"
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        New-Item -ItemType Directory -Force $pastaGodot | Out-Null
        Expand-Archive -Path $zip -DestinationPath $pastaGodot -Force
        Remove-Item $zip
        # Se o zip trouxer uma subpasta, acha os .exe onde estiverem
        $achado = Get-ChildItem $pastaGodot -Recurse -Filter "${nome}_console.exe" | Select-Object -First 1
        if (-not $achado) { throw "Não achei ${nome}_console.exe dentro do zip." }
        $console = $achado.FullName
        $exe = Join-Path $achado.DirectoryName "$nome.exe"
    }
    [Environment]::SetEnvironmentVariable('GODOT', $console, 'User')
    $env:GODOT = $console

    $atalho = Join-Path ([Environment]::GetFolderPath('Desktop')) "Godot $versao.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($atalho)
    $lnk.TargetPath = $exe
    $lnk.WorkingDirectory = Split-Path $exe -Parent
    $lnk.Save()
    Write-Host "OK: $exe (atalho na área de trabalho)"
}

# Daqui pra baixo os comandos podem escrever em stderr sem ser erro (gh, godot)
$ErrorActionPreference = 'Continue'

Write-Host "`n== Node.js (MCP do Godot, .mcp.json)" -ForegroundColor Cyan
if (Get-Command npx -ErrorAction SilentlyContinue) {
    Write-Host "OK: $(node --version)"
} else {
    Write-Host "Falta o Node.js: winget install --id OpenJS.NodeJS.LTS -e" -ForegroundColor Yellow
}

Write-Host "`n== GitHub CLI" -ForegroundColor Cyan
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh auth status *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host "OK" } else { Write-Host "Faça login: gh auth login" -ForegroundColor Yellow }
} else {
    Write-Host "gh não instalado: winget install --id GitHub.cli -e" -ForegroundColor Yellow
}

& (Join-Path $PSScriptRoot 'check.ps1')
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "`nPronto. Abra o Godot pelo atalho -> Import -> $raiz\project.godot" -ForegroundColor Green
