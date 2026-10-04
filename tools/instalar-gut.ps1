<#
Instala o GUT (testes automatizados) em addons/gut, na versão que casa com o Godot do projeto,
e cria um teste de exemplo. Roda 1 vez só (quem fizer o setup); depois addons/gut vai pro Git.
Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tools\instalar-gut.ps1
#>
$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$versaoGut = '9.7.1'   # GUT 9.7.x = Godot 4.7.x (branch godot_4_7 do github.com/bitwes/Gut)
$destino = Join-Path $raiz 'addons\gut'

if (Test-Path $destino) {
    Write-Host "GUT já está em addons/gut."
    exit 0
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
$zip = Join-Path $env:TEMP "gut-$versaoGut.zip"
$tmp = Join-Path $env:TEMP "gut-$versaoGut"
Write-Host "Baixando GUT $versaoGut..."
Invoke-WebRequest -Uri "https://github.com/bitwes/Gut/archive/refs/tags/v$versaoGut.zip" -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$origem = Get-ChildItem $tmp -Recurse -Directory -Filter 'gut' |
    Where-Object { $_.Parent.Name -eq 'addons' } | Select-Object -First 1
if (-not $origem) { throw "Não achei addons/gut dentro do zip do GUT." }
New-Item -ItemType Directory -Force (Join-Path $raiz 'addons') | Out-Null
Copy-Item $origem.FullName $destino -Recurse
Remove-Item $zip, $tmp -Recurse -Force

$teste = Join-Path $raiz 'tests\test_sanity.gd'
if (-not (Test-Path $teste)) {
    New-Item -ItemType Directory -Force (Split-Path $teste) | Out-Null
    $codigo = "extends GutTest`n## Prova que o GUT roda no CI. Pode apagar quando existir teste de verdade.`n`n`nfunc test_gut_is_running() -> void:`n`tassert_eq(2 + 2, 4)`n"
    [IO.File]::WriteAllText($teste, $codigo, (New-Object Text.UTF8Encoding $false))
}

Write-Host "GUT instalado. No Godot: Project > Project Settings > Plugins > GUT > Enable." -ForegroundColor Green
Write-Host "Depois: tools\check.ps1 e commit (chore(tests): instala GUT $versaoGut)."
