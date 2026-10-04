<#
Checagem do projeto: a MESMA que o CI roda. Verde aqui = verde lá.
  1. Godot na versão do .godot-version
  2. import (gera .godot/ e os .uid/.import que faltam)
  3. todo .gd compila (tools/check_scripts.gd)
  4. testes GUT, se o GUT estiver instalado
  5. .uid/.import gerados pelo Godot que ficaram fora do Git

Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tools\check.ps1
      O hook pre-push chama com -PrePush: aí o item 5 vira erro em vez de aviso.
#>
param([switch]$PrePush)

$raiz = Split-Path $PSScriptRoot -Parent
Set-Location $raiz
. (Join-Path $PSScriptRoot '_godot.ps1')
$versao = (Get-Content (Join-Path $raiz '.godot-version') -Raw).Trim()

function Etapa([string]$nome) { Write-Host "`n== $nome" -ForegroundColor Cyan }
function Falha([string]$texto) { Write-Host $texto -ForegroundColor Red }

$godot = Find-Godot -Raiz $raiz -Versao $versao
if (-not $godot) {
    Falha "Godot não encontrado. Rode tools\preparar.ps1 (ou defina a variável de ambiente GODOT)."
    exit 1
}

Etapa "Versão do Godot"
$v = Get-GodotVersion $godot
if ($v -notlike "$versao.stable*") {
    Falha "Este PC tem o Godot $v, mas o projeto usa $versao (.godot-version)."
    Falha "Se for o da Steam, ela atualizou sozinha: rode tools\preparar.ps1 (baixa a versão certa) e combine com o parceiro antes de mudar de versão."
    exit 1
}
Write-Host "$v ($godot)"

Etapa "Import"
if ((Invoke-Godot $godot $raiz @('--headless', '--quiet', '--path', '.', '--import')) -ne 0) {
    Falha "O import falhou (erro acima)."
    exit 1
}
Write-Host "OK"

$falhou = $false

Etapa "Scripts compilam"
if ((Invoke-Godot $godot $raiz @('--headless', '--path', '.', '-s', 'res://tools/check_scripts.gd')) -ne 0) { $falhou = $true }

Etapa "Testes (GUT)"
if (-not (Test-Path 'addons/gut/gut_cmdln.gd')) {
    Write-Host "GUT não instalado ainda (tools\instalar-gut.ps1). Pulando."
} elseif (-not (Test-Path 'tests')) {
    Write-Host "Sem pasta tests/ ainda. Pulando."
} else {
    $codigo = Invoke-Godot $godot $raiz @('--headless', '--path', '.', '-s', 'res://addons/gut/gut_cmdln.gd',
        '-gdir=res://tests', '-ginclude_subdirs', '-gexit') -Silencioso
    # A saída do GUT é longa: mostra só o resumo, ou tudo se falhar
    if ($codigo -ne 0) {
        $script:GodotSaida | ForEach-Object { Write-Host $_ }
        $falhou = $true
    } else {
        $script:GodotSaida | Where-Object { $_ -match '^(Scripts|Tests|Passing|Failing|Pending|Asserts|Time)|All tests passed' } |
            ForEach-Object { Write-Host $_ }
    }
}

Etapa ".uid/.import no Git"
# Só importa quando o arquivo dono já está no Git e o .uid/.import dele não.
$soltos = @()
foreach ($linha in (git status --porcelain --untracked-files=all -- '*.uid' '*.import')) {
    if (-not $linha.StartsWith('??')) { continue }
    $arquivo = $linha.Substring(3).Trim('"')
    $dono = $arquivo -replace '\.(uid|import)$', ''
    git ls-files --error-unmatch -- $dono *> $null
    if ($LASTEXITCODE -eq 0) { $soltos += $arquivo }
}
if ($soltos.Count -eq 0) {
    Write-Host "OK"
} elseif ($PrePush) {
    Falha "O Godot gerou estes arquivos e eles precisam ir no Git junto do arquivo dono:"
    $soltos | ForEach-Object { Write-Host "  $_" }
    Falha "Faça: git add <arquivos acima>; git commit -m `"chore: adiciona .uid`"; e o push de novo."
    $falhou = $true
} else {
    Write-Host "Lembrete: commitar junto do arquivo dono:" -ForegroundColor Yellow
    $soltos | ForEach-Object { Write-Host "  $_" }
}

if ($falhou) {
    Falha "`nCHECAGEM FALHOU (veja acima)."
    exit 1
}
Write-Host "`nTudo certo." -ForegroundColor Green
exit 0
