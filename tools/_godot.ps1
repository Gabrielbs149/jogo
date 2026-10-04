<#
Funções comuns do check.ps1 e do preparar.ps1: achar o Godot e rodar ele esperando terminar.
Funciona com o _console.exe do site oficial e com o .exe da Steam (que não escreve no terminal sozinho).
#>

# Roda o Godot, espera terminar, mostra a saída e devolve o código de saída.
function Invoke-Godot([string]$Exe, [string]$Pasta, [string[]]$Argumentos, [switch]$Silencioso) {
    $out = [IO.Path]::GetTempFileName()
    $err = [IO.Path]::GetTempFileName()
    $p = Start-Process -FilePath $Exe -ArgumentList $Argumentos -WorkingDirectory $Pasta `
        -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    $script:GodotSaida = @(Get-Content $out, $err -Encoding UTF8 | ForEach-Object { $_ -replace '\e\[[0-9;]*m', '' } | Where-Object { $_.Trim() -ne '' })
    Remove-Item $out, $err -ErrorAction SilentlyContinue
    if (-not $Silencioso) { $script:GodotSaida | ForEach-Object { Write-Host $_ } }
    return $p.ExitCode
}

function Get-GodotVersion([string]$Exe) {
    $null = Invoke-Godot -Exe $Exe -Pasta (Split-Path $Exe -Parent) -Argumentos @('--version') -Silencioso
    return ($script:GodotSaida | Select-Object -Last 1)
}

# Procura nesta ordem: variável GODOT, godot no PATH, pasta do preparar.ps1, Steam.
# Prefere um que tenha a versão do projeto; se nenhum tiver, devolve o primeiro achado (o check reclama da versão).
function Find-Godot([string]$Raiz, [string]$Versao) {
    $steam = Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
    $candidatos = @(
        $env:GODOT,
        [Environment]::GetEnvironmentVariable('GODOT', 'User'),
        (Get-Command godot -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source),
        (Join-Path (Split-Path $Raiz -Parent) "godot\$Versao\Godot_v$Versao-stable_win64_console.exe"),
        $steam
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    foreach ($c in $candidatos) {
        if ((Get-GodotVersion $c) -like "$Versao.stable*") { return $c }
    }
    return ($candidatos | Select-Object -First 1)
}
